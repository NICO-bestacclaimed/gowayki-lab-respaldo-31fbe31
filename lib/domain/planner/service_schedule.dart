const _minuteMicros = 60000000;
const _dayMicros = 86400000000;
const _limaMicros = 18000000000;

class TimeBand<T> {
  const TimeBand(this.start, this.end, this.value);
  final int start, end;
  final T value;
  bool contains(int minute) => start < end
      ? start <= minute && minute < end
      : minute >= start || minute < end;
}

DateTime addMinutes(DateTime time, double minutes) =>
    time.add(Duration(microseconds: (minutes * 60000000).round()));

class BoardingEstimate {
  const BoardingEstimate(this.at, this.expectedWaitMinutes);
  final DateTime at;
  final double expectedWaitMinutes;
}

class PlannerSettings {
  PlannerSettings({
    required List<TimeBand<double?>> speeds,
    required List<TimeBand<double?>> frequencies,
    this.walkMetersPerMinute = 75,
    this.accessMeters = 800,
    this.fallbackMeters = 1500,
    this.walkDistanceFactor = 1.3,
  }) : speeds = List.unmodifiable(speeds),
       frequencies = List.unmodifiable(frequencies) {
    for (final value in [
      walkMetersPerMinute,
      accessMeters,
      fallbackMeters,
      walkDistanceFactor,
    ]) {
      if (!value.isFinite || value <= 0) {
        throw ArgumentError('Parámetro peatonal inválido.');
      }
    }
    if (fallbackMeters < accessMeters || walkDistanceFactor < 1) {
      throw ArgumentError('Radios/factor inválidos.');
    }
    _validate(this.speeds);
    _validate(this.frequencies);
    _speedLookup = List.generate(
      1440,
      (m) => this.speeds.singleWhere((band) => band.contains(m)),
    );
    _frequencyLookup = List.generate(
      1440,
      (m) => this.frequencies.singleWhere((band) => band.contains(m)),
    );
    for (var minute = 0; minute < 1440; minute++) {
      if ((_at(this.speeds, minute) == null) !=
          (_at(this.frequencies, minute) == null)) {
        throw ArgumentError('Franjas de servicio incompatibles.');
      }
    }
  }
  final List<TimeBand<double?>> speeds, frequencies;
  late final List<TimeBand<double?>> _speedLookup, _frequencyLookup;
  final double walkMetersPerMinute,
      accessMeters,
      fallbackMeters,
      walkDistanceFactor;

  factory PlannerSettings.fromConfig(Map<String, Object?> config) {
    if (config['timezone'] != 'America/Lima') {
      throw ArgumentError('Ciudad horaria incompatible.');
    }
    final periods =
        config['frequency_minutes_by_period'] as Map<String, dynamic>;
    final speedRows = config['speed_bands'] as List<dynamic>;
    final frequencyRows = config['frequency_bands'] as List<dynamic>?;
    if (frequencyRows == null) {
      throw ArgumentError(
        'Faltan franjas de frecuencia: regenerar el paquete v2.',
      );
    }
    return PlannerSettings(
      speeds: speedRows
          .map(
            (dynamic row) => TimeBand<double?>(
              _clock(row['start'] as String),
              _clock(row['end'] as String),
              (row['speed_kmh'] as num?)?.toDouble(),
            ),
          )
          .toList(),
      frequencies: frequencyRows
          .map(
            (dynamic row) => TimeBand<double?>(
              _clock(row['start'] as String),
              _clock(row['end'] as String),
              row['period'] == null
                  ? null
                  : (periods[row['period']] as num).toDouble(),
            ),
          )
          .toList(),
      walkMetersPerMinute: (config['walking_speed_m_per_min'] as num)
          .toDouble(),
      accessMeters: (config['access_max_m'] as num).toDouble(),
      fallbackMeters: (config['access_fallback_max_m'] as num).toDouble(),
    );
  }

  static int _clock(String value) {
    if (!RegExp(r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
      throw ArgumentError('Hora inválida.');
    }
    final pair = value.split(':').map(int.parse).toList();
    return pair[0] * 60 + pair[1];
  }

  static void _validate(List<TimeBand<double?>> bands) {
    for (final band in bands) {
      if (band.start < 0 ||
          band.start >= 1440 ||
          band.end < 0 ||
          band.end >= 1440 ||
          band.start == band.end ||
          (band.value != null && (!band.value!.isFinite || band.value! <= 0))) {
        throw ArgumentError('Franja inválida.');
      }
    }
    for (var minute = 0; minute < 1440; minute++) {
      if (bands.where((band) => band.contains(minute)).length != 1) {
        throw ArgumentError('Franjas con huecos o solapes.');
      }
    }
  }

  static double? _at(List<TimeBand<double?>> bands, int minute) =>
      bands.singleWhere((b) => b.contains(minute)).value;
  static DateTime cityClock(DateTime time) =>
      time.toUtc().subtract(const Duration(hours: 5));
  static int _minute(DateTime time) =>
      _minuteFromMicros(time.microsecondsSinceEpoch);
  static int _minuteFromMicros(int micros) =>
      (micros - _limaMicros) % _dayMicros ~/ _minuteMicros;
  static double _clockMinutes(DateTime time) =>
      (time.microsecondsSinceEpoch - _limaMicros) % _dayMicros / _minuteMicros;
  double? speedAt(DateTime time) => _speedLookup[_minute(time)].value;
  double? frequencyAt(DateTime time) => _frequencyLookup[_minute(time)].value;

  /// Preserve separate arrival labels across waiting-time discontinuities.
  int arrivalBucket(DateTime time) {
    final local = cityClock(time);
    final day =
        DateTime.utc(
          local.year,
          local.month,
          local.day,
        ).millisecondsSinceEpoch ~/
        86400000;
    return day * frequencies.length +
        frequencies.indexWhere((b) => b.contains(_minute(time)));
  }

  DateTime? boardAt(DateTime ready) => boarding(ready)?.at;

  /// Expected wait remains headway/2. A passenger may also wait for a nearby
  /// band change when that yields an earlier boarding. This FIFO envelope
  /// prevents a later arrival at the same stop from being inherently better.
  BoardingEstimate? boarding(DateTime ready) {
    final current = _frequencyLookup[_minute(ready)];
    final frequency = current.value;
    if (frequency == null) return null;
    var untilChange = current.end - _clockMinutes(ready);
    if (untilChange <= 0) untilChange += 1440;
    if (frequency / 2 <= untilChange) {
      final at = addMinutes(ready, frequency / 2);
      return speedAt(at) == null ? null : BoardingEstimate(at, frequency / 2);
    }
    final local = cityClock(ready);
    final midnight = DateTime.utc(local.year, local.month, local.day, 5);
    final changes = <DateTime>[];
    for (var day = 0; day < 2; day++) {
      for (final band in frequencies) {
        final change = midnight.add(Duration(days: day, minutes: band.start));
        if (change.isAfter(ready) &&
            change.difference(ready) <= const Duration(days: 1)) {
          changes.add(change);
        }
      }
    }
    changes.sort();
    DateTime? closure;
    for (final change in changes) {
      if (frequencyAt(change) == null) {
        closure = change;
        break;
      }
    }
    BoardingEstimate? best;
    for (final candidate in [ready, ...changes]) {
      if (closure != null && !candidate.isBefore(closure)) break;
      if (best != null && !candidate.isBefore(best.at)) break;
      final frequency = frequencyAt(candidate)!;
      final departure = addMinutes(candidate, frequency / 2);
      if ((closure == null || departure.isBefore(closure)) &&
          speedAt(departure) != null &&
          (best == null || departure.isBefore(best.at))) {
        best = BoardingEstimate(departure, frequency / 2);
      }
    }
    return best;
  }

  /// Modern America/Lima instants for a local day's service intervals.
  List<(DateTime, DateTime)> serviceWindows(DateTime deadline) {
    final local = cityClock(deadline);
    final result = <(DateTime, DateTime)>[];
    for (var day = -1; day <= 0; day++) {
      final midnight = DateTime.utc(
        local.year,
        local.month,
        local.day + day,
        5,
      );
      final active = <(DateTime, DateTime)>[];
      for (final band in frequencies.where((band) => band.value != null)) {
        final start = midnight.add(Duration(minutes: band.start));
        final end = midnight.add(
          Duration(minutes: band.end + (band.end <= band.start ? 1440 : 0)),
        );
        if (start.isBefore(deadline)) active.add((start, end));
      }
      active.sort((a, b) => a.$1.compareTo(b.$1));
      for (final window in active) {
        if (result.isNotEmpty && !window.$1.isAfter(result.last.$2)) {
          final previous = result.removeLast();
          result.add((
            previous.$1,
            window.$2.isAfter(previous.$2) ? window.$2 : previous.$2,
          ));
        } else {
          result.add(window);
        }
      }
    }
    return result;
  }

  DateTime? readyBefore(DateTime boardingDeadline, DateTime windowStart) {
    final current = _frequencyLookup[_minute(boardingDeadline)];
    final frequency = current.value;
    if (frequency != null) {
      var elapsed = _clockMinutes(boardingDeadline) - current.start;
      if (elapsed < 0) elapsed += 1440;
      if (frequency / 2 <= elapsed) {
        final candidate = addMinutes(boardingDeadline, -frequency / 2);
        if (!candidate.isBefore(windowStart)) return candidate;
      }
    }
    DateTime? best;
    final local = cityClock(boardingDeadline);
    for (var day = -1; day <= 0; day++) {
      final midnight = DateTime.utc(
        local.year,
        local.month,
        local.day + day,
        5,
      );
      for (final band in frequencies) {
        if (band.value == null) continue;
        final start = midnight.add(Duration(minutes: band.start));
        final end = midnight.add(
          Duration(minutes: band.end + (band.end <= band.start ? 1440 : 0)),
        );
        var candidate = addMinutes(boardingDeadline, -band.value! / 2);
        if (!candidate.isBefore(end)) {
          candidate = end.subtract(const Duration(microseconds: 1));
        }
        if (candidate.isBefore(start) || candidate.isBefore(windowStart)) {
          continue;
        }
        if (speedAt(addMinutes(candidate, band.value! / 2)) == null) {
          candidate = candidate.subtract(const Duration(microseconds: 1));
          if (candidate.isBefore(start) || candidate.isBefore(windowStart)) {
            continue;
          }
        }
        final board = addMinutes(candidate, band.value! / 2);
        if (speedAt(board) != null &&
            !board.isAfter(boardingDeadline) &&
            (best == null || candidate.isAfter(best))) {
          best = candidate;
        }
      }
    }
    return best;
  }

  DateTime? travelBackwards(DateTime arrival, double meters) {
    if (!meters.isFinite || meters < 0) {
      throw ArgumentError('Distancia inválida.');
    }
    var time = arrival;
    var remaining = meters;
    while (remaining > 1e-8) {
      final band =
          _speedLookup[_minuteFromMicros(time.microsecondsSinceEpoch - 1)];
      final speed = band.value;
      if (speed == null) return null;
      var available = _clockMinutes(time) - band.start;
      if (available <= 0) available += 1440;
      final rate = speed * 1000 / 60;
      if (remaining <= available * rate + 1e-8) {
        return addMinutes(time, -remaining / rate);
      }
      remaining -= available * rate;
      time = addMinutes(time, -available);
    }
    return time;
  }

  /// Integrate distance across speed boundaries; do not travel during closure.
  DateTime? travel(DateTime departure, double meters) {
    if (!meters.isFinite || meters < 0) {
      throw ArgumentError('Distancia inválida.');
    }
    var time = departure;
    var remaining = meters;
    while (remaining > 1e-8) {
      final band = _speedLookup[_minute(time)];
      final speed = band.value;
      if (speed == null) return null;
      final clock = _clockMinutes(time);
      var available = band.end - clock;
      if (available <= 0) available += 1440;
      final metersPerMinute = speed * 1000 / 60;
      if (remaining <= available * metersPerMinute + 1e-8) {
        return addMinutes(time, remaining / metersPerMinute);
      }
      remaining -= available * metersPerMinute;
      time = addMinutes(time, available);
    }
    return time;
  }
}

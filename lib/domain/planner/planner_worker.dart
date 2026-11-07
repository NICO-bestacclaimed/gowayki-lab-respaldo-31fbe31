import 'dart:async';
import 'dart:isolate';

import 'journey_planner.dart';
import '../repositories/journey_planner_client.dart';
import 'planner_network.dart';

/// A long-lived domain isolate. The network is copied only during startup.
class PlannerWorker implements JourneyPlannerClient {
  PlannerWorker._() {
    _subscription = _receive.listen(_message);
  }
  final _receive = ReceivePort();
  final _ready = Completer<SendPort>();
  final _closedAck = Completer<void>();
  final _exited = Completer<void>();
  final _pending = <int, Completer<JourneyResponse>>{};
  late final StreamSubscription<dynamic> _subscription;
  Isolate? _isolate;
  SendPort? _send;
  int _sequence = 0;
  bool _closing = false;

  static Future<PlannerWorker> start(PlannerNetwork network) async {
    final worker = PlannerWorker._();
    try {
      worker._isolate = await Isolate.spawn(
        _entry,
        (network, worker._receive.sendPort),
        onError: worker._receive.sendPort,
        onExit: worker._receive.sendPort,
        errorsAreFatal: true,
      );
      worker._send = await worker._ready.future.timeout(
        const Duration(seconds: 30),
      );
      return worker;
    } on Object {
      worker._isolate?.kill(priority: Isolate.immediate);
      await worker._subscription.cancel();
      worker._receive.close();
      rethrow;
    }
  }

  @override
  Future<JourneyResponse> plan(JourneyRequest request, {DateTime? now}) {
    if (_closing || _exited.isCompleted) {
      return Future.error(StateError('El planificador está cerrado.'));
    }
    final id = ++_sequence;
    final result = Completer<JourneyResponse>();
    _pending[id] = result;
    _send!.send((id, request, (now ?? DateTime.now()).toUtc()));
    return result.future;
  }

  void _message(dynamic message) {
    if (message is SendPort) {
      if (!_ready.isCompleted) _ready.complete(message);
    } else if (message == 'closed') {
      if (!_closedAck.isCompleted) _closedAck.complete();
    } else if (message == null) {
      if (!_exited.isCompleted) _exited.complete();
      _fail(StateError('El isolate del planificador terminó.'));
    } else if (message case (
      int id,
      JourneyResponse? response,
      String? error,
    )) {
      final pending = _pending.remove(id);
      if (pending == null) return;
      if (response != null) {
        pending.complete(response);
      } else {
        pending.completeError(StateError(error ?? 'Error de planificación.'));
      }
    } else if (message is List) {
      _fail(StateError('Falló el isolate: ${message.first}'));
    }
  }

  void _fail(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final result in _pending.values) {
      result.completeError(error);
    }
    _pending.clear();
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    try {
      if (!_exited.isCompleted) {
        _send!.send(null);
        await Future.any([
          _closedAck.future,
          _exited.future,
        ]).timeout(const Duration(seconds: 30));
        if (!_exited.isCompleted) {
          await _exited.future.timeout(const Duration(seconds: 3));
        }
      }
    } on TimeoutException {
      _isolate?.kill(priority: Isolate.immediate);
    } finally {
      _fail(StateError('El planificador está cerrado.'));
      await _subscription.cancel();
      _receive.close();
    }
  }

  static void _entry((PlannerNetwork, SendPort) input) {
    final (network, reply) = input;
    final planner = JourneyPlanner(network);
    final receive = ReceivePort();
    reply.send(receive.sendPort);
    receive.listen((dynamic message) {
      if (message == null) {
        reply.send('closed');
        receive.close();
        return;
      }
      final (id, request, now) = message as (int, JourneyRequest, DateTime);
      try {
        reply.send((id, planner.plan(request, now: now), null));
      } on Object catch (error) {
        reply.send((id, null, error.toString()));
      }
    });
  }
}

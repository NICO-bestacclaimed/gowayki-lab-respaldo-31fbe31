import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/models/feedback_item.dart';
import '../../app/providers/app_providers.dart';

final feedbackMetadataProvider = FutureProvider.autoDispose<FeedbackMetadata>((
  ref,
) async {
  final app = await PackageInfo.fromPlatform(), device = DeviceInfoPlugin();
  final services = await ref.watch(appServicesProvider.future);
  String model;
  if (kIsWeb) {
    model = 'Web';
  } else {
    model = switch (defaultTargetPlatform) {
      TargetPlatform.android => await (() async {
        final info = await device.androidInfo;
        return '${info.manufacturer} ${info.model}';
      })(),
      TargetPlatform.iOS => (await device.iosInfo).utsname.machine,
      TargetPlatform.macOS => (await device.macOsInfo).model,
      TargetPlatform.windows => 'Windows (modelo no disponible)',
      TargetPlatform.linux => 'Linux (modelo no disponible)',
      TargetPlatform.fuchsia => 'Fuchsia (modelo no disponible)',
    };
  }
  // Only model, app and data versions are sent. No serial, user-assigned device
  // name, account email, advertising identifier or full device-info map.
  return FeedbackMetadata(
    appVersion: '${app.version}+${app.buildNumber}',
    deviceModel: model.trim().isEmpty
        ? 'Modelo no disponible'
        : model.trim().substring(
            0,
            model.trim().length > 120 ? 120 : model.trim().length,
          ),
    dataVersion: (await services.cityPack.packageInfo()).version,
  );
});

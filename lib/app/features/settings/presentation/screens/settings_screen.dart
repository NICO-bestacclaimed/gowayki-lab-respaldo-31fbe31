import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../settings/app_settings.dart';
import '../../../../settings/legal_links.dart';
import '../../../../../domain/models/city_pack_models.dart';
import '../../../../../shared/l10n/l10n.dart';
import '../../../../../shared/widgets/content_state.dart';

final packageInfoProvider = FutureProvider<CityPackInfo>((ref) async {
  final services = ref.watch(appServicesProvider).requireValue;
  return services.cityPack.packageInfo();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    AppSettings Function(AppSettings) change,
  ) async {
    try {
      await ref.read(appSettingsProvider.notifier).save(change);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      }
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    try {
      if (await ref.read(externalLinkOpenerProvider).open(uri)) return;
    } on Object {
      /* Shown below. */
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.openLinkFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(appSettingsProvider);
    final legal = ref.watch(legalLinksProvider);
    final info = ref.watch(packageInfoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: settings.when(
        loading: () => const ContentSkeleton(),
        error: (e, s) => ContentState(
          kind: ContentStateKind.error,
          onAction: () => ref.invalidate(appSettingsProvider),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.activeCity),
              subtitle: const Text('Arequipa'),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('settings.language.${value.languageCode}'),
              initialValue: value.languageCode ?? 'system',
              decoration: InputDecoration(labelText: l.language),
              items: [
                DropdownMenuItem(value: 'system', child: Text(l.systemDefault)),
                DropdownMenuItem(value: 'es', child: Text(l.spanish)),
                DropdownMenuItem(value: 'en', child: Text(l.english)),
              ],
              onChanged: (v) {
                if (v != null) {
                  _save(
                    context,
                    ref,
                    (s) => s.copyWith(
                      languageCode: v == 'system' ? null : v,
                      systemLanguage: v == 'system',
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<ThemeMode>(
              key: ValueKey('settings.theme.${value.theme.name}'),
              initialValue: value.theme,
              decoration: InputDecoration(labelText: l.theme),
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l.systemDefault),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l.lightTheme),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l.darkTheme),
                ),
              ],
              onChanged: (v) {
                if (v != null) _save(context, ref, (s) => s.copyWith(theme: v));
              },
            ),
            const SizedBox(height: 24),
            Text(
              l.plannerPreferences,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('settings.walking.${value.maxAccessMeters}'),
              initialValue: value.maxAccessMeters ?? 0,
              decoration: InputDecoration(labelText: l.maxWalking),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text(l.automaticWalking(800, 1500)),
                ),
                for (final meters in [400, 800, 1000, 1500])
                  DropdownMenuItem(
                    value: meters,
                    child: Text(l.walkingLimit(meters)),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  _save(
                    context,
                    ref,
                    (s) => s.copyWith(
                      maxAccessMeters: v == 0 ? null : v,
                      automaticWalking: v == 0,
                    ),
                  );
                }
              },
            ),
            SwitchListTile(
              key: const ValueKey('settings.avoidTransfers'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.avoidTransfers),
              value: value.avoidTransfers,
              onChanged: (v) =>
                  _save(context, ref, (s) => s.copyWith(avoidTransfers: v)),
            ),
            DropdownButtonFormField<AlarmMode>(
              key: ValueKey('settings.alarm.${value.alarm.name}'),
              initialValue: value.alarm,
              decoration: InputDecoration(labelText: l.alarmType),
              items: [
                DropdownMenuItem(
                  value: AlarmMode.sound,
                  child: Text(l.alarmSound),
                ),
                DropdownMenuItem(
                  value: AlarmMode.vibration,
                  child: Text(l.alarmVibration),
                ),
                DropdownMenuItem(value: AlarmMode.off, child: Text(l.alarmOff)),
              ],
              onChanged: (v) {
                if (v != null) _save(context, ref, (s) => s.copyWith(alarm: v));
              },
            ),
            const SizedBox(height: 24),
            Text(l.offlineData, style: Theme.of(context).textTheme.titleMedium),
            info.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => ContentState(
                kind: ContentStateKind.error,
                onAction: () => ref.invalidate(packageInfoProvider),
              ),
              data: (pack) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.dataVersion(pack.version)),
                subtitle: Text(
                  l.dataBuiltAt(
                    pack.generatedAt.toUtc().toIso8601String().split('T').first,
                  ),
                ),
              ),
            ),
            OutlinedButton(
              key: const ValueKey('settings.update'),
              onPressed: null,
              child: Text(l.checkUpdate),
            ),
            Text(l.updatesLater),
            const SizedBox(height: 24),
            Text(l.about, style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.osmAttribution),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _open(
                context,
                ref,
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.openMapTilesAttribution),
              trailing: const Icon(Icons.open_in_new),
              onTap: () =>
                  _open(context, ref, Uri.parse('https://openmaptiles.org/')),
            ),
            ListTile(
              key: const ValueKey('settings.privacy'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.privacy),
              enabled: legal.privacy != null,
              onTap: legal.privacy == null
                  ? null
                  : () => _open(context, ref, legal.privacy!),
            ),
            ListTile(
              key: const ValueKey('settings.terms'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.terms),
              enabled: legal.terms != null,
              onTap: legal.terms == null
                  ? null
                  : () => _open(context, ref, legal.terms!),
            ),
            if (legal.privacy == null || legal.terms == null)
              Text(l.legalUnavailable),
          ],
        ),
      ),
    );
  }
}

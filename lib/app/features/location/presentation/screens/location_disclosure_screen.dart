import 'package:gowayki_lab/shared/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/repositories/location_permission_repository.dart';
import '../../../../providers/app_providers.dart';

class LocationDisclosureScreen extends ConsumerStatefulWidget {
  const LocationDisclosureScreen({super.key, required this.onContinue});
  final Future<void> Function() onContinue;
  @override
  ConsumerState<LocationDisclosureScreen> createState() =>
      _LocationDisclosureState();
}

class _LocationDisclosureState extends ConsumerState<LocationDisclosureScreen> {
  bool _busy = false;
  LocationAccess? _access;
  String? _error;
  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      await widget.onContinue();
    } on Object {
      if (mounted) setState(() => _error = context.l10n.continueFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(locationPermissionRepositoryProvider);
      var access = await repository.check();
      if (access == LocationAccess.denied) access = await repository.request();
      if (!mounted) return;
      setState(() => _access = access);
      if (access == LocationAccess.allowed) await widget.onContinue();
    } on Object {
      if (mounted) setState(() => _error = context.l10n.permissionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settings() async {
    try {
      final opened = await ref
          .read(locationPermissionRepositoryProvider)
          .openSettings();
      if (!opened && mounted) {
        setState(() => _error = context.l10n.permissionSettingsHelp);
      }
    } on Object {
      if (mounted) setState(() => _error = context.l10n.deviceSettingsHelp);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined, size: 72),
                const SizedBox(height: 24),
                Text(
                  context.l10n.locationTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.locationExplanation,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.locationOptional,
                  textAlign: TextAlign.center,
                ),
                if (_access == LocationAccess.denied) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.locationDenied,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_access == LocationAccess.permanentlyDenied) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.locationPermanent,
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _busy ? null : _settings,
                    child: Text(context.l10n.openSettings),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _request,
                  child: Text(
                    _busy
                        ? context.l10n.waitMoment
                        : context.l10n.allowLocation,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _continue,
                  child: Text(context.l10n.continueWithoutLocation),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

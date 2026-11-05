import 'package:flutter/material.dart';

import '../../../../../core/models/city.dart';
import '../../../../../data/service_locator.dart';
import '../../../../../shared/theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<City>> _cities;
  String? _city;
  String? _locale;

  @override
  void initState() {
    super.initState();
    _cities = ServiceLocator.cities.activeCities();
    _load();
  }

  Future<void> _load() async {
    final city = await ServiceLocator.preferences.readCityCode();
    final locale = await ServiceLocator.preferences.readLocaleCode();
    if (!mounted) return;
    setState(() {
      _city = city;
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajustes')),
      body: FutureBuilder<List<City>>(
        future: _cities,
        builder: (context, snap) {
          final cities = snap.data ?? const <City>[];
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Text('Ciudad', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: cities.any((c) => c.code == _city) ? _city : null,
                items: cities
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.code,
                        child: Text(c.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  await ServiceLocator.preferences.saveCityCode(v);
                  setState(() => _city = v);
                },
                decoration: const InputDecoration(labelText: 'Ciudad activa'),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Idioma', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Auto'),
                    selected: _locale == null,
                    onSelected: (_) async {
                      await ServiceLocator.preferences.saveLocaleCode(null);
                      setState(() => _locale = null);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Español'),
                    selected: _locale == 'es',
                    onSelected: (_) async {
                      await ServiceLocator.preferences.saveLocaleCode('es');
                      setState(() => _locale = 'es');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('English'),
                    selected: _locale == 'en',
                    onSelected: (_) async {
                      await ServiceLocator.preferences.saveLocaleCode('en');
                      setState(() => _locale = 'en');
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Backend'),
                subtitle: Text(ServiceLocator.useFirebase ? 'Firebase' : 'Demo local'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Mapa'),
                subtitle: Text('MapLibre offline · GTFS Arequipa'),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../core/models/transit_line.dart';
import '../../../../../data/service_locator.dart';
import '../../../../../shared/theme/theme.dart';

/// Sheet "Combis": lista de líneas GTFS con ida/vuelta.
class CombisSheet extends StatefulWidget {
  const CombisSheet({super.key, required this.onSelected});

  final ValueChanged<TransitLine> onSelected;

  static Future<void> open(
    BuildContext context, {
    required ValueChanged<TransitLine> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CombisSheet(onSelected: onSelected),
    );
  }

  @override
  State<CombisSheet> createState() => _CombisSheetState();
}

class _CombisSheetState extends State<CombisSheet> {
  final _query = TextEditingController();
  List<TransitLine> _all = const [];
  List<TransitLine> _filtered = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final lines = await ServiceLocator.transit.lines();
    lines.sort(
      (a, b) => a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase()),
    );
    if (!mounted) return;
    setState(() {
      _all = lines;
      _filtered = lines;
      _loading = false;
    });
  }

  void _onChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _all;
      } else {
        _filtered = _all.where((l) {
          if (l.shortName.toLowerCase().contains(q)) return true;
          for (final d in l.directions) {
            if (d.headsign.toLowerCase().contains(q) ||
                d.longName.toLowerCase().contains(q)) {
              return true;
            }
          }
          return false;
        }).toList(growable: false);
      }
    });
  }

  Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h, radix: 16) ?? 0xF05709;
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.85;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Combis',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar línea o combi…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(color: AppColors.onSurfaceMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final line = _filtered[i];
                          final color = _parseColor(line.color);
                          final ida = line.ida?.headsign;
                          final vuelta = line.vuelta?.headsign;
                          final subtitle = [
                            if (ida != null) 'Ida → $ida',
                            if (vuelta != null) 'Vuelta → $vuelta',
                          ].join(' · ');
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              child: Text(
                                line.shortName.isEmpty
                                    ? '?'
                                    : (line.shortName.length > 3
                                        ? line.shortName.substring(0, 3)
                                        : line.shortName),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              line.shortName.isEmpty ? line.id : line.shortName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              subtitle.isEmpty
                                  ? '${line.directions.length} sentido(s)'
                                  : subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSelected(line);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

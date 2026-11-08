/// Visual catalog from Paradero Digital, transporte/catalogo.py.
/// Colors identify the ten numbered corridors in the bundled v2 data.
/// White fleets require an explicit operator: never infer one from white alone.
class FleetIdentity {
  const FleetIdentity(
    this.key,
    this.company,
    this.color,
    this.accent,
    this.micro,
  );
  final String key, company, color, accent;
  final String? micro;

  static const companies = <String, FleetIdentity>{
    'C2': FleetIdentity(
      'C2',
      'Cono Norte',
      '#DBD9D1',
      '#15803D',
      'c2_cono_norte_t',
    ),
    'C3': FleetIdentity(
      'C3',
      'Transcayma',
      '#FEDD00',
      '#A16207',
      'c3_transcayma_embajada',
    ),
    'C4': FleetIdentity(
      'C4',
      'Unión AQP',
      '#FF6900',
      '#EA580C',
      'c4_union_aqp_7a_huarangal',
    ),
    'C5': FleetIdentity('C5', 'EtraBus', '#FF0000', '#DC2626', null),
    'C6': FleetIdentity(
      'C6',
      'Unión Grau',
      '#AFA96E',
      '#857B2E',
      'c6_union_grau_a',
    ),
    'C7': FleetIdentity(
      'C7',
      'AQP Masivo',
      '#8D4925',
      '#8D4925',
      'c7_aqpmasivo_05',
    ),
    'C8': FleetIdentity(
      'C8',
      'Bus Characato',
      '#00C996',
      '#047857',
      'c8_bus_characato_t_quequena',
    ),
    'C9': FleetIdentity(
      'C9',
      'Emarsistran',
      '#10069F',
      '#10069F',
      'c9_emarsistran_4_de_octubre_cayma',
    ),
    'C10': FleetIdentity(
      'C10',
      'MegaBus AQP',
      '#DF1995',
      '#BE185D',
      'c10_megabus_a',
    ),
    'C11': FleetIdentity('C11', 'Cotum', '#2F4F4F', '#2F4F4F', null),
    'ALBOTRAN': FleetIdentity(
      'ALBOTRAN',
      'Albotran',
      '#FFFFFF',
      '#1D4ED8',
      'albotran_sin_letra',
    ),
    'CHIGUATA': FleetIdentity(
      'CHIGUATA',
      'Chiguata Express',
      '#FFFFFF',
      '#0369A1',
      'chiguata_p',
    ),
  };

  static const _micros = <String, Map<String, String>>{
    'ALBOTRAN': {
      'CB': 'albotran_cb',
      'F2': 'albotran_f2',
      'R': 'albotran_r',
      'S: Terminal Terrestre': 'albotran_s_terminal_terrestre',
    },
    'C2': {
      'A': 'c2_cono_norte_a',
      'C': 'c2_cono_norte_c',
      'T': 'c2_cono_norte_t',
      'Cettar': 'c2_cono_norte_cettar',
      'CIMA S': 'c2_cono_norte_cima_s',
      'CIMA*': 'c2_cono_norte_cima',
    },
    'C3': {'Embajada': 'c3_transcayma_embajada'},
    'C4': {
      '7A*': 'c4_union_aqp_7a_huarangal',
      'A15': 'c4_union_aqp_a15',
      'B: Juan XXIII': 'c4_union_aqp_b_juan_xxiii',
      'B: Miraflores (Salvador)': 'c4_union_aqp_b_miraflores_salvador',
      'B: Miraflores (Tomasa)': 'c4_union_aqp_b_miraflores_salvador',
      'D': 'c4_union_aqp_d',
      'D (Huaranguillo)': 'c4_union_aqp_d',
      'Gráficos*': 'c4_union_aqp_graficos_b_p_polanco',
    },
    'C6': {'A': 'c6_union_grau_a'},
    'C7': {'5': 'c7_aqpmasivo_05', 'B': 'c7_aqpmasivo_b'},
    'C8': {
      'T: Quequeña': 'c8_bus_characato_t_quequena',
      'T: San Antonio': 'c8_bus_characato_t_san_antonio',
    },
    'C9': {
      '4 de octubre*': 'c9_emarsistran_4_de_octubre_cayma',
      'Alto Libertad': 'c9_emarsistran_alto_libertad',
    },
    'C10': {
      'A': 'c10_megabus_la_mansion_del_fundador',
      'D': 'c10_megabus_d',
      'M': 'c10_megabus_m',
      '38': 'c10_megabus_38',
      'Tiabaya - Goyeneche': 'c10_megabus_tiabaya_goyeneche',
    },
    'CHIGUATA': {'P': 'chiguata_p'},
  };

  // Explicit spellings in the immutable v2 package; scoped to their corridor.
  static const _aliases = <String, Map<String, String>>{
    'C4': {'Juan XXIII': 'B: Juan XXIII', 'D Huaranguillo': 'D (Huaranguillo)'},
    'C7': {'05': '5'},
    'C8': {'T Quequeña': 'T: Quequeña', 'T San Antorio': 'T: San Antonio'},
    'C10': {'M Upis': 'M'},
  };

  static FleetIdentity resolve({
    String operatorName = '',
    String color = '#FF6B00',
  }) {
    final operator = operatorName.trim();
    final match = RegExp(
      r'^C\s*-?\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(operator);
    final key = match == null
        ? operator.split(' ').first.toUpperCase()
        : 'C${int.parse(match[1]!)}';
    if (companies.containsKey(key)) return companies[key]!;
    // A supplied unknown operator must not acquire another company's artwork.
    if (operator.isEmpty) {
      for (final fleet in companies.values) {
        if (fleet.color != '#FFFFFF' && fleet.color == color.toUpperCase()) {
          return fleet;
        }
      }
    }
    return FleetIdentity('', operator, color, '#C2410C', null);
  }

  String? assetFor(String code) {
    final table = _micros[key] ?? const <String, String>{};
    final value = _aliases[key]?[code.trim()] ?? code.trim();
    var slug = table[value];
    if (slug == null) {
      for (final entry in table.entries) {
        if (entry.key.endsWith('*') &&
            value.startsWith(entry.key.substring(0, entry.key.length - 1))) {
          slug = entry.value;
          break;
        }
      }
    }
    slug ??= micro;
    return slug == null ? null : 'assets/illustrations/micros/$slug.webp';
  }
}

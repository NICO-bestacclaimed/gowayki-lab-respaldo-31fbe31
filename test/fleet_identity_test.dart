import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gowayki_lab/shared/brand/fleet_identity.dart';
import 'package:gowayki_lab/app/features/planner/presentation/widgets/itinerary_card.dart';

void main() {
  test('catalog has all twelve companies and exact fleet colors', () {
    expect(FleetIdentity.companies, hasLength(12));
    expect(FleetIdentity.resolve(operatorName: 'C-4 Unión AQP').key, 'C4');
    expect(FleetIdentity.resolve(color: '#10069f').key, 'C9');
    expect(FleetIdentity.resolve(color: '#FFFFFF').key, isEmpty);
    expect(
      FleetIdentity.resolve(operatorName: 'Unknown', color: '#FF6900').key,
      isEmpty,
    );
  });
  test('specific route, prefix and company fallback', () {
    String? micro(String company, String code) =>
        FleetIdentity.resolve(operatorName: company).assetFor(code);
    expect(
      micro('C4', '7A: Huarangal'),
      endsWith('c4_union_aqp_7a_huarangal.webp'),
    );
    expect(micro('Albotran', 'F2'), endsWith('albotran_f2.webp'));
    expect(
      micro('C8', 'T: Quequeña'),
      endsWith('c8_bus_characato_t_quequena.webp'),
    );
    expect(
      micro('C8', 'T San Antorio'),
      endsWith('c8_bus_characato_t_san_antonio.webp'),
    );
    expect(micro('C2', 'CIMA S'), endsWith('c2_cono_norte_cima_s.webp'));
    expect(micro('C2', 'CIMA Bustamante'), endsWith('c2_cono_norte_cima.webp'));
    expect(
      micro('C10', 'A'),
      endsWith('c10_megabus_la_mansion_del_fundador.webp'),
    );
    expect(micro('C4', 'Unknown'), endsWith('c4_union_aqp_7a_huarangal.webp'));
    expect(micro('C5', 'A'), isNull);
    expect(micro('C11', 'B'), isNull);
    expect(micro('Chiguata Express', 'P'), endsWith('chiguata_p.webp'));
  });
  test('company fallback assets are present', () {
    for (final fleet in FleetIdentity.companies.values) {
      final asset = fleet.assetFor('');
      if (asset != null) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    }
  });
  testWidgets('route artwork, accessible label and border on white fleet', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ListTile(
            leading: LineAvatar(
              name: 'F2',
              color: '#FFFFFF',
              operatorName: 'Albotran',
            ),
            title: Text('Ruta'),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Albotran · F2'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(
      (provider.imageProvider as AssetImage).assetName,
      endsWith('albotran_f2.webp'),
    );
    final containers = tester.widgetList<Container>(find.byType(Container));
    expect(
      containers.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

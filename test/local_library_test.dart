import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gowayki_lab/app/library/local_library.dart';
import 'package:gowayki_lab/core/models/place_result.dart';
import 'package:gowayki_lab/domain/models/navigation_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = PlaceResult(
    id: 'a',
    name: 'Origen de prueba',
    address: '',
    latitude: -16.4,
    longitude: -71.5,
  );
  const b = PlaceResult(
    id: 'b',
    name: 'Destino de prueba',
    address: '',
    latitude: -16.5,
    longitude: -71.6,
  );
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    await container.read(localLibraryProvider.future);
  });
  tearDown(() => container.dispose());
  test(
    'cambios simultáneos conservan Casa, Trabajo, lugar y viaje y sobreviven al reinicio',
    () async {
      final controller = container.read(localLibraryProvider.notifier);
      final trip = LibraryItem.journey(
        const JourneyEndpoints(origin: a, destination: b),
      );
      await Future.wait([
        controller.setSpecial(LibraryKind.home, a),
        controller.setSpecial(LibraryKind.work, b),
        controller.toggle(
          const LibraryItem(
            id: 'place:a',
            kind: LibraryKind.place,
            label: 'Origen de prueba',
            point: a,
          ),
        ),
        controller.toggle(trip),
      ]);
      expect(
        container.read(localLibraryProvider).requireValue.items,
        hasLength(4),
      );
      final fresh = ProviderContainer();
      try {
        final state = await fresh.read(localLibraryProvider.future);
        expect(state.special(LibraryKind.home)!.point!.id, 'a');
        expect(state.contains(trip.id), isTrue);
        await fresh.read(localLibraryProvider.notifier).reorder([
          trip.id,
          'line:example',
          'home',
          'work',
          'place:a',
        ]);
        expect(
          fresh.read(localLibraryProvider).requireValue.order.first,
          trip.id,
        );
      } finally {
        fresh.dispose();
      }
    },
  );
  test(
    'toggle quita el mismo viaje y editar Casa conserva una sola ubicación',
    () async {
      final controller = container.read(localLibraryProvider.notifier);
      final trip = LibraryItem.journey(
        const JourneyEndpoints(origin: a, destination: b),
      );
      await controller.toggle(trip);
      await controller.toggle(trip);
      await controller.setSpecial(LibraryKind.home, a);
      await controller.setSpecial(LibraryKind.home, b);
      final state = container.read(localLibraryProvider).requireValue;
      expect(state.items, hasLength(1));
      expect(state.special(LibraryKind.home)!.point!.id, 'b');
    },
  );
  test('JSON dañado se informa sin sobrescribir el contenido', () async {
    SharedPreferences.setMockInitialValues({
      LibraryController.storageKey: 'broken',
    });
    final scope = ProviderContainer();
    try {
      await expectLater(
        scope.read(localLibraryProvider.future),
        throwsFormatException,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          LibraryController.storageKey,
        ),
        'broken',
      );
    } finally {
      scope.dispose();
    }
  });
}

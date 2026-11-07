import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/place_result.dart';
import 'library_models.dart';
export 'library_models.dart';
import '../sync/personal_data.dart';

final localLibraryProvider =
    AsyncNotifierProvider<LibraryController, LocalLibrary>(
      LibraryController.new,
      retry: (count, error) => null,
    );

class LibraryController extends AsyncNotifier<LocalLibrary> {
  static const storageKey = 'library.v1';
  @override
  FutureOr<LocalLibrary> build() {
    ref.watch(personalScopeProvider);
    ref.listen(personalDataProvider, (previous, next) {
      if (!ref.mounted || state.isLoading) return;
      if (!next.isLoading && next.hasValue) {
        state = AsyncData(libraryFrom(next.requireValue));
      }
      if (next.hasError) state = AsyncError(next.error!, next.stackTrace!);
    });
    final data = ref.read(personalDataProvider);
    if (data.hasError) Error.throwWithStackTrace(data.error!, data.stackTrace!);
    if (!data.isLoading && data.hasValue) return libraryFrom(data.requireValue);
    return ref.read(personalDataProvider.future).then(libraryFrom);
  }

  Future<void> _change(LocalLibrary Function(LocalLibrary) change) async {
    final scope = ref.read(personalScopeProvider);
    await ref.read(personalDataProvider.notifier).changeLibrary(change);
    if (ref.mounted && ref.read(personalScopeProvider) == scope) {
      state = AsyncData(
        libraryFrom(ref.read(personalDataProvider).requireValue),
      );
    }
  }

  Future<void> toggle(LibraryItem item) => _change((current) {
    final exists = current.contains(item.id);
    return LocalLibrary(
      items: exists
          ? current.items.where((value) => value.id != item.id).toList()
          : [...current.items, item],
      order: exists
          ? current.order.where((id) => id != item.id).toList()
          : [...current.order.where((id) => id != item.id), item.id],
    );
  });
  Future<void> setSpecial(LibraryKind kind, PlaceResult point) {
    if (kind != LibraryKind.home && kind != LibraryKind.work) {
      throw ArgumentError('Not a special place');
    }
    return _change(
      (current) => LocalLibrary(
        items: [
          ...current.items.where((item) => item.kind != kind),
          LibraryItem(
            id: kind.name,
            kind: kind,
            label: point.name,
            point: point,
          ),
        ],
        order: current.order.contains(kind.name)
            ? current.order
            : [...current.order, kind.name],
      ),
    );
  }

  Future<void> remove(String id) => _change(
    (current) => LocalLibrary(
      items: current.items.where((item) => item.id != id).toList(),
      order: current.order.where((value) => value != id).toList(),
    ),
  );
  Future<void> reorder(List<String> ids) => _change(
    (current) =>
        LocalLibrary(items: current.items, order: ids.toSet().toList()),
  );
}

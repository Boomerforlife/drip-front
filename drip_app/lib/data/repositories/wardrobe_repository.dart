import 'dart:typed_data';

import '../api/api_client.dart';
import '../mock/mock_content.dart';
import '../models/wardrobe.dart';
import 'local_store.dart';

abstract interface class WardrobeRepository {
  Future<List<WardrobeItem>> items();

  /// Signed upload → PUT the photo → confirm. Returns the item in
  /// `processing`; a background job cuts it out and tags it, so poll
  /// [items] until it's ready (or failed). Never a live model call.
  Future<WardrobeItem> upload(Uint8List bytes, {required String contentType});

  /// Saves a catalog garment (its cutout and tags are copied over).
  Future<WardrobeItem> saveGarment(String garmentId);

  /// Corrects the tags. Only [slot] and [colour] are editable, and only with
  /// values from `GET /meta`.
  Future<void> update(String id, {String? slot, String? colour});
  Future<void> remove(String id);

  // "In rotation" has no backend field yet, so it's kept on the device.
  Future<List<String>> rotationIds();
  Future<void> setRotation(String id, {required bool inRotation});
}

class ApiWardrobeRepository implements WardrobeRepository {
  ApiWardrobeRepository(this._api, this._store);
  final ApiClient _api;
  final LocalStore _store;

  static WardrobeItem _item(Object? json) =>
      WardrobeItem.fromJson((json as Map).cast<String, dynamic>());

  @override
  Future<List<WardrobeItem>> items() async {
    final json = await _api.get('/wardrobe/items') as Map;
    return [for (final i in (json['items'] as List?) ?? const []) _item(i)];
  }

  @override
  Future<WardrobeItem> upload(
    Uint8List bytes, {
    required String contentType,
  }) async {
    final slot =
        await _api.post('/wardrobe/uploads/upload-url', {
              'contentType': contentType,
            })
            as Map;
    await _api.upload(
      slot['uploadUrl'] as String,
      bytes,
      contentType: contentType,
    );
    return _item(await _api.post('/wardrobe/uploads', {'path': slot['path']}));
  }

  @override
  Future<WardrobeItem> saveGarment(String garmentId) async =>
      _item(await _api.post('/wardrobe/items', {'garmentId': garmentId}));

  @override
  Future<void> update(String id, {String? slot, String? colour}) =>
      _api.patch('/wardrobe/items/$id', {
        'category': ?slot,
        'colour': ?colour,
      });

  @override
  Future<void> remove(String id) async {
    await _api.delete('/wardrobe/items/$id');
    final rotation = _store.rotation..remove(id);
    await _store.setRotation(rotation);
  }

  @override
  Future<List<String>> rotationIds() async => _store.rotation.toList();

  @override
  Future<void> setRotation(String id, {required bool inRotation}) async {
    final rotation = _store.rotation;
    inRotation ? rotation.add(id) : rotation.remove(id);
    await _store.setRotation(rotation);
  }
}

/// Fixture wardrobe for tests. Uploads come back `processing` and turn
/// `ready` on the next [items] call, like the real background job.
class MockWardrobeRepository implements WardrobeRepository {
  final List<WardrobeItem> _items = List.of(MockContent.wardrobe);
  final Set<String> _rotation = {...MockContent.rotationIds};

  Future<void> _latency([int ms = 250]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<List<WardrobeItem>> items() async {
    await _latency();
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].isProcessing) {
        _items[i] = WardrobeItem.fromJson({
          'id': _items[i].id,
          'status': 'ready',
          'category': 'outer',
          'colour': 'black',
          'origin': 'upload',
          'image': MockContent.captureImage,
        });
      }
    }
    return List.unmodifiable(_items);
  }

  @override
  Future<WardrobeItem> upload(
    Uint8List bytes, {
    required String contentType,
  }) async {
    await _latency();
    final item = WardrobeItem.fromJson({
      'id': 'w_${DateTime.now().microsecondsSinceEpoch}',
      'status': 'processing',
      'origin': 'upload',
      'image': MockContent.captureImage,
    });
    _items.insert(0, item);
    return item;
  }

  @override
  Future<WardrobeItem> saveGarment(String garmentId) async {
    final item = WardrobeItem.fromJson({
      'id': 'w_$garmentId',
      'status': 'ready',
      'origin': 'saved',
      'garmentId': garmentId,
      'category': 'top',
      'image': MockContent.captureImage,
    });
    _items.insert(0, item);
    return item;
  }

  @override
  Future<void> update(String id, {String? slot, String? colour}) async {
    await _latency(150);
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final old = _items[i];
    _items[i] = old.copyWith(
      category: slot == null ? null : WardrobeItem.categoryLabel(slot),
      colorway: colour,
    );
  }

  @override
  Future<void> remove(String id) async {
    await _latency(150);
    _items.removeWhere((e) => e.id == id);
    _rotation.remove(id);
  }

  @override
  Future<List<String>> rotationIds() async => _rotation.toList();

  @override
  Future<void> setRotation(String id, {required bool inRotation}) async {
    inRotation ? _rotation.add(id) : _rotation.remove(id);
  }
}

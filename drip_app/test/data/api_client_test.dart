import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:drip/data/api/api_client.dart';
import 'package:drip/data/models/stylist.dart';
import 'package:drip/data/repositories/studio_repository.dart';
import 'package:drip/data/repositories/feed_repository.dart';
import 'package:drip/data/repositories/stylist_repository.dart';
import 'package:drip/data/repositories/wardrobe_repository.dart';
import 'package:drip/data/repositories/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

const _base = 'https://api.test';

http.Response _json(Object body, [int status = 200, Map<String, String>? h]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...?h},
    );

void main() {
  late FakeAuthRepository auth;
  setUp(() => auth = FakeAuthRepository(signedIn: true));

  ApiClient client(MockClientHandler handler) =>
      ApiClient(baseUrl: _base, auth: auth, client: MockClient(handler));

  group('ApiClient', () {
    test('sends the bearer token, but not to /meta', () async {
      final seen = <String, String?>{};
      final api = client((req) async {
        seen[req.url.path] = req.headers['Authorization'];
        return _json({'ok': true});
      });
      await api.get('/me');
      await api.get('/meta');
      expect(seen['/me'], 'Bearer test-token');
      expect(seen['/meta'], isNull);
    });

    test('a 401 refreshes the session once and retries', () async {
      var calls = 0;
      final api = client((req) async {
        calls++;
        return req.headers['Authorization'] == 'Bearer refreshed-token'
            ? _json({'user': {}})
            : _json({'error': 'Invalid token'}, 401);
      });
      await api.get('/me');
      expect(calls, 2);
      expect(auth.refreshes, 1);
      expect(auth.isSignedIn, isTrue);
    });

    test('signs out when the refreshed token is refused too', () async {
      auth.refreshSucceeds = false;
      final api = client((_) async => _json({'error': 'Expired'}, 401));
      await expectLater(
        api.get('/me'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(auth.isSignedIn, isFalse);
    });

    test('waits out a short Retry-After once', () async {
      var calls = 0;
      final api = client((_) async {
        calls++;
        return calls == 1
            ? _json({'error': 'Too many'}, 429, {'retry-after': '0'})
            : _json({'items': []});
      });
      await api.get('/scroll');
      expect(calls, 2);
    });

    test('surfaces a long Retry-After instead of waiting', () async {
      final api = client(
        (_) async => _json({'error': 'Too many'}, 429, {'retry-after': '60'}),
      );
      await expectLater(
        api.get('/scroll'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isRateLimited, 'rate limited', isTrue)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 60),
              ),
        ),
      );
    });

    test('parses { error, details } and maps 204 to null', () async {
      final api = client((req) async {
        if (req.method == 'PUT') return http.Response('', 204);
        return _json({
          'error': 'Invalid fit',
          'details': ['one item per slot'],
        }, 400);
      });
      expect(await api.put('/outfits/x/save'), isNull);
      await expectLater(
        api.post('/studio/fits', {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Invalid fit')
              .having((e) => e.details, 'details', ['one item per slot']),
        ),
      );
    });

    test('a network failure is status 0 with friendly copy', () async {
      final api = client((_) async => throw http.ClientException('offline'));
      await expectLater(
        api.get('/me'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNetwork, 'network', isTrue)
              .having((e) => e.friendly, 'friendly', contains("Can't reach")),
        ),
      );
    });

    test(
      'uploads PUT raw bytes to the signed URL with its content type',
      () async {
        late http.Request put;
        final api = ApiClient(
          baseUrl: _base,
          auth: auth,
          uploadHeaders: const {'apikey': 'pub'},
          client: MockClient((req) async {
            put = req;
            return http.Response('{}', 200);
          }),
        );
        await api.upload(
          'https://storage.test/upload/sign/x.jpg?token=t',
          Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
        );
        expect(put.method, 'PUT');
        expect(put.headers['Content-Type'], startsWith('image/jpeg'));
        expect(put.headers['apikey'], 'pub');
        expect(put.headers.containsKey('Authorization'), isFalse);
        expect(put.bodyBytes, [1, 2, 3]);
      },
    );
  });

  group('API repositories', () {
    test('scroll pages parse outfits, prices in INR and the cursor', () async {
      final api = client((req) async {
        expect(req.url.queryParameters['cursor'], '10');
        return _json({
          'items': [
            {
              'id': 'f1',
              'kind': 'collage',
              'image': 'https://cdn.test/f1.png',
              'dripRate': 87,
              'price': {'amount': 2499, 'currency': 'INR'},
              'colourStory': 'Tonal navy',
              'formality': 2,
              'season': ['summer'],
              'layoutTemplate': 'stack-3',
              'pieces': [
                {
                  'name': 'Boxy tee',
                  'category': 'top',
                  'price': {'amount': 999, 'currency': 'INR'},
                  'image': 'https://cdn.test/g1.png',
                  'buyUrl': 'https://shop.test/tee',
                },
              ],
              'hotspots': [
                {'label': 'Boxy tee', 'slot': 'top', 'x': 0.5, 'y': 0.2},
              ],
            },
          ],
          'nextCursor': null,
        });
      });
      final page = await ApiFeedRepository(api).page(cursor: '10');
      final o = page.items.single;
      expect(page.nextCursor, isNull);
      expect(o.title, 'Tonal navy');
      expect(o.price, 2499);
      expect(o.rate, 87);
      expect(o.isCollage, isTrue);
      expect(o.pieces.single.slot, 'TOP');
      expect(o.pieces.single.buyUrl, 'https://shop.test/tee');
      expect(o.hotspots.single.label, 'BOXY TEE');
      expect(o.tags, containsAll(['relaxed', 'summer']));
    });

    test('an occasion feed asks the server to filter', () async {
      final api = client((req) async {
        expect(req.url.queryParameters['occasion'], 'wedding');
        return _json({'items': [], 'nextCursor': null});
      });
      final page = await ApiFeedRepository(api).page(occasion: 'wedding');
      expect(page.items, isEmpty);
    });

    test('a Studio fit saves every accessory with its box and draw order, '
        'and reads them back by canvas key', () async {
      const top = '11111111-1111-4111-8111-111111111111';
      const bag = '22222222-2222-4222-8222-222222222222';
      const watch = '33333333-3333-4333-8333-333333333333';
      late Map<String, dynamic> sent;
      final api = client((req) async {
        sent = (jsonDecode(req.body) as Map).cast<String, dynamic>();
        return _json({
          'id': 'uf1',
          'name': 'Beach',
          'pieces': [
            for (final i in sent['items'] as List)
              {
                'id': i['garmentId'] ?? i['wardrobeItemId'],
                'source': i['garmentId'] != null ? 'catalog' : 'wardrobe',
                'name': 'piece',
                'brand': i['garmentId'] != null ? 'Snitch' : null,
                'category': i['slot'],
                'image': 'https://cdn.test/p.png',
                'price': null,
                'slot': i['slot'],
                'position': i['position'] ?? 0,
                'box': i['box'],
                'z': i['z'],
              },
          ],
          'dripRate': 88,
          'price': null,
          'updatedAt': '2026-10-03T10:00:00Z',
        }, 201);
      });
      StudioPiece piece(String id, String category, [String? source]) =>
          StudioPiece(
            id: id,
            name: id,
            category: category,
            image: '',
            source: source ?? 'catalog',
          );
      final fit = await ApiStudioRepository(api).saveFit(
        name: 'Beach',
        worn: {
          'TOPS': piece(top, 'TOPS'),
          'ACCESSORIES': piece(bag, 'ACCESSORIES'),
          'ACCESSORIES:3': piece(watch, 'ACCESSORIES', 'wardrobe'),
        },
        placed: {'ACCESSORIES:3': const Rect.fromLTWH(0.7, 0.1, 0.2, 0.15)},
        stack: const ['TOPS', 'ACCESSORIES:3', 'ACCESSORIES'],
      );

      final items = (sent['items'] as List).cast<Map>();
      expect(items[0], {'slot': 'top', 'garmentId': top, 'z': 0});
      expect(items[1], {
        'slot': 'accessory',
        'garmentId': bag,
        'position': 0,
        'z': 2,
      });
      expect(items[2], {
        'slot': 'accessory',
        'wardrobeItemId': watch,
        'position': 2,
        'box': {
          'x': closeTo(0.7, 1e-9),
          'y': closeTo(0.1, 1e-9),
          'w': closeTo(0.2, 1e-9),
          'h': closeTo(0.15, 1e-9),
        },
        'z': 1,
      });

      expect(fit.pieces.keys, ['TOPS', 'ACCESSORIES', 'ACCESSORIES:3']);
      expect(fit.pieces['TOPS']!.brand, 'Snitch');
      expect(fit.pieces['ACCESSORIES:3']!.brand, isNull);
      expect(fit.boxes.keys, ['ACCESSORIES:3']);
      expect(fit.boxes['ACCESSORIES:3']!.width, closeTo(0.2, 1e-9));
      expect(fit.stack, ['TOPS', 'ACCESSORIES:3', 'ACCESSORIES']);
    });

    test(
      'Taylor picks a fit, then the app fetches it for the result',
      () async {
        final api = client((req) async {
          if (req.url.path == '/taylor') {
            expect(jsonDecode(req.body), {
              'occasion': 'Date Night',
              'vibe': 'Y2K Goth',
              'restrictToWardrobe': false,
            });
            return _json({
              'fit_id': 'f9',
              'reason': 'Dark layers for a late dinner.',
              'alternatives': ['f2'],
            });
          }
          return _json({
            'id': 'f9',
            'kind': 'photo',
            'image': 'https://cdn.test/f9.jpg',
            'dripRate': 91,
            'price': null,
            'pieces': [],
            'hotspots': [],
          });
        });
        final b = await ApiStylistRepository(api).generateBlueprint(
          occasion: 'Date Night',
          vibe: 'Y2K Goth',
          restrictToWardrobe: false,
          wardrobe: const [],
        );
        expect(b.fitId, 'f9');
        expect(b.reasoning, 'Dark layers for a late dinner.');
        expect(b.drip, 91);
        expect(b.alternatives, ['f2']);
      },
    );

    test("Taylor's 404 means there are no fits yet", () async {
      final api = client(
        (_) async => _json({'error': 'No fits available yet'}, 404),
      );
      await expectLater(
        ApiStylistRepository(api).generateBlueprint(
          occasion: 'Concert',
          vibe: 'Y2K Goth',
          restrictToWardrobe: false,
          wardrobe: const [],
        ),
        throwsA(isA<NoFitsYet>()),
      );
    });

    test('a wardrobe upload is signed URL → PUT → confirm', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore(await SharedPreferences.getInstance());
      final calls = <String>[];
      final api = client((req) async {
        calls.add('${req.method} ${req.url.host}${req.url.path}');
        return switch (req.url.path) {
          '/wardrobe/uploads/upload-url' => _json({
            'uploadUrl': 'https://storage.test/sign/w.jpg',
            'path': 'wardrobe/u/abc.jpg',
          }, 201),
          '/wardrobe/uploads' => _json({
            'id': 'w1',
            'origin': 'upload',
            'status': 'processing',
            'image': 'https://storage.test/w.jpg?sig',
            'season': [],
            'styleTags': [],
            'addedAt': '2026-09-27T10:00:00Z',
          }, 202),
          _ => http.Response('', 200),
        };
      });
      final item = await ApiWardrobeRepository(
        api,
        store,
      ).upload(Uint8List.fromList([9]), contentType: 'image/jpeg');
      expect(calls, [
        'POST api.test/wardrobe/uploads/upload-url',
        'PUT storage.test/sign/w.jpg',
        'POST api.test/wardrobe/uploads',
      ]);
      expect(item.isProcessing, isTrue);
      expect(item.section, 'IN PROGRESS');
    });
  });
}

import 'dart:ui' show Rect;

import 'outfit.dart';
import 'stylist.dart';

/// A Gen job (`POST /gen` → poll `GET /gen/:id`).
class GenJob {
  const GenJob({
    required this.id,
    required this.fitId,
    required this.status,
    this.outputUrl,
    this.createdAt,
  });

  final String id;
  final String fitId;

  /// `queued | running | done | failed | fell_back`.
  final String status;

  /// `done`: a 1-hour signed URL (re-fetch the job for a fresh one).
  /// `fell_back`: the fit's collage; the credit was refunded.
  final String? outputUrl;
  final DateTime? createdAt;

  bool get isFinished =>
      status == 'done' || status == 'failed' || status == 'fell_back';
  bool get fellBack => status == 'fell_back';
  bool get failed => status == 'failed';

  factory GenJob.fromJson(Map<String, dynamic> json) => GenJob(
    id: (json['id'] ?? json['jobId']) as String,
    fitId: json['fitId'] as String? ?? '',
    status: json['status'] as String? ?? 'queued',
    outputUrl: json['outputUrl'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

/// A fit the user built in the Studio (`/studio/fits`). Private to them.
class UserFit {
  const UserFit({
    required this.id,
    required this.name,
    required this.pieces,
    this.boxes = const {},
    this.stack = const [],
    this.baseFitId,
    this.dripRate,
    this.price,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? baseFitId;

  /// Keyed by canvas key (TOPS, ACCESSORIES, ACCESSORIES:2…; see
  /// [StudioSlots.canvasKey]).
  final Map<String, StudioPiece> pieces;

  /// Where the user placed pieces (fractions of the canvas), by canvas key.
  /// Pieces without one sit where the layout puts them.
  final Map<String, Rect> boxes;

  /// Canvas keys back to front (the server's `z`).
  final List<String> stack;

  /// 0–100, null until the fit has at least two pieces.
  final int? dripRate;
  final int? price;
  final DateTime? updatedAt;

  factory UserFit.fromJson(Map<String, dynamic> json) {
    final pieces = <String, StudioPiece>{};
    final boxes = <String, Rect>{};
    final z = <String, int>{};
    for (final p in (json['pieces'] as List?) ?? const []) {
      if (p is! Map) continue;
      final key = StudioSlots.canvasKey(
        '${p['slot']}',
        (p['position'] as num?)?.toInt() ?? 0,
      );
      pieces[key] = StudioPiece.fromJson(p.cast<String, dynamic>());
      final box = p['box'];
      if (box is Map) {
        double v(String k) => (box[k] as num?)?.toDouble() ?? 0;
        boxes[key] = Rect.fromLTWH(v('x'), v('y'), v('w'), v('h'));
      }
      if (p['z'] is num) z[key] = (p['z'] as num).toInt();
    }
    // Pieces without a z keep the server's order, under the ones with one.
    final order = pieces.keys.toList();
    final stack = [...order]
      ..sort((a, b) {
        final byZ = (z[a] ?? -1).compareTo(z[b] ?? -1);
        return byZ != 0 ? byZ : order.indexOf(a).compareTo(order.indexOf(b));
      });
    return UserFit(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Studio fit',
      baseFitId: json['baseFitId'] as String?,
      pieces: pieces,
      boxes: boxes,
      stack: stack,
      dripRate: (json['dripRate'] as num?)?.round(),
      price: moneyAmount(json['price']),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

/// The user's own space (`GET /studio`): saved and liked fits, finished Gen
/// renders and the fits they built.
class StudioLibrary {
  const StudioLibrary({
    this.saved = const [],
    this.liked = const [],
    this.gen = const [],
    this.mine = const [],
  });

  final List<Outfit> saved;
  final List<Outfit> liked;
  final List<GenJob> gen;
  final List<UserFit> mine;

  factory StudioLibrary.fromJson(Map<String, dynamic> json) {
    List<Outfit> outfits(Object? v) => [
      for (final o in (v as List?) ?? const [])
        if (o is Map) Outfit.fromJson(o.cast<String, dynamic>()),
    ];
    return StudioLibrary(
      saved: outfits(json['saved']),
      liked: outfits(json['liked']),
      gen: [
        for (final g in (json['gen'] as List?) ?? const [])
          if (g is Map) GenJob.fromJson(g.cast<String, dynamic>()),
      ],
      mine: [
        for (final f in (json['mine'] as List?) ?? const [])
          if (f is Map) UserFit.fromJson(f.cast<String, dynamic>()),
      ],
    );
  }
}

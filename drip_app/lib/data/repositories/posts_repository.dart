import '../mock/mock_content.dart';
import '../models/ootd.dart';

/// Creator posts (OOTDs), stories, comments, reactions and DMs: the social
/// layer. It isn't in the v1 backend (founder decision: no social layer), so
/// only a mock exists; the UI that shows it says "coming after beta" when used.
abstract interface class PostsRepository {
  Future<List<Ootd>> feed();
  Future<List<Story>> stories();
  Future<Ootd?> ootd(String id);
  Future<Ootd> setLiked(String id, {required bool liked});
  Future<Ootd> setSaved(String id, {required bool saved});
  Future<Ootd> publish(Ootd post);
  Future<void> sendReaction(String ootdId, String reaction);
  Future<void> sendMessage(String ootdId, String message);
  Future<List<OotdComment>> comments(String ootdId);
  Future<OotdComment> addComment(String ootdId, String text);
  Future<void> recordShare(String ootdId);
}

class MockPostsRepository implements PostsRepository {
  final List<Ootd> _feed = List.of(MockContent.feed);

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<List<Ootd>> feed() async {
    await _latency();
    return List.unmodifiable(_feed);
  }

  @override
  Future<List<Story>> stories() async {
    await _latency();
    return MockContent.stories;
  }

  @override
  Future<Ootd?> ootd(String id) async {
    for (final o in _feed) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<Ootd> setLiked(String id, {required bool liked}) async {
    final i = _feed.indexWhere((o) => o.id == id);
    final o = _feed[i];
    if (o.isLiked == liked) return o;
    return _feed[i] = o.copyWith(
      isLiked: liked,
      likes: o.likes + (liked ? 1 : -1),
    );
  }

  @override
  Future<Ootd> setSaved(String id, {required bool saved}) async {
    final i = _feed.indexWhere((o) => o.id == id);
    final o = _feed[i];
    if (o.isSaved == saved) return o;
    return _feed[i] = o.copyWith(
      isSaved: saved,
      saves: o.saves + (saved ? 1 : -1),
    );
  }

  @override
  Future<Ootd> publish(Ootd post) async {
    await _latency();
    _feed.insert(0, post);
    return post;
  }

  @override
  Future<void> sendReaction(String ootdId, String reaction) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<void> sendMessage(String ootdId, String message) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  final Map<String, List<OotdComment>> _comments = {};

  @override
  Future<List<OotdComment>> comments(String ootdId) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List.unmodifiable(
      _comments.putIfAbsent(ootdId, () => MockContent.commentsFor(ootdId)),
    );
  }

  @override
  Future<OotdComment> addComment(String ootdId, String text) async {
    final list = _comments.putIfAbsent(
      ootdId,
      () => MockContent.commentsFor(ootdId),
    );
    final c = OotdComment(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      handle: 'taylor_drip',
      avatar: MockContent.myAvatar,
      text: text,
      ago: 'NOW',
    );
    list.insert(0, c);
    final i = _feed.indexWhere((o) => o.id == ootdId);
    if (i >= 0) _feed[i] = _feed[i].copyWith(comments: _feed[i].comments + 1);
    return c;
  }

  @override
  Future<void> recordShare(String ootdId) async {
    final i = _feed.indexWhere((o) => o.id == ootdId);
    if (i >= 0) _feed[i] = _feed[i].copyWith(shares: _feed[i].shares + 1);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_content.dart';
import '../../data/mock/mock_users.dart';
import '../../data/models/ootd.dart';
import '../home/feed_controller.dart';

class CreateOotdState {
  const CreateOotdState({
    this.imagePath,
    this.caption = MockContent.defaultCaption,
    this.tags = MockContent.seedCreateTags,
    this.visibility = 'Public',
    this.location = 'Tokyo Grid-9',
    this.drafts = 3,
    this.posting = false,
  });

  final String? imagePath;
  final String caption;
  final List<String> tags;
  final String visibility;
  final String location;
  final int drafts;
  final bool posting;

  CreateOotdState copyWith({
    String? imagePath,
    String? caption,
    List<String>? tags,
    String? visibility,
    String? location,
    int? drafts,
    bool? posting,
  }) => CreateOotdState(
    imagePath: imagePath ?? this.imagePath,
    caption: caption ?? this.caption,
    tags: tags ?? this.tags,
    visibility: visibility ?? this.visibility,
    location: location ?? this.location,
    drafts: drafts ?? this.drafts,
    posting: posting ?? this.posting,
  );
}

class CreateOotdController extends Notifier<CreateOotdState> {
  @override
  CreateOotdState build() => const CreateOotdState();

  void setImage(String path) => state = state.copyWith(imagePath: path);
  void setCaption(String v) => state = state.copyWith(caption: v);
  void setVisibility(String v) => state = state.copyWith(visibility: v);
  void setLocation(String v) => state = state.copyWith(location: v);

  void addTag(String raw) {
    var t = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return;
    if (!t.startsWith('#')) t = '#$t';
    if (state.tags.contains(t)) return;
    state = state.copyWith(tags: [...state.tags, t]);
  }

  void removeTag(String tag) => state = state.copyWith(
    tags: [
      for (final t in state.tags)
        if (t != tag) t,
    ],
  );

  /// Saves the current composition as a draft and clears the form.
  void saveDraft() {
    state = CreateOotdState(drafts: state.drafts + 1);
  }

  /// Publishes to the feed. Returns the new post.
  Future<Ootd?> post({String? overrideImage}) async {
    final image = overrideImage ?? state.imagePath ?? MockContent.createPreview;
    state = state.copyWith(posting: true);
    final me = MockUsers.me;
    final post = Ootd(
      id: 'ootd_${DateTime.now().millisecondsSinceEpoch}',
      creatorHandle: me.handle,
      creatorAvatar: me.avatar,
      image: image,
      title: state.caption.split(RegExp(r'[.!?]')).first.trim().isEmpty
          ? 'New OOTD'
          : state.caption.split(RegExp(r'[.!?]')).first.trim(),
      era: state.tags.isEmpty ? 'DRIP' : state.tags.first.replaceFirst('#', ''),
      score: 90,
      likes: 0,
      saves: 0,
      tags: state.tags,
      postedAgo: 'JUST NOW',
      caption: state.caption,
      location: state.location,
    );
    await ref.read(postsProvider.notifier).publish(post);
    if (!ref.mounted) return post;
    state = const CreateOotdState();
    return post;
  }
}

final createOotdProvider =
    NotifierProvider<CreateOotdController, CreateOotdState>(
      CreateOotdController.new,
    );

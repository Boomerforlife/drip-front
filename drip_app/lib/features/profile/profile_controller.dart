import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_content.dart';
import '../../data/mock/mock_users.dart';
import '../../data/models/ootd.dart';
import '../../data/models/outfit.dart';
import '../home/feed_controller.dart';
import '../outfits/outfit_controller.dart';

/// Looks shown on a profile's FITS tab.
final profileFitsProvider = Provider.family<List<Outfit>, String>((
  ref,
  handle,
) {
  final catalog = ref.watch(outfitCatalogProvider).value ?? const <Outfit>[];
  final bespokeIds =
      MockContent.profileFits[handle]?.map((o) => o.id).toList() ??
      const <String>[];
  final bespoke = [
    for (final id in bespokeIds)
      catalog.firstWhere(
        (o) => o.id == id,
        orElse: () =>
            MockContent.profileFits[handle]!.firstWhere((o) => o.id == id),
      ),
  ];
  final authored = catalog
      .where((o) => o.creatorHandle == handle && !bespokeIds.contains(o.id))
      .toList();
  // Newest first: anything the user just published leads.
  return [
    ...authored.where((o) => o.id.startsWith('o_studio_')),
    ...bespoke,
    ...authored.where((o) => !o.id.startsWith('o_studio_')),
  ];
});

/// Feed posts authored by [handle] (OOTD tab).
final profilePostsProvider = Provider.family<List<Ootd>, String>((ref, handle) {
  final feed = ref.watch(postsProvider).value ?? const <Ootd>[];
  return feed.where((p) => p.creatorHandle == handle).toList();
});

/// Private accounts the user has requested access to.
class AccessRequestsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String handle) => state = state.contains(handle)
      ? ({...state}..remove(handle))
      : {...state, handle};
}

final accessRequestsProvider =
    NotifierProvider<AccessRequestsController, Set<String>>(
      AccessRequestsController.new,
    );

bool isMe(String handle) => handle == MockUsers.meHandle;

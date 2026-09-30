/// The caller's backend profile (`GET /me`): onboarding picks, Gen credits and
/// the avatar photos Gen renders from. Identity (name, photo) comes from the
/// Google account instead, see `AuthUser`.
class Account {
  const Account({
    required this.id,
    this.onboardingPrefs = const {},
    this.skinTone,
    this.styleTags = const [],
    this.genCreditsRemaining = 0,
    this.avatarUrls = const [],
    this.createdAt,
  });

  final String id;
  final Map<String, dynamic> onboardingPrefs;
  final String? skinTone;
  final List<String> styleTags;
  final int genCreditsRemaining;

  /// 1-hour signed URLs, newest first. Display only, never persist.
  final List<String> avatarUrls;
  final DateTime? createdAt;

  bool get hasAvatar => avatarUrls.isNotEmpty;

  factory Account.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Account(
      id: user['id'] as String? ?? '',
      onboardingPrefs:
          (user['onboarding_prefs'] as Map?)?.cast<String, dynamic>() ??
          const {},
      skinTone: user['skin_tone'] as String?,
      styleTags: [
        for (final t in (user['style_tags'] as List?) ?? const []) '$t',
      ],
      genCreditsRemaining: (json['genCreditsRemaining'] as num?)?.toInt() ?? 0,
      avatarUrls: [
        for (final u in (json['avatarUrls'] as List?) ?? const []) '$u',
      ],
      createdAt: DateTime.tryParse(user['created_at'] as String? ?? ''),
    );
  }
}

/// The caller's backend profile (`GET /me`): onboarding picks, Gen credits,
/// and the public profile the user sets (username, display name, profile
/// photo). Until they set one, the profile falls back to the Google account
/// (`AuthUser`). Selfies are not here: they stay on the device
/// (`LocalSelfie`).
class Account {
  const Account({
    required this.id,
    this.onboardingPrefs = const {},
    this.skinTone,
    this.styleTags = const [],
    this.genCreditsRemaining = 0,
    this.avatarUrls = const [],
    this.username,
    this.displayName,
    this.photoUrl,
    this.isAdmin = false,
    this.createdAt,
  });

  final String id;
  final Map<String, dynamic> onboardingPrefs;
  final String? skinTone;
  final List<String> styleTags;
  final int genCreditsRemaining;

  /// Gen selfies an older build uploaded (1-hour signed URLs). The API no
  /// longer collects or returns them; kept so old responses still parse.
  final List<String> avatarUrls;

  /// The handle the user picked (`a–z 0–9 . _`, 3–24), without the `@`.
  final String? username;
  final String? displayName;

  /// The profile picture (public URL).
  final String? photoUrl;

  /// May review imported products (`/admin/review`).
  final bool isAdmin;
  final DateTime? createdAt;

  bool get hasAvatar => avatarUrls.isNotEmpty;

  Account copyWith({
    Map<String, dynamic>? onboardingPrefs,
    List<String>? styleTags,
    String? skinTone,
    String? username,
    String? displayName,
    String? photoUrl,
    bool clearPhoto = false,
  }) => Account(
    id: id,
    onboardingPrefs: onboardingPrefs ?? this.onboardingPrefs,
    skinTone: skinTone ?? this.skinTone,
    styleTags: styleTags ?? this.styleTags,
    genCreditsRemaining: genCreditsRemaining,
    avatarUrls: avatarUrls,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    photoUrl: clearPhoto ? null : photoUrl ?? this.photoUrl,
    isAdmin: isAdmin,
    createdAt: createdAt,
  );

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
      username: json['username'] as String? ?? user['username'] as String?,
      displayName:
          json['displayName'] as String? ?? user['display_name'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      createdAt: DateTime.tryParse(user['created_at'] as String? ?? ''),
    );
  }
}

/// `GET /me/username-available`.
class UsernameCheck {
  const UsernameCheck(this.username, {required this.available, this.reason});
  final String username;
  final bool available;
  final String? reason;
}

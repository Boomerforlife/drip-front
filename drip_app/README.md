# Drip — Flutter frontend

Mobile frontend for **Drip**, the outfit-of-the-day app, built from the supplied Figma file (`../canvas.fig`).
It talks to the Drip backend (`../../Backend_app`): Supabase for Google sign-in only, and the Drip API for
everything else. The contract is `Backend_app/docs/API.md`; the integration rules are
`Backend_app/docs/INTEGRATION.md`.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=config/dev.json      # any connected Android device
flutter test                                              # fixtures only, no network
flutter analyze
```

`config/dev.json` holds `API_BASE_URL`, `SUPABASE_URL` and the Supabase **publishable** key, which is public by
design (it ships in the app; RLS protects the data). Never put a secret or service-role key in the app. Built without
the defines, the app shows a "missing configuration" screen instead of failing on its first request.

Google sign-in returns through `com.drip.drip://login-callback` (Android intent filter + iOS URL type). That URL
must be listed in Supabase → Authentication → URL Configuration → Redirect URLs.

`flutter run -d chrome` needs the API's `CORS_ORIGINS` to include `http://localhost:5555` and
`--web-port 5555`; use a phone or `-d windows` until that's set on Railway.

Requires Flutter 3.47+ (Dart 3.13).

## Architecture

```
lib/
  core/            theme (tokens from Figma), shared widgets, formatting, config/env.dart
  data/
    api/           ApiClient: bearer token, 401 refresh-and-retry, 429 Retry-After, { error } parsing, uploads
    models/        immutable domain models, each with fromJson for the API shape
    mock/          fixture data (tests, and the after-beta social screens)
    repositories/  interface + Api* implementation + Mock* fixture per data source
    providers.dart Riverpod wiring: the app gets Api*, tests override with Mock* (test/support/fakes.dart)
  features/<x>/    screens + controllers (Riverpod Notifiers)
  routing/         go_router config, floating-nav shell, auth guard
```

`UI → controller (Riverpod) → repository interface → Api* (HTTP) → Drip API`.

## What's live vs. after beta

Live against the API: Google sign-in (the first request creates the account), onboarding picks
(`PATCH /me`), the Fashion Scroll and Home fits (`/scroll`, paged, with open/skip signals), likes and saves,
Fit Analysis (`/outfits/:id`), Saved Looks and your Studio fits (`/studio`), the wardrobe (signed upload →
background cut-out and tagging, polled until ready; retag category/colour; delete), the Studio canvas
(`/studio/pieces`, `/studio/fits`, server-computed drip rate), Taylor (`/taylor` + the picked fit), Gen
photoshoots (selfie upload, credits, job polling), Colour Theory seasons (`/colour/seasons`), account deletion.

Prices are INR (`₹1,499`). Personal images (wardrobe uploads, selfies, Gen renders) are 1-hour signed URLs: shown,
never stored, refetched when stale.

Kept in the UI but "coming after beta" when used (no v1 backend, founder decision): stories, comments, sharing,
following, DMs and notifications, posting OOTDs, public profiles, Discover and search, profile editing, privacy
controls, photoshoot edits. Phone sign-in is hidden for now (Google only). The rotation flag is stored on the device (no backend field).

Still mocked on screen: the Home weather card and the bag (no checkout).

## Design source

`reference/` (project root) holds PNG renders of every Figma frame used for visual comparison.
Fonts (DM Mono, Bungee, Manrope, Inter, Fredoka) and the symbol/emoji fallbacks are bundled in
`assets/fonts`; photos were exported from the Figma file to `assets/images`.


## Refinement pass: what changed

On top of the original Figma build; the information architecture, data layer and existing screens were kept, and
this pass refined look, motion, navigation and performance.

### Home
- Restructured to the hand-drawn wireframe: DRIP wordmark + messages/notifications (after beta) →
  horizontally scrolling **Stories** → the **featured fit** → a "Today's Drip" info bar (with the Ask Taylor entry) →
  a two-column grid of fresh fits → floating navigation.
- Stories are larger (76px), with an accent→secondary ring for unseen and a hairline once seen, plus a "Your story" add.
- Featured fit: tap opens it in the Fashion Scroll (the image expands into place); double-tap likes with a heart burst.
- **Search left the Home header.** It lives in **Discover**, reached from the "SEARCH & DISCOVER →" link on Home
  (after beta: there's no search endpoint yet).
- Pull to refresh, skeleton placeholders shaped like the real layout while loading.

### Fashion Scroll (`/scroll`)
- Immersive, full-bleed vertical pager: one fit per screen, snapping, next image pre-cached.
- Curated-by-Drip row (follow is after beta), title, kind and tag chips, a "shop the look" strip
  ("N pieces · ₹total") and the DRIP score.
- Action rail: like and save (live), comments and share (after beta).
- Pages from `/scroll`: the next page loads near the end, and the last page is a "caught up" card. Each card reports
  `open` or `skip` with how long it was on screen. Double-tap to like; opens on a specific fit via `?id=`.
- The Home card's photo flies into place (Hero) with an animating corner radius. This only happens when you open
  from a card, never during a tab swipe.

### Navigation and gestures
- Floating glass bottom bar, **icons only** (no labels; semantic labels are kept for screen readers). The "$" slot
  became the ellipse-and-star **reel** glyph (`lib/core/widgets/nav_glyphs.dart`, fitted to the reference).
- Tap a tab, or drag on the bar to scrub the selection lens (1:1 tracking, haptic ticks, rubber-band at the ends,
  momentum projection on release).
- **Swipe anywhere on a tab root** to move to the neighbouring tab (Home ↔ Scroll ↔ Wardrobe ↔ You). The screen follows
  the finger with resistance, buzzes when the swipe is far enough, and a short quick flick also counts. Horizontal
  lists (stories, the theme bar, carousels) claim their own drags first, so nothing fights.
- Tab changes are a plain sideways page push (position only, no fading) so they stay cheap on mid-range phones.

### Themes ("worlds")
13 poster-based themes (`lib/core/theme/drip_skin.dart`). The default is the black/white/red/blue flare poster. A theme
is a whole world, not a recolour:
- **Ground**: the tinted near-black the app sits on (blue-black, oxblood-black, moss-black...).
- **Surfaces**: cards, inputs, chips and borders are re-derived from the ground and poster wash
  (`AppColors.useSurfaces`); the default theme keeps the original Figma values exactly.
- **Headline typeface**: poster caps (Bungee), soft and rounded (Fredoka) or clean editorial (Manrope ExtraBold).
- **Glass character**: clarity (frosted paper → clear crystal) and corner roundness (archival = squarer,
  bloom = pillowy). The Home cards' corners follow it too.
- **Backdrop**: a quiet composition: the poster as faint texture plus one pool of its light, placed differently per theme.
- **Accent / secondary**: used sparingly (create button, story rings, links, chips, profile handle and ring).
- Switch from the **customization bar** (Profile and Settings: colour swatches, one tap) or the **poster carousel**
  (`/themes`), which previews the entire app live and reverts if you leave without applying.
- Changing theme cross-fades the backdrop and rebuilds the app once so every screen takes the new surfaces and type.

### App icon
- The launcher icon is the poster of the selected theme; the default is the flare poster. "Match App Icon to Theme" in
  Settings turns this off (the default icon returns).
- Android: one `<activity-alias>` per theme + a small Kotlin channel (`MainActivity.kt`). iOS: alternate icon sets +
  a Swift channel (`AppDelegate.swift`). Dart side: `lib/core/platform/app_icon.dart`.
- **Android swaps the icon only when you leave the app.** Switching the alias while the app is open restarted it (it
  looked like a crash right after changing theme). iOS can only change the icon in the foreground and never restarts,
  so it is debounced instead.

### Launch and loading
- ~1.1s launch sequence: the wordmark resolves out of a blur, the red "i" drop pulses, tap to skip; it pre-warms the
  feed, stories and catalogue and pre-caches images. Native launch screens use the base colour so there is no white flash.
- One loading language: shimmer skeletons with a shared clock (`core/widgets/skeleton.dart`), a drop-pulse indicator,
  tinted image placeholders, and designed failure states (no blank flashes, no spinners over content).

### Visual refinement
- **Glass** (`core/widgets/glass.dart`) is the translucent material: floating nav, big plates and sheets get a real
  backdrop blur; small chips are tinted only (a live blur per chip was too costly).
- Calmer overall: solid saturated accent slabs became quiet tinted pills, the nav lens is neutral glass, the create
  button is smaller with no glow, and the backdrop is dark and quiet.
- Motion vocabulary in `core/motion.dart` (durations, ease-out curves, critically damped springs, semantic haptics);
  reduced-motion turns movement into short fades. Accessible labels, 44px hit targets, high-contrast solid glass.

### Performance
- Tab transitions no longer fade whole screens (two offscreen layers per change); they slide.
- Thin glass surfaces no longer run a live blur (the Fashion Scroll had ~7 over a full-screen photo); regular/thick blur
  strengths lowered.
- Backdrop image uses an opacity parameter instead of an `Opacity` layer; avatars decode at their display size.
- Hero flights are disabled for tab moves; the swipe wrapper repaints only a translated layer.

### Tests and tooling
- `flutter test`: 80 tests (API client: auth header, 401 refresh-and-retry, 429 Retry-After, errors, uploads; API
  repositories against canned responses; controllers; sign-in → onboarding sync → logout; feed paging and signals;
  nav tap/drag/rubber-band, swipe-anywhere, Home → Scroll; after-beta messages; themes and live preview; icon-swap
  timing per platform; launch; five screen sizes). Tests use `test/support/fakes.dart`, never the network.
- `flutter test tool/capture_test.dart --dart-define=OUT=<dir>` renders real screenshots (fonts, assets, blur) of key
  screens and skins for visual review.
- `python tool/build_assets.py` (needs `posters/poster_XX.jpg`) regenerates theme art, the wordmark and the icons;
  then `dart run flutter_launcher_icons`.

### Known limits
- iOS alternate icons and the Swift channel are written but **not built or run** (no Mac here).
- The poster art was captured at ~658px, so enlarged icons are slightly grainy.
- Launchers can take a few seconds to refresh a changed icon.
- After a theme switches the icon, `flutter run` can't launch (it starts the default alias, now disabled).
  Re-enable it: `adb shell pm enable com.drip.drip/com.drip.drip.Alias_retro_cyber`.

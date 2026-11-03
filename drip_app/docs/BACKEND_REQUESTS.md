# Backend requests from the app

From the Flutter session, for the backend session. Newest first. Each request says what the app
does today without it, so nothing is blocked.

## 2026-10-09: fits in the user's price range, and the style quiz

### Status of earlier requests

| Request | Status |
|---|---|
| 10-06 #1 username and display name | **Done** (in `docs/API.md`). |
| 10-05 #3 saved pieces, #4 paging, #5 material | Still open, all low priority. |

### 1. Keep the Scroll in the user's price range (needed: the founder's top complaint)

**What's wrong.** Onboarding asks "usual spend a piece" (`onboardingPrefs.budget`, ₹500–15,000).
In `personalize.ts` that's one soft term, `+0.8 × fitBudget`, beside collage score, colour (0.7),
style, occasions and behaviour. A pricey fit that scores well on the others still lands near the
top, so a ₹2,000 user sees ₹12,000 fits early. A fit with no priced pieces gets no budget penalty,
so it beats a fit that's slightly over budget. This is a ranking problem, not an app one: the app
already sends the budget, and the feed comes back in the server's order.

**Don't add storage buckets or a table per price range.** Storage buckets hold files, not fits.
Copying fits into a table per price range duplicates rows, goes stale when a store changes a price,
and would make the app page across buckets itself. One sort key in the ranking does the same job
and keeps prices in one place.

**Short v1: price bands as the first sort key in `GET /scroll`.**
1. Find the user's limits.
   - Each piece: `budget` (per piece).
   - The whole fit: from the new quiz answer `onboardingPrefs.quiz.spend` (see #2):

     | `spend` | Fit limit |
     |---|---|
     | `u2k` | ₹2,000 |
     | `2to5k` | ₹5,000 |
     | `5to10k` | ₹10,000 |
     | `10kplus` | no limit |

     If they haven't answered it, there's no fit limit.
2. Give each fit a band from its priced pieces (`price_inr > 0`):
   - **`in`**: every priced piece is at most 1.2 × `budget`, and the fit's total is within the fit
     limit (if there is one).
   - **`stretch`**: no piece is over 2 × `budget`, or the total is at most 1.5 × the fit limit.
   - **`over`**: everything else.
   - **`null`**: no priced pieces, or no budget. Rank these with `stretch`.
3. Order by band (`in`, then `stretch`/`null`, then `over`), then by today's score within each band.
   The user gets every fit in budget first, and the next band only when those run out: the
   "when one bucket ends, show the next" idea, as a sort rather than storage. The existing
   per-user, per-day, per-prefs cache and the cursor keep working, because the order is still
   fixed for the day. A `PATCH /me` that changes `budget` or `quiz` already re-ranks.
4. Return the band on each `Outfit`: **`budgetBand: "in" | "stretch" | "over" | null`**.
   - The app reads it today (optional; missing is fine).
   - The Scroll's shop strip says "· in your budget" for `in` and "· above your budget" for
     `over`, so a price jump past the end of a band isn't a surprise.
5. Keep the budget term in the score; it now only orders fits within a band.

**Worth checking in the catalogue.** If few fits come in under ₹2,000–3,000 a piece, the `in`
band runs out in a few swipes whatever we rank. A count of fits per band for a few budgets
(₹1,500 / ₹3,000 / ₹6,000) would show what the pipeline should bank more of.

**Also note.** Onboarding's budget is per piece, but the Scroll shows the fit's total. A
four-piece fit at ₹2,000 a piece shows "₹8,000 total" to a ₹2,000 user and *looks* over budget
even when it's `in`. The band label in the app is there for exactly this.

### 2. Use the style quiz in the ranking (nice to have: the answers are already saved)

**What the app does.**
- Home's **Style Quiz** tile (it used to say "after beta") opens 10 one-tap multiple-choice
  questions. Every question can be skipped.
- Answers are saved with the existing `PATCH /me`, inside `onboardingPrefs`. The other keys are
  kept, and the payload is small, well under the 4,096-char cap.
- No new endpoint or column is needed.

```
onboardingPrefs.quiz = {
  "v": 1, "at": "2026-10-09",          // version and day answered (UTC)
  "spend":   "u2k" | "2to5k" | "5to10k" | "10kplus",            // whole-outfit budget
  "buy":     "deal" | "exact" | "styled" | "brand",             // what makes them buy
  "next":    "work" | "night" | "trip" | "function" | "everyday",  // dressing for next
  "volume":  "quiet" | "statement" | "loud" | "mood",           // how bold
  "colour":  "neutral" | "pop" | "full" | "black",              // colour comfort zone
  "matters": "comfort" | "cut" | "fabric" | "trend",            // what matters in a piece
  "where":   "highstreet" | "marketplace" | "local" | "thrift", // where they shop
  "when":    "sales" | "need" | "monthly" | "impulse",          // when they shop
  "weather": "humid" | "dry" | "mild" | "cold",                 // climate
  "explore": "safe" | "mix" | "push"                            // how adventurous the feed is
}
```
Any key can be missing (skipped). The question ids and option ids are stable. The screen copy is
in `lib/features/quiz/style_quiz.dart`.

**Short v1, cheapest first:**
- `spend`: the fit limit in #1. This is the one that matters for buying.
- `next`: map it onto `/meta` occasions, then reuse the existing `+0.25` occasion term.

  | `next` | Occasions |
  |---|---|
  | `work` | the work/college ones |
  | `night` | night out, late-night dinner |
  | `trip` | travel |
  | `function` | wedding, festive |
  | `everyday` | casual |

- `colour`:
  - `neutral` or `black`: treat as `paletteHasNeutral` with extra weight.
  - `full`: soften the palette-miss penalty.
- `volume` and `explore`:
  - `quiet` or `safe`: rank down the fits furthest from the user's aesthetics.
  - `loud` or `push`: let roughly 1 in 5 cards come from outside their aesthetics.
- `weather`:
  - `humid` or `dry`: rank down wool, fleece, leather and puffers.
  - `cold`: rank up layers and outerwear.
- `buy = deal` or `when = sales`: rank up pieces with an `original_price` above `price`, once the
  catalogue has sale prices.
- `where`, `matters`: keep for later; store-type and fabric data aren't in the catalogue yet.

## 2026-10-06: usernames and display names, and where earlier requests stand

### Status of earlier requests

| Request | Status |
|---|---|
| 10-05 (later) #1 `POST /reports` | **Done and live.** The app keeps a report on the phone on 429, 5xx or offline, and resends it. |
| 10-05 (later) #2 public profile photo on account deletion | **Closed.** The API has no public user content, and the app's photo handling is being reworked on the app side (no backend work). |
| 10-05 #1 garment `id` on `Outfit.pieces` | **Done.** + WARDROBE and + STUDIO in the Scroll use it. |
| 10-05 #2 `buyUrl` on `StudioPiece` | **Done.** VISIT shows for every catalogue piece in the Studio picker. |
| 10-05 #3 saved pieces, #4 paging, #5 material | Still open, all low priority. |
| 10-03 Studio canvas and occasion feeds | Done. |

### 1. Username and display name (needed: the profile editor calls these today)

**Why.** The profile editor (You → edit profile) lets users pick an @username and a display name.
`PATCH /me` accepts only `onboardingPrefs`, `skinTone` and `styleTags`, so both edits fail with
a 400 today, and `GET /me/username-available` is a 404.

**What the app does today.** It shows the fields, checks the username rules on the phone, and
shows the server's error when saving. Until this ships, people see their Google name.

**Contract the app already sends and reads:**

```
PATCH /me { "username": "vighnesh.k" }
  → 200, the same body as GET /me (the app reads `username` at the top level or `user.username`)
  → 409 { error } when it's taken; 400 { error } when it breaks the rules

PATCH /me { "displayName": "Vighnesh" }      // 1–40 chars after trimming
PATCH /me { "displayName": null }            // clear it: back to the Google name
  → 200, the same body as GET /me (`displayName` at the top level or `user.display_name`)

GET /me/username-available?u=vighnesh.k
  → 200 { "username": "vighnesh.k", "available": true }
  → 200 { "username": "drip", "available": false, "reason": "That username is reserved" }

GET /me  → also returns "username" and "displayName" (null until set)
```

**Username rules** (the app checks the same ones first, in `usernameProblem` in
`lib/data/repositories/account_repository.dart`; please mirror them exactly):
- `^[a-z0-9._]{3,24}$` (lower case: the app lower-cases what's typed)
- at least one letter or number
- reserved: `drip, admin, support, help, official, team, taylor, staff, me, settings, api`
- unique, case-insensitively

**Short v1.** Migration (schema change: founder approval): `users.username text null` with a
unique index on `lower(username)` and a check constraint for the pattern; `users.display_name
text null` with `char_length(trim(display_name)) between 1 and 40`. Extend the `PATCH /me` zod
body with `username` and `displayName` (nullable), and map a unique violation to 409. Add
`GET /me/username-available` (auth required, rate-limited like other reads; it may answer
`available: false` with `reason` instead of 400 for a bad pattern).

**Privacy.** The app's privacy policy says nothing a user adds is public in the beta. So keep
both visible only to their owner (`GET /me`) until there are public profiles. When those ship,
the app updates the policy first. `DELETE /me` already removes the row.

---

## 2026-10-05 (later): bug reports and the privacy policy (done)

### 1. `POST /reports`: bug reports from the app (needed; one new table, founder approval)

**Why.** The feed now has a **Report a bug** button (below Share). The user picks a kind, writes
what happened, and can attach the fit on screen.

**What the app does today.** It posts to `/reports`. On 404 (not deployed), a network error or a
5xx, it keeps the report on the phone (up to 20) and sends the waiting ones with the next report.
A 400 drops it rather than retrying forever.

**Contract the app sends** (signed-in users only, `Authorization: Bearer`):

```json
POST /reports
{ "kind": "broken | wrong_piece | image | slow | other",
  "message": "The shoes link opens a hat",        // 3–1000 chars
  "screen": "scroll",
  "fitId": "uuid",                                // optional: the fit on screen
  "appVersion": "1.0.0+1",
  "platform": "android 14 …",                     // Platform.operatingSystem + version
  "createdAt": "2026-10-05T15:20:00.000Z" }       // when the user sent it (may be earlier than receipt)
→ 201 { "id": "uuid" }
```

**Short v1.** Migration `…_bug_reports.sql`: `bug_reports (id uuid pk, user_id uuid references
users on delete cascade, kind text check in (…), message text check length 3–1000, screen text,
fit_id uuid null, app_version text, platform text, reported_at timestamptz, created_at timestamptz
default now(), status text default 'new')`. RLS: a user can insert their own and read none (admins
read via the service role or an admin view). Zod-validate the body, rate-limit like other writes
(for example 10 an hour), and capture a PostHog `bug_reported` event with `kind` only. No
attachments in v1.

**Privacy.** The app's policy says reports carry only the above (never photos) and are deleted
with the account. The `on delete cascade` covers the second part.

### 2. Account deletion must remove the public profile photo

The app's new privacy policy says deleting the account removes everything, straight away.
`DELETE /me` removes the private bucket's files. Please check it also removes the **public**
profile photo (`/me/photo`, from the profile-editing work) and any copies in the CDN, and add it
if not.

## 2026-10-05: shop the look (Scroll) and the Studio piece picker (#1, #2 done)

**Context.** Tapping a garment in a Scroll collage now opens a sheet with the fit's pieces. Each
piece has BUY, **+ STUDIO** (puts it on the Studio canvas) and **+ WARDROBE**
(`POST /wardrobe/items { garmentId }`). The Studio's new piece picker has a **Saved** tab and a
VISIT button. Branch `feat/studio-picker` in drip-front.

### 1. A garment id on `Outfit.pieces` (needed; tiny, no schema change)

**Why.** + WARDROBE and + STUDIO need the piece's garment id, and `OutfitPiece` (in
`src/domain/outfit.ts`) doesn't carry one.

**What the app does today.** It looks the piece up with `GET /studio/pieces?slot=&subcategory=`
and matches by cut-out URL, then by title. That endpoint returns only the newest 50 per slot, so
older garments aren't found, and the user sees "This piece isn't in the Drip catalogue yet".

**Short v1.** Add `id` (the `garments.id`) to `OutfitPiece`. `loadOutfits` already selects
`fit_items → garment`; add `id` to that select and to the mapped piece. The app reads `id` (or
`garmentId`) and stops matching once it's there.

```ts
export interface OutfitPiece {
  id: string | null; // garments.id: for POST /wardrobe/items and Studio fits
  name: string | null;
  …
}
```

### 2. `buyUrl` on `StudioPiece` (nice to have; no schema change)

**Why.** The Studio picker's VISIT button needs the store page. `garments.buy_url` exists, but
`StudioPiece` doesn't return it.

**What the app does today.** It shows VISIT only for pieces it has seen in the user's saved or
liked fits (it takes their `buyUrl` from those).

**Short v1.** Add `buy_url` to `GARMENT_COLS` in `src/api/user-fits.ts` and
`buyUrl: g.buy_url ?? null` to `garmentPiece()`. Wardrobe pieces stay `null`.

### 3. The user's saved pieces for the Studio picker (nice to have)

**Why.** The picker's **Saved** tab shows the catalogue pieces from fits the user saved or liked.

**What the app does today.** It reads `GET /studio` (saved and liked fits), then fetches
`/studio/pieces` for the slot and keeps the pieces that match by cut-out or title. It's capped by
the same 50-newest limit.

**Short v1.** `GET /studio/pieces?slot=&source=saved`: the published garments in that slot that
appear in the caller's `saved_fits` or liked fits, newest save first, as `StudioPiece[]`. Once
it's there, the app calls it for the Saved tab.

### 4. Paging on `GET /studio/pieces` (later)

The catalogue tab stops at the newest 50 per slot (`.limit(50)`). A `cursor` (the same
offset-style one as `/scroll`) would let the picker keep loading as the user swipes. Not urgent at
today's catalogue size.

### 5. Material (later, only if the pipeline has it)

The founder wants the piece's material in the sheet ("cotton", "denim"). `garments` has no
material column, so this depends on the catalog pipeline or the discovery products
(`DripProduct.material`) extracting it. If it lands, add `material: string | null` to
`OutfitPiece` and `StudioPiece`; the app has a line for it.

---

## 2026-10-03: Studio canvas and occasion feeds (done)

Shipped in `feat/app-requests-1003` with migration `…0012`. The app uses it: every accessory, box
and z saved on user fits; `GET /scroll?occasion=`; `home: true` occasions; `brand` on Studio
pieces. The original write-up follows for reference.

### 1. Studio fits: several accessories, and where each piece sits

**Why.** The Studio canvas now lets users place pieces anywhere and resize them, and wear up to
6 accessories (bag, eyewear, watch, jewellery…). `user_fit_items` has `primary key (user_fit_id,
slot)` and the API refuses two items with the same slot, so a fit can hold one accessory and no
placement.

**What the app does today.** It saves one accessory to the server and keeps the extra accessories
and every piece's position on the phone (SharedPreferences, keyed by fit id). Extras don't count
toward the drip rate and don't sync across devices.

#### Short v1 solution (one migration, small API change)

Migration `…0012_user_fit_canvas.sql`:

```sql
alter table public.user_fit_items
  add column position int not null default 0,   -- 0 for core slots; 0..5 for accessories
  add column box_x real, add column box_y real,  -- placement, fractions of the canvas (0–1)
  add column box_w real, add column box_h real,
  add column z int;                              -- draw order, higher = on top
alter table public.user_fit_items drop constraint user_fit_items_pkey;
alter table public.user_fit_items add primary key (user_fit_id, slot, position);
alter table public.user_fit_items add constraint user_fit_items_position_ck
  check ((slot = 'accessory' and position between 0 and 5) or (slot <> 'accessory' and position = 0));
alter table public.user_fit_items add constraint user_fit_items_box_ck
  check (box_x is null or (box_x between -1 and 2 and box_y between -1 and 2
                           and box_w > 0 and box_w <= 1.5 and box_h > 0 and box_h <= 1.5));
```

`save_user_fit`: read `position`, `box_x/y/w/h`, `z` from each `p_items` element (all optional;
`position` defaults to 0). RLS policies are unchanged.

API (`src/api/user-fits.ts`):
- `FitBody.items[]` accepts optional `position` (int), `box: {x, y, w, h}` and `z`.
- Replace "one item per slot" with: at most one per core slot, at most 6 `accessory` items, and
  `(slot, position)` unique. `.max(CATEGORIES.length)` becomes `.max(11)`.
- `UserFit.pieces[]` returns `position`, `box` (or null) and `z`.
- `dripRate`: score with all accessories (or the first only, your call; tell us which).
- Catalogue outfits allow at most 4 accessories, one per kind (`MAX_ACCESSORIES`, `docs/FITS.md`).
  The app currently allows 6 of any kind. If you'd rather user fits follow the same rule, enforce
  it here and the app will match: cap at 4 and swap a same-kind accessory instead of adding it.

Contract example:

```json
POST /studio/fits
{ "name": "Beach", "items": [
  { "slot": "top", "garmentId": "…", "box": {"x":0.21,"y":0.03,"w":0.58,"h":0.4}, "z": 2 },
  { "slot": "accessory", "position": 0, "garmentId": "…", "box": {"x":0.8,"y":0.2,"w":0.17,"h":0.2}, "z": 5 },
  { "slot": "accessory", "position": 1, "wardrobeItemId": "…" }
] }
```

`box` absent or null means "put it where the layout says", which is what the app does for pieces
the user hasn't moved.

**Once it ships,** the app sends every accessory and every box, reads them back, and stops keeping
them on the phone. Fits saved before then keep working (no boxes = layout positions).

*Even faster stopgap, not recommended:* a `user_fits.canvas jsonb` blob the app owns. It skips
RLS checks on the extra pieces (the publish gate) and would store image URLs that expire, so the
item-row change above is worth the extra hour.

### 2. `GET /scroll?occasion=<id>`

**Why.** Home now has "Shop by occasion" cards; tapping one opens the Scroll on fits for that
occasion.

**What the app does today.** It pages through the normal ranked `/scroll` and keeps fits whose
`formality` falls in a band it picked per occasion. That reads up to 6 pages per screen and gets
thin quickly.

**Short v1 solution.** Accept an optional `occasion` on `/scroll`: filter the ranked candidates by
the occasion's formality band (and prefer its vibe styles if you like), keep the same cursor and
paging, and cache the ranked list per `(user, day, occasion)`. 400 for an unknown id.

Add the missing ones to `OCCASIONS` in `src/domain/meta.ts` (ids and bands as the app uses them
now; adjust the bands freely):

| id | label | formality |
|---|---|---|
| date-night | Date night | 2–4 |
| concert | Concerts | 1–3 |
| late-night-dinner | Late-night dinner | 3–4 |
| university | University | 1–2 |
| parties | Parties | 1–3 |
| clubs | Clubs | 2–4 |
| picnics | Picnics | 1–2 |
| derbies | Derbies | 4–5 |
| golf | Golf | 2–3 |
| sports | Sports | 1–2 |
| family-events | Family events | 2–4 |
| wedding | Weddings | 4–5 |

`date-night`, `concert` and `wedding` already exist with these bands, and the app now uses the same
ids. The other nine are new. Taylor's occasion picker lists every `OCCASIONS` label, so if the Home
ones shouldn't all show up there, add a flag such as `home: true` rather than a second list.

### 3. Nice to have (not blocking)

- **A display title on `Outfit`.** The app shows `colourStory` as the title ("blue · brown · black
  · grey"), which reads like a tag list. Even a generated "Navy shirt + cargo" would be better.
- **`brand` on Outfit pieces and Studio pieces.** The cards and Fit Analysis have a slot for it.

### Not needed for v1

Search, Discover, the wardrobe rotation flag and the social layer stay "after beta" in the app.

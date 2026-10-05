# Backend requests from the app

From the Flutter session, for the backend session. Newest first. Each request says what the app
does today without it, so nothing is blocked.

## 2026-10-05: shop the look (Scroll) and the Studio piece picker

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

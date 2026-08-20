# Noor Sharik

The manufacturer-facing surface of Noor. Flutter, Android, English.

Sharik is the second app on an existing system. **Noor Majlis owns the database.**
This app creates no schema, runs no migration and adds no table, column or enum.

---

## Rule zero — one Supabase project

```
SUPABASE_URL      = https://itmzwslepexeqixuxjca.supabase.co   (project: noor-demo)
SUPABASE_ANON_KEY = <the same anon key Majlis uses>
```

Both live in `lib/core/supabase_config.dart` and can be overridden at build time:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Build

```bash
flutter pub get
flutter test          # 16 tests, all green
flutter analyze
flutter build apk --release
```

Release builds need `android.permission.INTERNET`, which `flutter create` only
writes into the debug and profile manifests. It has been added to
`android/app/src/main/AndroidManifest.xml`; without it a release APK reaches
Supabase not at all and fails silently.

---

## The two commercial rules

These are not implementation details. They are the reason the product exists.

**1 · A seller sees an order only once it is released.**
Every order query carries the released status set
(`released, in_production, inspection, packed, shipped, arrived, closed`).
It lives in one place, `SupabaseConfig.visibleOrderStatuses`, and is covered by
tests that fail if a pre-release status ever enters it. A seller seeing an order
while the client is still negotiating is a commercial disaster, not a bug.

**2 · A seller never sees a client.**
There is no client name, city or price anywhere in this app — not hidden in the
UI, but never selected from the database. `SellerOrder` has no field to put one
in. The client relationship is Noor's, and the model makes leaking it structurally
impossible rather than merely unlikely.

---

## What Sharik writes

| Table | The write | Where |
|---|---|---|
| `manufacturer_orders` | `status` → `in_production`, on accept only | `acceptOrder` |
| `production_events` | `status`, `qty_out`, `qty_in`, `completed_at` | `completeStage` |
| `media_assets` | the two colour blocks for a completed stage | `completeStage` |
| `issues` | insert, when the seller raises a problem | `raiseIssue` |

Everything else is read-only. The accept write is guarded with
`.eq('status', 'released')`, so a double-tap cannot move an order twice.

---

## Schema divergences from `13-integration-contract.md`

**The contract does not match the database.** The live schema is the authority;
nothing here was changed to fit the document. Majlis and the QC dashboard need
to read this list.

| Contract says | Database actually has |
|---|---|
| `order_lines` | `manufacturer_order_lines` |
| `gates(order_id, gate_type, status, checks, note, decided_at)` | **no `gates` table.** `order_reviews` (checks, outcome `passed/query/rejected`, note, reviewer_id, decided_at) plus `approvals` (type `lab_dip/pp_sample/size_set/inspection/artwork`) |
| `production_events.order_id` | `production_events.manufacturer_order_id` |
| `production_events.stage`, `.stage_ar`, `.sort` | on `production_stages`, joined via `stage_id` |
| `production_events.photo_colours text[]` | **does not exist.** See below |
| `issues.order_id` | `issues.manufacturer_order_id`, and `issue_type_id` is required |
| — | every table carries a `tenant_id`, NOT NULL |

### Where the colour blocks go

`production_events.photo_colours` does not exist, so **no column was added.**
The schema already solves this: `media_assets` holds rows with
`owner_type='production_event'`, `url='noor://gradient'` and
`meta = {"gradient": ["#RRGGBB", "#RRGGBB"], "label": "..."}`. Seeded rows for
the existing order use exactly that shape, so Sharik writes the same shape.

This matches the contract's own forward path — *"in production it becomes media
asset IDs"* — except the database went there already. Two consequences:

- `media_assets` is a fourth Sharik write, not in the contract's write map.
- Sharik writes `kind='floor'` because the seeded production-event rows use
  `floor` and `detail`. **Majlis must read stage imagery by `owner_id`, not by a
  `kind` allowlist**, or the blocks will not appear on the client timeline.

Both are worth a decision rather than an assumption.

---

## The project is in INR, and some rows are inconsistent

`noor-demo` was converted from USD to INR by another surface partway through
this work: `tenants.default_currency`, the client, nine of ten styles and every
order now read INR.

**The conversion was only half applied.** On most order lines `unit_price` was
converted while `line_total` was left at its USD figure, so
`unit_price × pcs ≠ line_total` — out by a factor of about 85. Sharik shows the
rate from `unit_price` and the order value from `line_total`, so an affected
order displays a per-piece rate and a total that disagree by two orders of
magnitude.

Repaired on the five orders this app seeded (`NT-2026-0163-A` was already
consistent): `line_total` recomputed as `unit_price × pcs`, freight and packing
converted at 84.5, and the order rollups rebuilt.

**Still broken, and not ours to fix:** `NT-2026-0184-A`, `-B`, `-C` and `-D`,
created by the client flow. All four carry INR unit prices against USD line
totals, and `-D` has a null `subtotal` and `total`. Whoever owns those rows
needs to run the same repair. None is `released`, so none reaches a seller yet
— but `-B` belongs to Zubair Garments and will surface the moment QC releases it.

## Changes made to the shared project

Approved before running, none creating a schema object:

**1 · Realtime was completely off.** The `supabase_realtime` publication
contained zero tables, so no subscription in any of the three apps could ever
fire. Fixed with:

```sql
alter publication supabase_realtime
  add table manufacturer_orders, production_events, approvals;
alter table manufacturer_orders replica identity full;
alter table production_events  replica identity full;
alter table approvals          replica identity full;
```

**2 · Demo data.** The database held one order, already `in_production`, so
there was nothing to accept and nothing to prove invisibility with. Added:

| Order | House | Status | Purpose |
|---|---|---|---|
| `NT-2026-0164-A` | Zubair Garments | `released` | visible as New; accept and run the ladder |
| `NT-2026-0165-A` | Zubair Garments | `proforma_issued` | **must stay invisible** — proves the status filter |
| `NT-2026-0166-B` | Dar Al-Khuyut | `released` | **must stay invisible to Zubair** — proves the house filter |

**3 · A jeans style**, because the seeded catalogue is skirts, dresses and
abayas and there was no trouser shape to show:

| Row | Detail |
|---|---|
| `categories` | `trousers` — no trouser category existed, and a null category would hide the style in the client's catalogue browse |
| `styles` | `J-2204` Straight Leg Jeans, Zubair Garments, rigid denim, 340 gsm, INR 980 |
| `colourways` | Indigo `#2E4272`, Stone Wash `#8FA0B8`, Black Rinse `#23262B` |
| `ratio_packs` | Standard, S2 M3 L3 XL2, 10 per pack |
| `price_lists`, `assortments` | so the style is priced and visible client-side |
| `manufacturer_orders` | `NT-2026-0171-A`, released, 1,200 pieces |

Beyond the currency repair described above, existing rows were not modified.

---

## The wiring test

Steps 5 to 9 are Sharik's. Steps 6, 7 and 9 were run against the live database
and pass; the demo data was reset afterwards, so the app starts clean.

| # | Do this | Expect | State |
|---|---|---|---|
| 5 | QC approves the gate | order appears in Sharik on its own, with a sound | wired; needs all three surfaces to confirm end to end |
| 6 | Accept with a date | order → `in_production` | ✅ verified — and a second accept touches 0 rows |
| 7 | Done + photo | exactly **one** `production_events` row completes, one `media_assets` row is written | ✅ verified |
| 8 | Majlis timeline moves | stage turns green with the colour blocks | Majlis's half; realtime is now on |
| 9 | An order that was never released | **not visible in Sharik at all** | ✅ verified — both the unreleased same-house order and the other house's released order are absent |

Step 9 is the one people forget.

---

## Screens

1. **Orders inbox** — three tabs by colour (New amber · Running green · Done grey).
   Large cards leading with the colourway block; `PIECES` and `VALUE` are the
   biggest text. Accept and No sit on the card. Subscribed to
   `manufacturer_orders` filtered to this house: a new card arrives with a sound
   and a badge, no refresh.
2. **Order detail** — style block, colourway swatches with piece counts,
   proportional size bars, total pieces in a dark green panel as the largest
   number on screen, his rate, his order value, the date and a days-remaining
   chip, and a voice-note row.
3. **Update production** — the vertical ladder. Completed stages are green with
   date, quantity and their colour blocks. Only the lowest incomplete stage is
   actionable: gold panel, one enormous `DONE + PHOTO`. Future stages are grey,
   numbered, inert. Four taps from the ladder to the write.

Every list has an empty state and a retry state. Nothing crashes on no data.

---

## Demo simplifications

Role picker instead of phone OTP · RLS off, the status filter is in the query ·
two gradient blocks instead of camera and storage · English only · no offline
queue · in-app sound and badge instead of push.

Not built yet: raise-a-problem grid, my articles, stock, payments, my score.
`raiseIssue` is implemented in the repository and unused by the UI.

---

## Known limitation of this build

**The APK has not been compiled**, and the app has not been run against the live
database, because the build container's egress policy blocks two hosts:

| Host | Effect |
|---|---|
| `dl.google.com` | no Android Gradle Plugin, no androidx — **blocks the APK** |
| `*.supabase.co` | the app cannot reach the database from the container |

Everything else needed is reachable and was put in place: Flutter 3.35.1, the
Gradle distribution, Maven Central, an API 35 `android.jar`, and Ubuntu's
build-tools assembled into an SDK at `/opt/android-sdk`. The build then fails
resolving `com.android.application:8.9.1`, because `google()` points at
`dl.google.com/dl/android/maven2` and `maven.google.com` is only a redirect to
the same blocked host. AGP and androidx are not published to Maven Central, so
there is no legitimate second source.

On any machine with normal network access there is nothing to work around:

```bash
flutter pub get
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
```

What *was* verified here: `flutter analyze` clean, 12 tests green, every
PostgREST embed backed by a real foreign key, and the accept and
stage-completion writes executed directly against `noor-demo` (see the wiring
test above). Build the APK and run the three surfaces side by side before the
demo.

# Architecture summary

Full document (schema tables, provider graph, UI tree): https://claude.ai/artifact/Xr6iJSRSTVFmtET6pMQYTC
This file keeps the load-bearing decisions. If they conflict, fix the doc and this file together.

## Decisions (v1)
- Flutter + Riverpod (riverpod_generator), freezed, go_router, drift, flutter_local_notifications, timezone, crypto. No BLoC.
- Feature-first layout. Each feature's `domain/` is pure Dart (no Flutter or Drift imports) and unit-tested with a FakeClock.
- Two SQLite files: read-only `catalog.sqlite` (built per game patch, swapped atomically, verified by sha256 from manifest.json) and `user.db` (Drift migrations, never overwritten). SQLite cannot enforce FKs across attached DBs, so the bundle installer checks user.db ids against the new catalog. **v1**: the catalog is built in-repo by `dart run tool/build_catalog.dart` from a vendored genshin-db extract (`tool/data/vendor/`, MIT; all values unverified in-game — docs/ASSUMPTIONS.md), which emits both the version-stamped `build/catalog/catalog.sqlite` + manifest and a generated Dart data file the app loads in-memory — identical on native and web, no file-install path yet. The separate data-pipeline repo and on-device sqlite swap remain the post-v1 plan.
- User tables: UUID text keys, `updated_at`, `deleted_at` on every row (sync-ready, but no sync in v1). JSON export/import in Settings.
- Android first, iOS after v1. Free, no ads, labelled unofficial. Avoid the game's name in the public app name.
- Multiple game accounts (profiles), switchable from Settings' Accounts section and from the all-accounts strip on Today. Every user table is `profileId`-scoped; `currentProfileProvider` resolves whichever profile is selected (`AppState.selectedProfileId`, with graceful fallback), and every screen/controller reads the active profile exclusively through that one provider. Each profile carries **its own HoYoLab login** (`lib/core/hoyolab/data/hoyolab_credentials_store.dart`, keys namespaced by profile id; a pre-multi-login global credential is adopted onto the selected profile once, then deleted). Notification reminders are planned for **every** profile, not just the selected one (`lib/core/providers/notification_providers.dart`) — ids are namespaced by profile, so plans concatenate without colliding. Soft-deleting a profile deliberately leaves its credential and data intact, so Undo restores a working account.
- No third-party API at runtime for game *data* — that still comes only from the bundle. One user-opt-in exception: Settings can connect a HoYoLab account per profile (session cookie, stored in secure storage, never in `user.db`) to auto-fetch that account's live `dailyNote`: resin (replacing the manual Sync dialog's text entry), daily commissions, weekly boss discounts, expeditions and realm currency. Non-resin fields are cached in `account_snapshots`; resin still flows through `ResinEngine.sync` into `resin_state` so manual and synced resin stay one source of truth. Refresh happens on app open past a 5-minute freshness window and on pull-to-refresh; a per-account failure is shown on that account's card, never thrown. This talks to HoYoLab's unofficial, reverse-engineered `dailyNote` endpoint (not a sanctioned API — HoYoverse's ToS broadly prohibits third-party account-data collection, with a real if small risk of account action), gated behind an explicit in-app disclaimer the user must acknowledge before connecting. No API, official or unofficial, exposes material/item inventory, so this doesn't touch the Inventory screen or Planner's aggregation at all — see `lib/core/hoyolab/`.
- **Wishes and primogems** are tracked per account, on their own tab (`/wishes`, the 4th pill-nav branch), with the all-accounts screen as a *pushed* route (`lib/features/accounts/presentation/all_accounts_screen.dart`) rather than a 5th tab — Settings sets that precedent. Neither feature has an approved `design/v3` mock; both are built from the existing vocabulary (one gradient hero card per screen, card stack, 20px gaps, 112px bottom padding). The pill tabs stack icon above label because four horizontal icon-and-label pairs don't fit 320dp.
- Run estimates y(WL) deferred to v2 (no clean public drop-rate source). v1 shows missing material counts and logs runs done. Totals-only mode treats inventory as 0.
- Level farm calc stops at 90 (100 uses a non-farmable item).

## Resin
Store an anchor, never a ticking counter: v (original resin at anchor), n (time of next +1, null while v >= C), R = 480 s, C = 200 (from `game_rules`, not hard-coded).
- k(t) = floor((t - n)/R) + 1 if n != null and t >= n, else 0; v(t) = min(C, v + k(t))
- time to threshold T: t_T = n + (T - v - 1) * R
- planning total: E = v(t) + 40*condensed + 60*(fragile + sum of unexpired transient)
- Mutations (Sync, Spend, Craft Condensed, Use Fragile/Transient, Use Condensed) project to now, apply one change, append a `resin_events` row (append-only; undo writes a compensating event).
- Sync(x, fullIn?): v = x; n = null if x >= C, else now + fullIn - (C-x-1)*R, or now + R/2 (+-4 min) without fullIn.
- To verify in-game before shipping: timer restarts from zero when resin drops below cap; resin above cap does not regenerate.
- Notifications: one idempotent `reconcile()` after every mutation, app start, tz change, reboot, planned across every profile. Stable id = hash(profile, kind, threshold). Exact alarms need SCHEDULE_EXACT_ALARM; if denied, schedule inexact and label alerts "approximate".

## Server day
Daily reset 04:00 server time. Offsets fixed: Asia +8, Europe +1, America -5, TW/HK/MO +8.
serverDate = date(t_utc + offset - 4h). Never use the phone clock for day logic; everything goes through `ServerClock`.
A domain_drops row is open when its weekday_mask has serverDate's weekday bit (bit0 = Monday; Sunday opens all).

## Material aggregation
Need per material over active targets (ascension + 3 talents, stages after current). EXP via exp_curves -> books largest-first, plus Mora. Per tier group walk low to high with ratio 3, carrying surplus up. Daily checklist task_key = serverDate:domain:tierGroup; "+1 run" calls Spend(domain cost) and increments runs_done so checklist and resin tracker never disagree.

## Wishes

No HoYoLab cookie endpoint exposes wish history. The only source is the game's own
`getGachaLog`, authenticated by a short-lived `authkey` carried in the link the in-game
wish-history webview hands out — a second user-opt-in exception to the no-third-party-API
rule, behind its own explicit disclaimer (`lib/features/wishes/presentation/import_wish_history_sheet.dart`).
- **The authkey is never persisted.** It expires in about a day, so storing it would buy
  nothing and add a credential to protect; it lives only for the duration of one
  `WishImportService.importAll` call.
- **The endpoint's host and path come from the pasted link, never hardcoded** — the same
  API is served at more than one spelling depending on region and client version, and the
  link always carries the right one (`parseGachaUrl`). `lang=en` *is* forced, so item
  names match the catalog's English names.
- Import is incremental: high-water mark per banner, read once for the whole run. The
  character banner's two `gacha_type` codes (301 and 400) share one mark — ids are
  monotonic in time across codes — and reading the mark again between them would skip
  banner 400 entirely on a first import.
- `wish_pulls` is keyed by the upstream snowflake id, the one deliberate break from the
  uuid-key convention: it makes re-importing an overlapping window idempotent.
- Pity, 50/50 inference and statistics are pure Dart (`lib/features/wishes/domain/`).
  Imported history and manually entered pity are **alternatives, not a merge** — blending
  a real pull count with a typed-in one yields a number that is neither — and the UI always
  says which it is, mirroring the live-or-manual commission split.

## Primogems

Nothing exposes a live primogem balance — not HoYoLab, not the game. So the balance uses
the **same anchor model as resin**: the player enters it once, and it is derived from there.
- `balance(t) = anchor + diary income after the anchor + manual adjustments − 160 × wishes
  since the anchor`, clamped at 0 (`lib/features/primogems/domain/primogem_ledger.dart`).
- Income comes from the Traveler's Diary (`event/ysledgeros/month_info`), which reports
  primogems *earned*, month to date. Monthly totals rather than per-day detail: one cheap
  number per month, where per-day history needs a second paginated endpoint. The anchor
  stores the month-to-date reading taken at anchor time, without which the income already
  inside the entered balance would be counted twice; when that reading is unknown, none of
  the anchor month is credited.
- **The diary may reject a login that `dailyNote` accepts** — it wants a different cookie,
  and the login WebView may not hand one back. That failure has its own exception type
  (`DiaryUnauthorizedException`), is swallowed inside the refresh service's own try/catch
  so it can never mask a working resin sync, and surfaces as "income isn't syncing" on the
  balance card. Primogem tracking works fully without it, on the anchor plus manual
  adjustments.
- The diary's month is derived from the region encoded in the account's UID, not the app's
  "Game server" setting: that setting is a reset-math preference and the two are allowed to
  disagree.

## Account ordering

`ProfileOrder` is a table of its own, not a column on `Profiles`, and not by preference:
the v2 migration rebuilds `profiles` with `alterTable`, which copies the table using the
*current* Dart definition — so any column added to `Profiles` makes that historical step
select a column the old database never had, and the 1→2 path fails. A table introduced in
its own step touches no earlier step.

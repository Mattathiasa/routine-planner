# Architecture summary

Full document (schema tables, provider graph, UI tree): https://claude.ai/artifact/Xr6iJSRSTVFmtET6pMQYTC
This file keeps the load-bearing decisions. If they conflict, fix the doc and this file together.

## Decisions (v1)
- Flutter + Riverpod (riverpod_generator), freezed, go_router, drift, flutter_local_notifications, timezone, crypto. No BLoC.
- Feature-first layout. Each feature's `domain/` is pure Dart (no Flutter or Drift imports) and unit-tested with a FakeClock.
- Two SQLite files: read-only `catalog.sqlite` (built per game patch by a separate data-pipeline repo, swapped atomically, verified by sha256 from manifest.json) and `user.db` (Drift migrations, never overwritten). SQLite cannot enforce FKs across attached DBs, so the bundle installer checks user.db ids against the new catalog.
- User tables: UUID text keys, `updated_at`, `deleted_at` on every row (sync-ready, but no sync in v1). JSON export/import in Settings.
- Android first, iOS after v1. Free, no ads, labelled unofficial. Avoid the game's name in the public app name.
- One game account in the v1 UI; `profiles` table exists anyway.
- No third-party API at runtime. Game data comes only from the bundle.
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
- Notifications: one idempotent `reconcile()` after every mutation, app start, tz change, reboot. Stable id = hash(profile, kind, threshold). Exact alarms need SCHEDULE_EXACT_ALARM; if denied, schedule inexact and label alerts "approximate".

## Server day
Daily reset 04:00 server time. Offsets fixed: Asia +8, Europe +1, America -5, TW/HK/MO +8.
serverDate = date(t_utc + offset - 4h). Never use the phone clock for day logic; everything goes through `ServerClock`.
A domain_drops row is open when its weekday_mask has serverDate's weekday bit (bit0 = Monday; Sunday opens all).

## Material aggregation
Need per material over active targets (ascension + 3 talents, stages after current). EXP via exp_curves -> books largest-first, plus Mora. Per tier group walk low to high with ratio 3, carrying surplus up. Daily checklist task_key = serverDate:domain:tierGroup; "+1 run" calls Spend(domain cost) and increments runs_done so checklist and resin tracker never disagree.

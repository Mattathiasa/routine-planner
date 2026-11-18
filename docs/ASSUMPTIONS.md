# Assumptions

Facts the app relies on that have **not** been verified in-game (no verified game access
during development). Each is implemented behind a single named constant or isolated in one
place, so a wrong guess is a one-line fix. Tests that pin these behaviours are labelled
assumption tests — they document the current guess, they do not prove it.

## Resin mechanics

1. **Timer behaviour on reset** — when a mutation (spend, craft, use item) drops resin
   below cap, the +1 timer restarts from zero (`now + R`) rather than keeping the phase of
   the previously running tick.
   - Constant: `ResinEngine.assumedTimerRestartsFromZeroOnReset` (`lib/features/resin/domain/resin_engine.dart`)
   - If wrong: flip to `false` — the engine then preserves the previous anchor's tick phase.
   - Verify by: in-game, note the regen countdown, spend 20 resin, check whether the
     countdown continued or restarted at 8:00.

2. **Regeneration above cap** — resin at or above cap does not regenerate; the timer stops
   and an over-cap value (from Fragile/Condensed/Transient resin) stays frozen.
   - Constant: `ResinEngine.assumedNoRegenerationAboveCap` (same file)
   - If wrong: flip to `false` — natural ticks then continue past cap.
   - Verify by: in-game, use a Fragile Resin at cap and check the value an hour later.

3. **Sync phase uncertainty** — a manual sync without the in-game "full in" countdown cannot
   know the current tick's phase; the engine assumes the expected midpoint (`n = now + R/2`),
   which is inherently uncertain by ±4 minutes. Not a mechanic guess, but a documented
   precision limit (`ResinEngine.sync`).

## Server time

4. **Daily reset at 04:00 server time with fixed UTC offsets** — Asia +8, Europe +1,
   America −5, TW/HK/MO +8, no daylight-saving changes ever. Matches long-standing community
   documentation but is unverified in-game here (`lib/core/clock/game_server.dart`,
   `lib/core/clock/server_clock.dart`).

## Catalog data

5. **Every catalog name and number is community-sourced and unverified in-game.** The
   catalog is built by `dart run tool/build_catalog.dart` from a vendored extract of the
   MIT-licensed [genshin-db](https://www.npmjs.com/package/genshin-db) dataset (version
   pinned in `tool/fetch_catalog_source.sh`; provenance and hashes in
   `build/catalog/manifest.json` and the `catalog_metadata` row). Characters, weapons,
   ascension/talent costs, tier chains (derived from the game's own 3:1 crafting recipes in
   the dataset), farm-domain names and weekday schedules all come straight from that
   dataset — including any upstream mistakes. Nothing was hand-authored.

6. **Resin cost per run** — 20 for a talent/weapon domain, 40 for an open-world boss, 60
   for a weekly boss (with 3 discounted runs per week modelled as `max_runs_per_period`) —
   and the `game_rules` constants (cap 200, 480 s per resin, condensed = 40, fragile = 60)
   are long-standing community knowledge, not dataset fields
   (`tool/build_catalog.dart`, `bundledGameRules`).

7. **Level EXP/Mora ladders are absent.** The vendored dataset has no per-level character
   or weapon EXP table, so `exp_curves` ships empty: the planner's derived EXP-book and
   leveling-Mora needs are 0 for every target (ascension and talent Mora costs *are* real
   rows). The aggregation layer was already designed for sparse curves, so this degrades
   silently and honestly rather than inventing a ladder.

8. Two modelling notes, not game facts: gathered local specialties and one-off items
   (e.g. Crown of Insight) are stored under the untiered `bossMaterial` category with no
   farm domain; and each boss is modelled as its own always-open "domain" whose name is
   mechanically derived from the dataset's drop-source text.

## Live account data (HoYoLab)

9. **The `dailyNote` field names are community-sourced and unverified.** Resin
   (`current_resin`, `max_resin`, `resin_recovery_time`) is required and a missing field is
   treated as a broken response. Everything added for the per-account view — commissions
   (`finished_task_num`, `total_task_num`, `is_extra_task_reward_received`), weekly boss
   discounts (`remain_resin_discount_num`, `resin_discount_num_limit`), expeditions
   (`expeditions[].status`/`remained_time`, `current_expedition_num`, `max_expedition_num`)
   and realm currency (`current_home_coin`, `max_home_coin`, `home_coin_recovery_time`) —
   is optional and degrades to "unknown" rather than zero, so an upstream rename can never
   break resin sync (`lib/core/hoyolab/domain/hoyolab_notes.dart`).

10. **Four commissions per server day** is assumed only for the *manual* tracker used by
    accounts with no HoYoLab login (`defaultDailyCommissionCount`). A connected account
    always prefers the live `total_task_num` over this constant.

11. **Two product choices, not game rules**: the commission reminder fires
    `commissionReminderLeadTime` (2 hours) before an account's own server reset
    (`lib/core/notifications/domain/notification_plan.dart`), and a cached snapshot counts
    as fresh for `accountSnapshotFreshness` (5 minutes), which throttles app-open refreshes
    against an unofficial endpoint (`lib/features/accounts/data/accounts_refresh_service.dart`).
    Pull-to-refresh deliberately ignores the freshness window.

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

8. **Six materials have no record in the dataset** — `Kristallfold`, `Fairy Wormwood`,
   `Shattered Stability Anchor`, `Snowborn Heart of Ignorance`, `Snowborn Heartshard` and
   `Snowborn Mirrorheart` are referenced by ascension costs (so their names and quantities
   are the dataset's own), but genshin-db 5.2.15 carries no entry describing them. They are
   stored as untiered, non-farmable materials so the characters needing them stay
   plannable; where they actually drop is unknown. The build prints them every run and
   lists them in `build/catalog/manifest.json` under `materialsWithoutRecords`.

9. Two modelling notes, not game facts: gathered local specialties and one-off items
   (e.g. Crown of Insight) are stored under the untiered `bossMaterial` category with no
   farm domain; and each boss is modelled as its own always-open "domain" whose name is
   mechanically derived from the dataset's drop-source text.

## Live account data (HoYoLab)

10. **The `dailyNote` field names are community-sourced and unverified.** Resin
   (`current_resin`, `max_resin`, `resin_recovery_time`) is required and a missing field is
   treated as a broken response. Everything added for the per-account view — commissions
   (`finished_task_num`, `total_task_num`, `is_extra_task_reward_received`), weekly boss
   discounts (`remain_resin_discount_num`, `resin_discount_num_limit`), expeditions
   (`expeditions[].status`/`remained_time`, `current_expedition_num`, `max_expedition_num`)
   and realm currency (`current_home_coin`, `max_home_coin`, `home_coin_recovery_time`) —
   is optional and degrades to "unknown" rather than zero, so an upstream rename can never
   break resin sync (`lib/core/hoyolab/domain/hoyolab_notes.dart`).

11. **Four commissions per server day** is assumed only for the *manual* tracker used by
    accounts with no HoYoLab login (`defaultDailyCommissionCount`). A connected account
    always prefers the live `total_task_num` over this constant.

12. **Two product choices, not game rules**: the commission reminder fires
    `commissionReminderLeadTime` (2 hours) before an account's own server reset
    (`lib/core/notifications/domain/notification_plan.dart`), and a cached snapshot counts
    as fresh for `accountSnapshotFreshness` (5 minutes), which throttles app-open refreshes
    against an unofficial endpoint (`lib/features/accounts/data/accounts_refresh_service.dart`).
    Pull-to-refresh deliberately ignores the freshness window.

## Wishes (gacha)

13. **The `getGachaLog` field names and shape are community-sourced and unverified.**
    `id`, `gacha_type`, `name`, `item_type`, `rank_type` and `time` are all required and a
    missing one is treated as a broken response; an unrecognised `gacha_type` is skipped
    instead, so a banner added in a future patch can't break an import
    (`lib/features/wishes/domain/wish_pull.dart`).
    - Also assumed: `time` is wall-clock time on the account's own server with no offset
      attached, and snowflake `id`s are monotonic in time across banners — the second is
      what makes one high-water mark per banner correct.
    - If wrong: the import reports a mismatch rather than storing nonsense.

14. **Upstream keeps roughly six months of history.** Not a configurable value, just what
    the endpoint serves. One visible consequence: the earliest 5★ in an import has no
    known starting point, so its pity is counted from the start of the window and is
    excluded from the average (`wish_stats.dart`).

15. **Pity constants** — 90-pull guarantee on the character, standard, beginner and
    chronicled banners, 80 on the weapon banner, soft pity from 74 (63 on weapons), 4★
    guarantee every 10 — are long-standing community knowledge, not dataset fields
    (`lib/features/wishes/domain/pity_calculator.dart`).

16. **A lost 50/50 is inferred, not reported.** Nothing records which 5★ was *featured* on
    a given banner — not the catalog, not any endpoint — so a 5★ character from the
    permanent pool is read as "that wasn't the featured one, the next is guaranteed". The
    pool is the named constant `standardPool5StarCharacters` (Diluc, Jean, Qiqi, Mona,
    Keqing, Tighnari, Dehya; all seven verified present in the shipped catalog).
    HoYoverse adds to it every few years, so it needs a look whenever the catalog is
    bumped. Inference is confined to the character banner: the standard and beginner
    banners have no 50/50, and the weapon banner's guarantee runs on Epitomized Path fate
    points, which nothing reports.

## Primogems

17. **160 primogems per wish**, and Fates bought at the same price
    (`primogemsPerWish`). Community knowledge, not a dataset field.

18. **The forecast's income constants are estimates, and deliberately incomplete**: 60 a
    day from commissions, 90 from the Welkin, and the battle pass as 680 per 42-day cycle
    (`lib/features/primogems/domain/primogem_ledger.dart`). Events, Spiral Abyss and
    quests are **not** counted, which the forecast card says outright — so the real date
    usually arrives sooner. Welkin and battle pass default off: assuming a purchase nobody
    made would overstate every forecast.

19. **The Traveler's Diary field names are community-sourced, and its auth requirement is
    unverified.** Only `month_data.current_primogems` is required; everything else degrades
    to null (`lib/core/hoyolab/domain/diary_month.dart`). The endpoint is believed to need
    a different cookie from `dailyNote`, which the login WebView may not capture — so a
    rejected login is treated as an expected, non-fatal state rather than an error, and the
    whole feature is designed to work without it.

## iOS

20. **Restoring an iPhone backup yields the data but a disconnected HoYoLab
    account.** `user.sqlite` lives in `Documents/`, which is included in
    iCloud/device backups, so profiles, resin state, planner targets and wish
    history come back. The credential does not: it is stored
    `first_unlock_this_device`
    (`lib/core/hoyolab/data/hoyolab_credentials_store.dart`), which is
    `ThisDeviceOnly` and therefore ineligible for restore onto another device.
    That is the intended trade — it is what makes "never leaves the device"
    true — but the symptom reads like a bug, so it is recorded here. Android is
    near-parity: `allowBackup` is unset, so Auto Backup is on by default there
    too. **Not verified on a device**: a simulator has no lock state, so the
    first-unlock behaviour rests on Apple's documentation rather than
    observation.

21. **Web renders the `approximate` delivery banner, which is a hold rather
    than a claim.** The web scheduler is a no-op fake
    (`lib/core/providers/notification_providers.dart`), so the literal answer
    is `blocked` — but "Notifications are off. Turn them on in Settings" names
    an action a browser user cannot take, and there is no approved web copy for
    a third state. `approximate` keeps the rendering exactly as it was before
    the three-state refactor. Worth revisiting if web notifications are ever
    actually wired up.

22. **Whether the Traveler's Diary accepts a cookie captured by `WKWebView` is
    still unknown.** Entry 19 predicts the diary may reject a login that
    `dailyNote` accepts, because it wants a different cookie the login WebView
    may not hand back. The Darwin cookie store is a different implementation
    from Android's `CookieManager`, so iOS could resolve this either way. It
    needs a real HoYoLab account to find out; until then the graceful-failure
    path (`DiaryUnauthorizedException` → "income isn't syncing" on the balance
    card) is the only thing relied on.

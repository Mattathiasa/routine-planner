# Portfolio entry — Routine Planner

## 1. Title

**Routine Planner — Offline-First Resin & Daily-Routine Companion for Genshin Impact**

Alternates:
- Routine Planner: A Precision Stamina Tracker Built on Math, Not Polling
- Routine Planner: Never Waste a Drop of Resin Again

## 2. Short Description

A cross-platform Flutter companion app for Genshin Impact players that tracks Original Resin, daily commissions, weekly domain rotations and character farming goals — entirely on-device, with no account, no ads and no background battery drain. It predicts exactly when your resin hits 160 and 200 using the game's real regeneration math, and reconciles local alarms around every reset.

## 3. Language / Tags

`Flutter` · `Dart` · `Mobile` · `Android` · `iOS` · `Web` · `Offline-first` · `Local-first` · `SQLite` · `Riverpod` · `Clean Architecture` · `Domain-Driven Design` · `Unit Testing` · `Timezones` · `Notifications` · `Open Source` · `Fan Project`

## 4. Full Tech Stack

**Application**
- Flutter (Dart SDK ^3.13.7), Android-first release with a Flutter Web build and an iOS target verified on simulator (unsigned; no store distribution)
- Riverpod 3 (`flutter_riverpod`, `riverpod_annotation` + `riverpod_generator`) for state and dependency injection — no BLoC
- `go_router` 18 for navigation with a shell + floating pill bottom nav
- `freezed` 3 for immutable domain models and sealed event types
- Feature-first architecture: `features/{resin,today,planner,settings}` each split into `domain / data / application / presentation`, with a shared `core/`

**Data**
- Drift 2.35 over SQLite (`drift_flutter`), two separate databases:
  - read-only `catalog.sqlite` — game data rebuilt per patch, swapped atomically, verified by SHA-256 from a manifest
  - `user.db` — the player's own data, versioned with Drift migrations and tested with generated schema snapshots
- `flutter_secure_storage` for credentials, `uuid` for sync-ready text keys, JSON export/import for backups

**Time & scheduling**
- `timezone` + `flutter_local_notifications` for exact alarms, with an idempotent reconcile pass on every mutation, app start, timezone change and reboot
- Custom `Clock` / `ServerClock` / `FakeClock` abstraction — no `DateTime.now()` in domain code
- `crypto` (MD5/SHA-256) for catalog integrity and HoYoLab request signing

**Integrations**
- `webview_flutter` + `webview_cookie_manager_flutter` for an in-app HoYoLab login, `http` for the unofficial `dailyNote` endpoint, `flutter_secure_storage` for the session cookie

**Tooling & delivery**
- `build_runner` codegen (Drift, Riverpod, freezed), `flutter_lints`, 69 test files across domain, repository, migration, widget and platform-channel layers, plus `integration_test` on a real simulator
- GitHub Pages hosting: a hand-built marketing landing page (HTML/CSS, vanilla JS, Three.js, GSAP + ScrollTrigger, Lenis) alongside the Flutter Web build and the signed Android APK

## 5. Long Description

Routine Planner is a companion app for Genshin Impact players who care about one specific thing: not wasting resin. The game regenerates one Original Resin every 8 minutes up to a cap of 200, and anything past that cap is simply lost. Most trackers solve this by running a timer in the background — which costs battery, requires the app to stay alive, and still drifts.

This app takes the opposite approach. Instead of storing a counter that ticks, it stores an **anchor**: the resin value at a known moment, plus the timestamp of the next `+1`. Everything else is computed on demand:

```
k(t) = floor((t - n) / R) + 1        // ticks since the anchor
v(t) = min(cap, v + k(t))            // current resin
t_T  = n + (T - v - 1) * R           // exact time to reach threshold T
```

Because nothing has to run, the app can tell you "you'll hit 160 at 12:43 and cap at 18:03" the instant you open it — and schedule a native alarm for exactly those moments without a background service. The engine is a pure Dart class with no Flutter, no database and no clock of its own; every mutation (sync, spend, craft condensed, use fragile/transient resin) projects the state to "now", applies one change, and appends an event to an append-only log. Undo writes a compensating event rather than mutating history, so the log always explains how you got to your current number.

Around that core sits the rest of a daily routine:

- **Today** — a server-day checklist combining resin state, open domains for the current weekday, and the character goals you're actively farming, with a one-tap "−20" that debits resin and marks the run done so the checklist and the tracker can never disagree.
- **Resin** — a full gauge with condensed / fragile / transient stock, a planning total, and a manual or automatic sync.
- **Planner** — pick a character, set a target level and three talent levels, and the app aggregates every ascension, talent, EXP-book and Mora requirement, then walks material tiers low-to-high with the game's 3:1 conversion ratio, carrying surplus upward — including from tiers you don't currently need.
- **Settings** — multiple game profiles, inventory editing, JSON backup, reminder thresholds and an optional HoYoLab connection.

Correctness details that matter more than they look:

- **Server day is not phone day.** Reset is 04:00 server time across four regions (Asia +8, Europe +1, America −5, TW/HK/MO +8). All day logic goes through `ServerClock`, and a domain is "open" when its weekday bitmask matches the server date's weekday (Sunday opens everything).
- **Two databases, on purpose.** The game catalog is read-only, patch-versioned and replaced wholesale with a SHA-256 check; your data lives in a separate, never-overwritten database with real migrations. SQLite can't enforce foreign keys across attached databases, so the bundle installer validates your saved ids against the incoming catalog before swapping.
- **Privacy is the default, not a setting.** No analytics, no accounts, no network calls for game data. The single opt-in exception is HoYoLab auto-sync, gated behind an explicit disclaimer and stored only in secure storage.

It's free, ad-free, openly labelled unofficial, and ships as an Android APK plus a fully client-side Flutter Web build running Drift on SQLite WASM.

## 6. Challenges

**Making a timer without a timer.**
The hard part wasn't the formula, it was every edge around it. The in-game regeneration timer restarts from zero when resin drops below cap, but resin above cap doesn't regenerate at all — so the anchor has to become `null` at exactly the right moment, and every mutation has to re-anchor correctly or the app silently lies about your resin. Syncing without an in-game "full in" countdown is inherently uncertain by ±4 minutes, so I modelled that honestly (`now + R/2`) instead of pretending to precision I didn't have. Choosing an append-only event log with compensating undo, rather than updating rows, came from the same instinct: a wrong projection should be explainable, not just overwritten.

**Getting "today" right across four servers.**
`serverDate = date(t_utc + offset - 4h)` looks trivial until you hit the cases: a player at 23:30 local on a Sunday whose server has already rolled over, daylight-saving changes that must not affect a fixed-offset game region, and a phone clock that's simply wrong. The fix was architectural — ban `DateTime.now()` from domain code entirely, route everything through an injected `Clock`, and test it all with a `FakeClock`. The API also reports "today" in a format that is *not* the app's local day, which is exactly the kind of bug that only shows up in tests.

**Two databases that have to agree.**
Splitting read-only game data from player data gives atomic patch swaps and a tiny app download, but SQLite cannot enforce foreign keys between attached databases. That pushed validation into application code: the bundle installer has to check every saved profile, target and material id against the new catalog before committing, and fail cleanly if a patch removes something. The migration harness — generated schema snapshots per version, with a test that upgrades from every old shape — was the other half of keeping a never-overwritten user database actually safe across releases.

**3:1 tier aggregation with surplus.**
Material requirements look simple until you realise players convert lower-tier drops upward, so a stockpile of tier 1 reduces how many tier 2 you need. The walk has to go low-to-high, carry surplus at exactly 3:1, and keep `need`, `have` and `missing` arithmetically consistent on screen. The subtle bug I had to design around: a tier you don't currently need still donates its *entire* stock upward, so the algorithm must receive every material in the group, including zero-need ones, or inventory silently disappears from the total.

**Reliable alarms under modern Android restrictions.**
Exact alarms need `SCHEDULE_EXACT_ALARM`, which users can deny; Doze can delay anything inexact. Instead of one-shot scheduling, I made a single idempotent `reconcile()` that recomputes every reminder from state with stable ids derived from `hash(profile, kind, threshold)`, run after every mutation, on app start, on timezone change and on reboot. If exact alarms are unavailable the app schedules inexact ones and labels them "approximate" rather than lying about precision.

**Reverse-engineering a private API responsibly.**
The optional HoYoLab sync required reproducing HoYoLab's `ds` request signing (an MD5 over a salt + timestamp + random string) — undocumented, community-derived, and confirmed against an actively maintained open-source client rather than guessed. It also required capturing the cookie jar through an embedded WebView instead of asking users to paste tokens, deriving the server region from the UID rather than the app's own setting, and tolerating fields the API returns as numeric strings. Because HoYoverse's terms broadly prohibit third-party account-data collection, this is the one place the app touches the network — opt-in, behind an explicit warning, credentials in secure storage and never in the database.

**Scoping a v1 honestly.**
Several features would have been easy to fake and hard to do right: run-count estimates need drop rates that have no clean public source, an official inventory API doesn't exist at all, and level 90→100 needs a non-farmable item. Rather than ship plausible-looking numbers, v1 stops at level 90, shows missing material counts instead of predicted run counts, and treats inventory as zero in totals-only mode — with those limits documented at the source. Multi-profile support follows the same rule: every table is `profileId`-scoped and every screen reads the active profile through one provider, while the two deliberate v1 gaps (background reminders and the HoYoLab credential are not per-profile) are written down where a future contributor will find them.

**Shipping the same codebase three ways.**
The app runs on Android, iOS and in the browser from one codebase, which meant confronting Drift's web story: `sqlite3.wasm` and `drift_worker.js` have to be served and configured explicitly, and the app has to degrade gracefully where native-only features (WebView login, exact alarms) aren't available. The launch page was then built by hand — Three.js hero, GSAP scroll choreography, custom cursor — with skip links for keyboard users and an in-page interactive resin calculator that mirrors the real engine's math, so visitors can verify the app's core claim before installing anything. Adding iOS later was mostly a test of whether those boundaries had held: the domain layers, the server-day math, the absolute-UTC notification instants and the Drift migrations all moved untouched, and the codebase still contains no `Platform.isIOS` branch. Four things genuinely differed, and the most interesting one cut both ways — iOS has no inexact-alarm mode, so "approximate" would have been a lie there, and replacing the exact-alarms bool with a three-state delivery report surfaced an Android bug where a denied notification permission still rendered as "Alerts fire on time".

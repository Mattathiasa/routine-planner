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

5. *(added in the data phase)* — see the section appended by `tool/build_catalog.dart` work:
   all catalog names and numbers are community-sourced and unverified in-game.

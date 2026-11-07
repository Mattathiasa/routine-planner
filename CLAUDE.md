# Routine Planner: Claude Code guide

Read `docs/ARCHITECTURE.md` first; it is the source of truth for decisions. Do not re-open settled decisions without asking.

## Build order
1. `flutter create` (Android first), pubspec with the packages listed in the architecture doc.
2. Theme from the approved design (below).
3. `core/clock` (Clock, ServerClock, FakeClock) + tests.
4. `features/resin/domain` (ResinEngine) + tests against the formulas. Do this before any UI.
5. Drift schema for user.db, catalog read layer with a tiny seed catalog.
6. Screens in order: Today, Resin, Planner, Settings.

## Design
Approved screens: `design/v3/*.dc.html` (Claude Design canvas files; open `design/canvas.json` in Claude Design, or read the HTML for exact values).
Light base, one accent indigo #3B4FE0, Manrope for headings/numbers, Inter for text. Depth from layered white cards, soft shadows, one gradient hero card per screen. Rarity = soft tint on material tiles; element = small badge on avatars. Pill floating bottom nav.
`design/earlier/` was rejected. Do not use it.

## Rules
- Domain code is pure Dart. No DateTime.now() anywhere; inject Clock.
- Do not copy or bundle the game's art, icons or UI. Placeholder icons only until a licensed-safe approach is decided.
- Names and numbers in the mocks are sample data.
- Commit messages: plain, no co-author trailers.

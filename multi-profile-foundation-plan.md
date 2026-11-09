# Multi-profile foundation — plan & progress

Local working doc, not part of the shipped app. Tracks the approved plan and live progress for the multi-profile foundation work. Not committed to git as part of the feature itself (delete or keep locally as you prefer).

## Context

The HoYoLab resin-sync feature (separate plan, see bottom of this file) is complete, tested, and pushed (6 commits, through `66d8efd`). While testing it, the user mentioned having multiple HoYoLab accounts and wanting to see each one's resin/commissions/etc. at once. Clarified: separate HoYoLab logins (not just multiple linked UIDs under one login), and multi-account should extend to the whole app (manual resin tracking, Planner, Today), not just stay scoped to new read-only synced screens.

That's a genuine architecture change, not a feature add, so per CLAUDE.md ("do not re-open settled decisions without asking") the real size of it was surfaced before planning further: every table in `user.db` is implicitly single-row today, every screen assumes one active save. Agreed to sequence this as two efforts: land a multi-profile **foundation** first (this plan — the ability to create/switch/delete local profiles, with Today/Resin/Planner correctly isolated per profile), verified and pushed on its own; then a **follow-up** plan builds multi-login HoYoLab sync and the new commissions/expeditions/realm-currency/boss-discount screens on top of it.

**The good news, confirmed by reading the actual source**: this schema was already built anticipating this. `lib/core/database/tables/profiles_table.dart`'s own comment says "the table exists so multi-account support doesn't require a schema change later," and every other table (`Settings`, `ResinAlertThresholds`, `PlannerTargets`, `MaterialInventory`, `DailyTasks`, `ResinStateTable`, `ResinEvents`) already has a `profileId` column; every repository method already takes `profileId` as an explicit parameter and filters by it. 15 files across Resin/Planner/Today/Settings/notifications all read the active profile through exactly one provider, `currentProfileProvider`. Because of that, making `currentProfileProvider` itself switchable should cascade correctly through the whole app via normal Riverpod invalidation, with **no changes needed to Resin/Planner/Today's internals**.

Two real landmines exist that must be fixed as part of this, not after:
1. `ProfileRepository.getOrCreateDefaultProfile()` queries with `.getSingleOrNull()` and no limit — Drift throws a `StateError` the moment a second live profile exists.
2. `BackupService.importBackupJson()` does an unscoped full-table wipe before importing — written for a single-profile app; once multiple profiles exist, importing one profile's backup would silently delete every other profile's data too.

Two deliberate scope cuts (documented, not silently skipped):
- **Notifications** continue to follow whichever profile is currently selected (today's exact behavior, just switchable) — not fanned out across every profile in the background.
- **`HoyolabCredentialsStore` stays global** (one cookie, not per-profile) for now — fixing it properly is the whole point of the follow-up plan.

## Commit 1 — `AppState` singleton table, `createdAt` on `Profiles`, and the project's first real migration

**Files**: `lib/core/database/tables/app_state_table.dart` (new), `lib/core/database/tables/profiles_table.dart`, `lib/core/database/ids.dart`, `lib/core/database/user_database.dart`, `drift_schemas/1.json` + `drift_schemas/2.json` (new, frozen snapshots — never hand-edit after creation), `test/generated_migrations/` (new, generated harness), `test/core/database/user_database_migration_test.dart` (new), `test/core/database/user_database_test.dart`.

New table — same "one wide typed row" shape `Settings` already uses, just global instead of per-profile:
```dart
class AppState extends Table {
  TextColumn get id => text()();
  TextColumn get selectedProfileId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
```
No FK on `selectedProfileId` — it's allowed to point at a soft-deleted profile between a delete and the next resolve; `ids.dart` gets `const appStateSingletonId = 'app_state';`.

`profiles_table.dart` adds `DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();` — needed because `updatedAt` changes on rename/server-switch and can't serve as a stable list order.

`user_database.dart`: register `AppState`, bump `schemaVersion` to 2, add a real `onUpgrade`:
```dart
onUpgrade: (m, from, to) async {
  if (from < 2) {
    await m.addColumn(profiles, profiles.createdAt);
    await m.createTable(appState);
    final existing = await (select(profiles)..where((t) => t.deletedAt.isNull()))
        .getSingleOrNull();
    await into(appState).insert(AppStateCompanion.insert(
      id: appStateSingletonId,
      selectedProfileId: Value(existing?.id),
      updatedAt: DateTime.now().toUtc(),
    ));
  }
},
```

**Migration tooling**: `dart run drift_dev schema dump <input> <output>` and `dart run drift_dev schema generate <input> <output>` confirmed to exist via `--help` (positional input/output). Steps:
1. Before schema edits: `dart run drift_dev schema dump lib/core/database/user_database.dart drift_schemas/` → v1 snapshot.
2. After edits: dump again → v2 snapshot.
3. `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/` → `SchemaVerifier` harness.
4. `user_database_migration_test.dart`: `verifySelfConsistency()` + hand-written data-preservation test (insert a Schema1 profile, migrate, assert untouched + `createdAt` backfilled + one `AppState` row pointing at it).
5. `user_database_test.dart`: extend `createAll()` test to cover `AppState`.

## Commit 2 — Multiple live profiles, with a persisted selection and safe fallback

Fixes landmine #1.

**Files**: `lib/core/database/repositories/profile_repository.dart` (rewrite), `lib/core/providers/current_profile_provider.dart`, `lib/core/providers/profile_providers.dart` (new), `test/core/database/profile_repository_test.dart` (rewrite/extend), `test/core/providers/current_profile_provider_test.dart`, `test/core/providers/profile_providers_test.dart` (new). Mechanical rename `getOrCreateDefaultProfile()` → `getActiveProfile()` at call sites in: `test/core/database/settings_repository_test.dart`, `test/core/database/planner_repository_test.dart`, `test/features/resin/data/resin_repository_test.dart`, `test/features/resin/data/resin_repository_undo_test.dart`, `test/features/settings/data/backup_service_test.dart`.

`ProfileRepository` gains `listProfiles()` (live only, ordered by `createdAt`), `createProfile({String? displayName, required String server})` (insert via `newId()`, re-query by that id), `renameProfile(id, displayName)`, `deleteProfile(id)` (soft-delete only, doesn't touch `AppState`), `selectProfile(id)` (upserts `AppState`). `getOrCreateDefaultProfile()` replaced by `getActiveProfile()`: persisted selection if live → else oldest remaining live profile (persisted as new selection) → else bootstrap fresh default.

New `profile_providers.dart` returns a plain record list (riverpod_generator workaround, matching existing `current_profile_provider.dart` precedent):
```dart
@riverpod
Future<List<({String id, String displayName, String server})>> profileList(Ref ref) async {
  final profiles = await ref.watch(profileRepositoryProvider).listProfiles();
  return [for (final p in profiles) (id: p.id, displayName: p.displayName, server: p.server)];
}
```
Not `keepAlive`.

**Tests**: creating a 2nd profile doesn't crash `getActiveProfile`; `listProfiles` excludes soft-deleted, orders by `createdAt`; fallback-to-oldest-remaining on deleted selection (persists fallback); bootstraps fresh when all deleted; `deleteProfile` doesn't touch `AppState`; `renameProfile` works; provider-level invalidation propagates correctly.

## Commit 3 — Scope backup import to the imported profile, not the whole database

Fixes landmine #2.

**Files**: `lib/features/settings/data/backup_service.dart`, `lib/features/settings/presentation/data_section.dart`, `test/features/settings/data/backup_service_test.dart`.

`importBackupJson` reads target `profileId` from the backup JSON first, scopes every delete `..where((t) => t.profileId.equals(profileId))` instead of unscoped wipes. Returns the imported profile's id.

`data_section.dart`: confirm-import copy changes to "replaces that account's data"; after import, `selectProfile(importedId)` + invalidate `currentProfileProvider`, land on imported profile immediately — drop "please relaunch the app" workaround.

**Tests**: multi-profile isolation case — export A, mutate both A and B further, import A's export, assert B completely untouched.

## Commit 4 — Document the notification and HoYoLab scoping limitations

No behavior change — just making the two deliberate scope cuts explicit.

**Files**: `lib/core/providers/notification_providers.dart`, `lib/core/hoyolab/data/hoyolab_credentials_store.dart` and/or `lib/core/providers/hoyolab_providers.dart`, `docs/ARCHITECTURE.md`, `test/core/providers/notification_reconcile_test.dart`.

**Tests**: two-profile notification scenario proving profile A's alarm is gone (not merely unchanged) after switching to B and reconciling.

## Commit 5 — Accounts section in Settings

**Files**: `lib/features/settings/presentation/accounts_section.dart` (new), `lib/features/settings/presentation/settings_screen.dart`, `test/features/settings/presentation/accounts_section_test.dart` (new), `test/features/settings/presentation/settings_screen_test.dart`.

Placed above `GameServerSection`. `RadioGroup<String>` over `profileListProvider`, tap-to-select (same pattern as `GameServerSection`). Trailing menu: Rename (dialog), Delete (confirmation, disabled at 1 remaining profile). "Add profile" row: name dialog (optional) → `createProfile` (server defaulted to current) → select → land on new profile.

**Tests**: starts with 1 profile selected; add switches to new; tap-switch works; rename updates display; delete removes non-selected; delete disabled at 1 remaining; deleting selected falls back correctly.

## Other risks, accepted as-is
- Soft-deleting a profile doesn't cascade-delete its child rows (harmless, no restore UI exists anyway).
- Export stays single-profile-at-a-time, no picker.
- `getActiveProfile()`'s fallback persistence isn't transactionally guarded (fine given Riverpod's single-flight de-dupe).

## Verification
- After commit 1: `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, migration test passing specifically.
- After every commit: `flutter analyze` clean, full `flutter test` green.
- Emulator spot-check after commit 5: fresh install still single-profile zero-friction; add 2nd profile, confirm independent state after switching; delete non-active profile; export/import round-trips.
- 5 commits, plain messages, no co-author trailer. **Push once at the end, after all 5 are in and verified** — not after every commit, per explicit instruction this time.

---

## PROGRESS LOG

### Commit 1 — AppState table + createdAt + first migration — DONE
- [x] Dump v1 schema snapshot (`drift_schemas/drift_schema_v1.json`)
- [x] Add `createdAt` to `profiles_table.dart`
- [x] Create `app_state_table.dart`
- [x] Add `appStateSingletonId` to `ids.dart`
- [x] Register `AppState` + bump schemaVersion to 2 + `onUpgrade` in `user_database.dart`
- [x] Dump v2 schema snapshot (`drift_schemas/drift_schema_v2.json`)
- [x] Generate migration test harness (`test/generated_migrations/`, with `--data-classes --companions`)
- [x] Write `user_database_migration_test.dart`
- [x] Extend `user_database_test.dart`
- [x] `build_runner build`, `flutter analyze` clean, `flutter test` green (194 passing)
- [x] Commit

**Note**: a second Claude Code session sharing this working tree ("fix-dark-mode-colors", building unrelated web/landing-page support) ran a broad `git add` and committed `1989848` before I could commit my own work — it accidentally swept in `app_state_table.dart`, the `profiles_table.dart`/`ids.dart` edits, and `drift_schemas/`, bundled into their unrelated "add github pages" commit (already pushed, did not rewrite history). My actual bug fix (switching `m.addColumn` to `m.alterTable` after the migration test caught a real SQLite "non-constant default" rejection) plus all new test files landed cleanly in my own commit `6ba9edf`. Content is correct either way; just split across two commits instead of one. Also deleted `test/widget_test.dart` (untracked, dead `flutter create` boilerplate referencing a nonexistent `MyApp` — unrelated cleanup, not committed since it was never tracked).

**Real bug caught by the migration test itself**: SQLite rejects `ALTER TABLE ADD COLUMN ... DEFAULT (CURRENT_TIMESTAMP)` (non-constant defaults aren't allowed in `ADD COLUMN`, only in `CREATE TABLE`). Fixed via `m.alterTable(TableMigration(profiles, newColumns: [profiles.createdAt]))`, which rebuilds the table instead and sidesteps the restriction — existing rows get `createdAt` via the table's own `CREATE TABLE`-level default during the copy.

### Commit 2 — Multiple live profiles + selection + fallback — DONE (`fd238b7`)
- [x] Rewrite `profile_repository.dart`
- [x] Update `current_profile_provider.dart`
- [x] New `profile_providers.dart`
- [x] Rename `getOrCreateDefaultProfile` → `getActiveProfile` at all test call sites
- [x] Tests written/passing
- [x] `flutter analyze` clean, `flutter test` green (204 passing)
- [x] Commit

### Commit 3 — Scope backup import to one profile — DONE (`043d018`)
- [x] Fix `backup_service.dart` import scoping (also now returns the imported profileId)
- [x] Update `data_section.dart` (copy + auto-select imported profile, dropped "please relaunch")
- [x] Multi-profile isolation test
- [x] `flutter analyze` clean, `flutter test` green (205 passing)
- [x] Commit

### Commit 4 — Document scoping limitations — DONE (`758ef34`)
- [x] Doc comments on notification_providers.dart / hoyolab providers / backup_service.dart
- [x] `docs/ARCHITECTURE.md` updated
- [x] Two-profile notification test
- [x] `flutter analyze` clean, `flutter test` green (206 passing)
- [x] Commit

### Commit 5 — Accounts section in Settings
- [ ] `accounts_section.dart` built
- [ ] Wired into `settings_screen.dart`
- [ ] Widget tests written/passing
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Emulator verification (fresh install, add/switch/delete profile, export/import)
- [ ] Commit

### Final
- [ ] All 5 commits in, full suite green
- [ ] Push once (user confirmation required first)

---

## Reference: HoYoLab account sync plan (already complete)

Status: complete, pushed through `66d8efd`. Full original plan preserved in the Claude Code plan-mode file at `~/.claude/plans/read-claude-md-and-docs-architecture-md-splendid-dragonfly.md` if needed — field names/response shape verified there will be reused by the follow-up multi-login plan.

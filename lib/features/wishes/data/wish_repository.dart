import 'package:drift/drift.dart';

import '../../../core/database/ids.dart';
import '../../../core/database/user_database.dart';
import '../domain/wish_banner.dart';
import '../domain/wish_pull.dart';

/// Reads and writes one account's wish history and its import bookkeeping.
/// Pure persistence — paging, rate limits and pity maths live elsewhere.
class WishRepository {
  WishRepository(this._db);

  final UserDatabase _db;

  /// Stores [pulls] and advances the high-water mark for every banner they
  /// touch.
  ///
  /// Idempotent: the rows are keyed by the upstream snowflake id, so
  /// re-importing an overlapping window updates rows in place instead of
  /// duplicating them. Returns how many of [pulls] were not already stored,
  /// which is what the import reports as "imported".
  Future<int> insertPulls(
    String profileId,
    List<WishPull> pulls, {
    required DateTime now,
  }) async {
    if (pulls.isEmpty) return 0;

    final existingIds = await _existingIds(profileId, [
      for (final pull in pulls) pull.id,
    ]);

    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.wishPulls, [
        for (final pull in pulls)
          WishPullsCompanion.insert(
            id: pull.id,
            profileId: profileId,
            bannerType: pull.banner.gachaType,
            itemName: pull.itemName,
            itemKind: pull.kind.name,
            rarity: pull.rarity,
            pulledAt: pull.pulledAtUtc,
            updatedAt: now,
          ),
      ]);
    });

    // Highest id per banner in this batch, which is the newest pull — ids are
    // monotonic.
    final newestByBanner = <WishBanner, String>{};
    for (final pull in pulls) {
      final current = newestByBanner[pull.banner];
      if (current == null || _idIsNewer(pull.id, current)) {
        newestByBanner[pull.banner] = pull.id;
      }
    }
    for (final entry in newestByBanner.entries) {
      await _advanceHighWaterMark(
        profileId,
        entry.key,
        entry.value,
        now: now,
      );
    }

    return pulls.length - existingIds.length;
  }

  /// This account's pulls, oldest first — the order every domain function in
  /// `pity_calculator.dart` and `wish_stats.dart` expects.
  Future<List<WishPull>> pullsFor(
    String profileId, {
    WishBanner? banner,
  }) async {
    final query = _db.select(_db.wishPulls)
      ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull());
    if (banner != null) {
      query.where((t) => t.bannerType.equals(banner.gachaType));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.id)]);

    final rows = await query.get();
    return [
      for (final row in rows)
        if (WishBanner.fromGachaType(row.bannerType) case final banner?)
          WishPull(
            id: row.id,
            banner: banner,
            itemName: row.itemName,
            kind: WishItemKind.values.firstWhere(
              (kind) => kind.name == row.itemKind,
              orElse: () => WishItemKind.weapon,
            ),
            rarity: row.rarity,
            pulledAtUtc: row.pulledAt,
          ),
    ];
  }

  Future<int> pullCount(String profileId) async {
    final count = _db.wishPulls.id.count();
    final row =
        await (_db.selectOnly(_db.wishPulls)
              ..addColumns([count])
              ..where(
                _db.wishPulls.profileId.equals(profileId) &
                    _db.wishPulls.deletedAt.isNull(),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// How many wishes this account made strictly after [since] — what the
  /// primogem ledger charges 160 primogems each for.
  Future<int> pullCountSince(String profileId, DateTime since) async {
    final count = _db.wishPulls.id.count();
    final row =
        await (_db.selectOnly(_db.wishPulls)
              ..addColumns([count])
              ..where(
                _db.wishPulls.profileId.equals(profileId) &
                    _db.wishPulls.deletedAt.isNull() &
                    _db.wishPulls.pulledAt.isBiggerThanValue(since),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<List<WishImportStateData>> importStateFor(String profileId) {
    return (_db.select(_db.wishImportState)
          ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull()))
        .get();
  }

  /// The newest pull id already stored for this banner, or null before the
  /// first successful import. The importer stops paging when it reaches it.
  Future<String?> lastImportedId(String profileId, WishBanner banner) async {
    final row = await _stateRow(profileId, banner);
    return row?.lastImportedPullId;
  }

  /// Manually entered pity, for an account that can't produce a wish-history
  /// link. Null values clear that field.
  Future<void> saveManualPity(
    String profileId,
    WishBanner banner, {
    required int? pityFive,
    required int? pityFour,
    required bool? guaranteed,
    required DateTime now,
  }) async {
    final existing = await _stateRow(profileId, banner);
    await _db
        .into(_db.wishImportState)
        .insertOnConflictUpdate(
          WishImportStateCompanion.insert(
            id: existing?.id ?? newId(),
            profileId: profileId,
            bannerType: banner.gachaType,
            lastImportedPullId: Value(existing?.lastImportedPullId),
            lastImportedAt: Value(existing?.lastImportedAt),
            manualPityFive: Value(pityFive),
            manualPityFour: Value(pityFour),
            manualGuaranteed: Value(guaranteed),
            manualUpdatedAt: Value(now),
            updatedAt: now,
          ),
        );
  }

  /// Hard-deletes this account's history and import state.
  ///
  /// Hard, not soft, and for the same reason `clearSnapshot` is: a soft-
  /// deleted row would keep its snowflake primary key and block the next
  /// import of that same pull.
  Future<void> clearPulls(String profileId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.wishPulls,
      )..where((t) => t.profileId.equals(profileId))).go();
      await (_db.delete(
        _db.wishImportState,
      )..where((t) => t.profileId.equals(profileId))).go();
    });
  }

  Future<WishImportStateData?> _stateRow(
    String profileId,
    WishBanner banner,
  ) {
    return (_db.select(_db.wishImportState)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.bannerType.equals(banner.gachaType) &
              t.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<Set<String>> _existingIds(String profileId, List<String> ids) async {
    final rows =
        await (_db.selectOnly(_db.wishPulls)
              ..addColumns([_db.wishPulls.id])
              ..where(
                _db.wishPulls.profileId.equals(profileId) &
                    _db.wishPulls.id.isIn(ids),
              ))
            .map((row) => row.read(_db.wishPulls.id)!)
            .get();
    return rows.toSet();
  }

  Future<void> _advanceHighWaterMark(
    String profileId,
    WishBanner banner,
    String candidateId, {
    required DateTime now,
  }) async {
    final existing = await _stateRow(profileId, banner);
    final currentMark = existing?.lastImportedPullId;
    // Never move the mark backwards: a re-import of an older window must not
    // make the next import re-walk history it already has.
    final mark = currentMark == null || _idIsNewer(candidateId, currentMark)
        ? candidateId
        : currentMark;

    await _db
        .into(_db.wishImportState)
        .insertOnConflictUpdate(
          WishImportStateCompanion.insert(
            id: existing?.id ?? newId(),
            profileId: profileId,
            bannerType: banner.gachaType,
            lastImportedPullId: Value(mark),
            lastImportedAt: Value(now),
            manualPityFive: Value(existing?.manualPityFive),
            manualPityFour: Value(existing?.manualPityFour),
            manualGuaranteed: Value(existing?.manualGuaranteed),
            manualUpdatedAt: Value(existing?.manualUpdatedAt),
            updatedAt: now,
          ),
        );
  }
}

/// Compares two snowflake ids. They're decimal numbers too long for an int,
/// but fixed-width in practice, so a length-then-lexicographic compare orders
/// them correctly without a BigInt parse.
bool _idIsNewer(String candidate, String current) {
  if (candidate.length != current.length) {
    return candidate.length > current.length;
  }
  return candidate.compareTo(current) > 0;
}

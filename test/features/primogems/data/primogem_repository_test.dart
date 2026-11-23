import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine_planner/core/database/user_database.dart';
import 'package:routine_planner/features/primogems/data/primogem_repository.dart';

final now = DateTime.utc(2026, 11, 3, 12);

void main() {
  late UserDatabase db;
  late PrimogemRepository repository;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    repository = PrimogemRepository(db);
    addTearDown(db.close);

    for (final (id, name) in [('profile-1', 'Main'), ('profile-2', 'Alt')]) {
      await db
          .into(db.profiles)
          .insert(
            ProfilesCompanion.insert(
              id: id,
              displayName: Value(name),
              server: 'asia',
              updatedAt: now,
            ),
          );
    }
  });

  group('anchor', () {
    test('starts absent', () async {
      expect(await repository.anchorFor('profile-1'), isNull);
    });

    test('round-trips every field', () async {
      await repository.setAnchor(
        'profile-1',
        balance: 12480,
        fates: 7,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 3200,
      );

      final anchor = await repository.anchorFor('profile-1');

      expect(anchor!.balance, 12480);
      expect(anchor.fates, 7);
      expect(anchor.anchoredAt, now);
      expect(anchor.anchorMonth, '2026-11');
      expect(anchor.anchorMonthIncomeAtAnchor, 3200);
    });

    test('re-anchoring replaces rather than stacking', () async {
      await repository.setAnchor(
        'profile-1',
        balance: 100,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 0,
      );
      await repository.setAnchor(
        'profile-1',
        balance: 500,
        fates: 1,
        anchoredAt: now.add(const Duration(days: 1)),
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: 60,
      );

      expect(await db.select(db.primogemAnchors).get(), hasLength(1));
      expect((await repository.anchorFor('profile-1'))!.balance, 500);
    });

    test('keeps a null month reading when the diary was unreachable', () async {
      await repository.setAnchor(
        'profile-1',
        balance: 100,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: null,
      );

      expect(
        (await repository.anchorFor('profile-1'))!.anchorMonthIncomeAtAnchor,
        isNull,
      );
    });

    test('is scoped per account', () async {
      await repository.setAnchor(
        'profile-1',
        balance: 100,
        fates: 0,
        anchoredAt: now,
        anchorMonth: '2026-11',
        monthIncomeAtAnchor: null,
      );

      expect(await repository.anchorFor('profile-2'), isNull);
    });
  });

  group('monthly income', () {
    test('stores a month and reads it back as a map', () async {
      await repository.saveMonthlyIncome(
        'profile-1',
        month: '2026-11',
        primogems: 3200,
        fetchedAt: now,
      );

      expect(await repository.monthlyIncomeFor('profile-1'), {
        '2026-11': 3200,
      });
    });

    test('overwrites a month in place as it grows', () async {
      await repository.saveMonthlyIncome(
        'profile-1',
        month: '2026-11',
        primogems: 3200,
        fetchedAt: now,
      );
      await repository.saveMonthlyIncome(
        'profile-1',
        month: '2026-11',
        primogems: 3460,
        fetchedAt: now.add(const Duration(hours: 6)),
      );

      expect(await db.select(db.primogemMonthlyIncome).get(), hasLength(1));
      expect(await repository.monthlyIncomeFor('profile-1'), {
        '2026-11': 3460,
      });
    });

    test('keeps separate rows per month', () async {
      await repository.saveMonthlyIncome(
        'profile-1',
        month: '2026-10',
        primogems: 5000,
        fetchedAt: now,
      );
      await repository.saveMonthlyIncome(
        'profile-1',
        month: '2026-11',
        primogems: 3200,
        fetchedAt: now,
      );

      expect(await repository.monthlyIncomeFor('profile-1'), {
        '2026-10': 5000,
        '2026-11': 3200,
      });
    });

    test('reports the newest fetch time across months', () async {
      await repository.saveMonthlyIncome(
        'profile-1',
        month: '2026-10',
        primogems: 5000,
        fetchedAt: now,
      );
      final later = now.add(const Duration(hours: 3));
      await repository.saveMonthlyIncome(
        'profile-1',
        month: '2026-11',
        primogems: 3200,
        fetchedAt: later,
      );

      expect(await repository.incomeLastFetchedAt('profile-1'), later);
    });

    test('has no fetch time before the first fetch', () async {
      expect(await repository.incomeLastFetchedAt('profile-1'), isNull);
    });
  });

  group('adjustments', () {
    test('appends, newest first', () async {
      await repository.addAdjustment(
        'profile-1',
        delta: -1600,
        note: 'spent on resin',
        occurredAt: now,
      );
      await repository.addAdjustment(
        'profile-1',
        delta: 300,
        occurredAt: now.add(const Duration(hours: 1)),
      );

      final adjustments = await repository.adjustmentsFor('profile-1');

      expect(adjustments.map((a) => a.delta), [300, -1600]);
      expect(adjustments.last.note, 'spent on resin');
      expect(adjustments.first.note, isNull);
    });

    test('accumulates rather than replacing', () async {
      await repository.addAdjustment('profile-1', delta: 60, occurredAt: now);
      await repository.addAdjustment('profile-1', delta: 60, occurredAt: now);

      expect(await repository.adjustmentsFor('profile-1'), hasLength(2));
    });

    test('a removed adjustment stops being read', () async {
      await repository.addAdjustment('profile-1', delta: 60, occurredAt: now);
      final adjustment = (await repository.adjustmentsFor('profile-1')).single;

      await repository.removeAdjustment(adjustment.id, now: now);

      expect(await repository.adjustmentsFor('profile-1'), isEmpty);
      // Soft-deleted, so the correction history survives.
      expect(await db.select(db.primogemAdjustments).get(), hasLength(1));
    });
  });

  group('clearLedger', () {
    test('drops one account ledger and leaves the others', () async {
      for (final profileId in ['profile-1', 'profile-2']) {
        await repository.setAnchor(
          profileId,
          balance: 100,
          fates: 0,
          anchoredAt: now,
          anchorMonth: '2026-11',
          monthIncomeAtAnchor: null,
        );
        await repository.saveMonthlyIncome(
          profileId,
          month: '2026-11',
          primogems: 500,
          fetchedAt: now,
        );
        await repository.addAdjustment(
          profileId,
          delta: 60,
          occurredAt: now,
        );
      }

      await repository.clearLedger('profile-1');

      expect(await repository.anchorFor('profile-1'), isNull);
      expect(await repository.monthlyIncomeFor('profile-1'), isEmpty);
      expect(await repository.adjustmentsFor('profile-1'), isEmpty);

      expect(await repository.anchorFor('profile-2'), isNotNull);
      expect(await repository.monthlyIncomeFor('profile-2'), hasLength(1));
      expect(await repository.adjustmentsFor('profile-2'), hasLength(1));
    });
  });
}

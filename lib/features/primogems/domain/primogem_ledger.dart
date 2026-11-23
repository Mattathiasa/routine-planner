/// Primogem balance arithmetic.
///
/// Pure Dart — no Flutter/Riverpod/Drift imports — and every function takes
/// an explicit `now`, like `ResinEngine`.
///
/// Nothing exposes a live primogem balance, so the balance is derived the way
/// resin is: from an anchor the player entered, plus everything that has
/// happened since. Income comes from the Traveler's Diary (primogems
/// *earned*, month to date), spending from imported wishes at
/// [primogemsPerWish] each, and anything else from manual adjustments.
///
/// The projection constants are community knowledge, not verified game
/// values; each sits behind a named constant. See `docs/ASSUMPTIONS.md`.
library;

import '../../wishes/domain/pity_calculator.dart' show primogemsPerWish;

/// Four daily commissions plus the completion bonus.
const commissionPrimogems = 60;

/// Blessing of the Welkin Moon, per day.
const welkinPrimogems = 90;

/// The battle pass's paid tier, per cycle, and the cycle's length — stored
/// separately so the per-day figure is visibly a division and not a magic
/// number.
const battlePassPrimogems = 680;
const battlePassCycleDays = 42;

/// The anchor, lifted out of its Drift row so this stays pure.
typedef PrimogemAnchorInput = ({
  int balance,
  int fates,
  DateTime anchoredAt,

  /// `YYYY-MM` of the anchor's server month.
  String anchorMonth,

  /// The diary's month-to-date reading when the anchor was set, or null when
  /// the diary wasn't reachable.
  int? monthIncomeAtAnchor,
});

typedef PrimogemAdjustmentInput = ({DateTime at, int delta});

/// The balance as of [now].
///
/// Income is counted from month rows strictly after the anchor month, plus
/// whatever the anchor month has earned *since* the anchor was set. That last
/// part needs [PrimogemAnchorInput.monthIncomeAtAnchor]: the diary reports a
/// month-to-date total, so without knowing what it read at anchor time, the
/// income already included in the entered balance would be counted twice.
/// When it is null, none of the anchor month is credited — understating the
/// balance is the safer error, and a manual adjustment can correct it.
///
/// Clamped at zero. A negative balance is impossible in game, so a negative
/// result means something was mis-entered, and showing a negative number
/// would be less useful than showing nothing owed.
int balanceAt({
  required PrimogemAnchorInput anchor,
  required Map<String, int> monthlyIncome,
  required List<PrimogemAdjustmentInput> adjustments,
  required int wishesSinceAnchor,
  required DateTime now,
}) {
  var income = 0;
  for (final entry in monthlyIncome.entries) {
    // 'YYYY-MM' sorts chronologically as a string.
    if (entry.key.compareTo(anchor.anchorMonth) > 0) {
      income += entry.value;
    } else if (entry.key == anchor.anchorMonth) {
      final atAnchor = anchor.monthIncomeAtAnchor;
      if (atAnchor != null) {
        final since = entry.value - atAnchor;
        if (since > 0) income += since;
      }
    }
  }

  var adjusted = 0;
  for (final adjustment in adjustments) {
    if (adjustment.at.isAfter(anchor.anchoredAt)) {
      adjusted += adjustment.delta;
    }
  }

  final spent = wishesSinceAnchor * primogemsPerWish;
  final balance = anchor.balance + income + adjusted - spent;
  return balance < 0 ? 0 : balance;
}

/// How many wishes [balance] buys, counting [fates] already held.
int wishesAffordable(int balance, {int fates = 0}) =>
    fates + balance ~/ primogemsPerWish;

/// Primogems a day from the sources the player says they have.
///
/// Commissions are always counted — they're free and daily. Welkin and the
/// battle pass are opt-in, and both default off in settings: assuming a
/// purchase nobody made would overstate every forecast built on this.
int projectedDailyIncome({required bool welkin, required bool battlePass}) {
  var daily = commissionPrimogems;
  if (welkin) daily += welkinPrimogems;
  if (battlePass) daily += battlePassPrimogems ~/ battlePassCycleDays;
  return daily;
}

/// When [wishes] wishes become affordable, or null if never at this rate.
///
/// Returns [now] when they already are. Null only when nothing is coming in,
/// which the UI shows as "set your income sources" rather than a date.
DateTime? dateForWishes({
  required int balance,
  required int fates,
  required int wishes,
  required int dailyIncome,
  required DateTime now,
}) {
  final shortfall = (wishes - fates) * primogemsPerWish - balance;
  if (shortfall <= 0) return now;
  if (dailyIncome <= 0) return null;
  final days = (shortfall + dailyIncome - 1) ~/ dailyIncome;
  return now.add(Duration(days: days));
}

/// Primogems still needed for [wishes] wishes. Zero once they're affordable.
int shortfallFor({
  required int balance,
  required int fates,
  required int wishes,
}) {
  final shortfall = (wishes - fates) * primogemsPerWish - balance;
  return shortfall < 0 ? 0 : shortfall;
}

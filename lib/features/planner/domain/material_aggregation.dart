/// Pure material-need aggregation — the tier-walking, ratio-3, EXP/Mora
/// math from `docs/ARCHITECTURE.md`'s "Material aggregation" section. No
/// Flutter/Riverpod/Drift imports, mirroring `ResinEngine`'s purity:
/// callers convert Drift rows into these plain shapes first, and own the
/// catalog-driven grouping (which materials share a tier group, and in
/// what order) — this module only knows how to walk a group once it's
/// handed one.
library;

/// A material and how much of it is needed, from one requirement source
/// (an ascension phase, a talent level, or a derived EXP/Mora total).
typedef Quantity = ({String materialId, int quantity});

/// One material's need/have/missing after a tier-walk. `have` is the
/// *displayed* have (`min(need, rawHave + carryIn)`), so `missing` and
/// `have` always stay arithmetically consistent with `need` on screen.
typedef MaterialNeedResult = ({String materialId, int need, int have, int missing});

/// Sums [rows] into a single need-per-material map.
Map<String, int> accumulateNeed(Iterable<Quantity> rows) {
  final need = <String, int>{};
  for (final row in rows) {
    need[row.materialId] = (need[row.materialId] ?? 0) + row.quantity;
  }
  return need;
}

/// Greedily allocates [totalExp] across EXP books, largest value first.
/// Every book but the smallest takes as many as fit whole; the smallest
/// rounds up to guarantee full coverage, since a fractional book can't be
/// used. Returns `{}` for a non-positive total or an empty book list —
/// never throws (an empty catalog of EXP books is an accepted gap in a
/// tiny seed catalog, not an error).
Map<String, int> allocateExpBooks(
  int totalExp,
  List<({String materialId, int expValue})> booksDescByValue,
) {
  if (totalExp <= 0 || booksDescByValue.isEmpty) return {};

  var remaining = totalExp;
  final counts = <String, int>{};
  for (var i = 0; i < booksDescByValue.length; i++) {
    final book = booksDescByValue[i];
    final isSmallest = i == booksDescByValue.length - 1;
    final count = isSmallest ? (remaining / book.expValue).ceil() : remaining ~/ book.expValue;
    if (count > 0) counts[book.materialId] = count;
    remaining -= count * book.expValue;
  }
  return counts;
}

/// Walks one tier-group's materials low-to-high, carrying surplus `have`
/// upward at a 3:1 ratio (3 units of a lower tier's surplus convert to 1
/// unit of the next tier's effective stock).
///
/// [ascendingByTier] must include **every** material in the group, even
/// ones this particular need doesn't touch (need `0`) — a zero-need low
/// tier still donates its entire stock upward via carry; dropping it would
/// silently strand that inventory. For a material with no tier group
/// (boss/EXP-book/currency materials), call this with a single-element
/// list — the walk then degenerates to a plain `min(need, have)` clamp
/// with no carry, since there's nowhere higher to go.
List<MaterialNeedResult> walkTierGroup(
  List<({String materialId, int need})> ascendingByTier,
  Map<String, int> have,
) {
  var carry = 0;
  final out = <MaterialNeedResult>[];
  for (final m in ascendingByTier) {
    final effectiveHave = (have[m.materialId] ?? 0) + carry;
    final displayedHave = m.need < effectiveHave ? m.need : effectiveHave;
    final surplus = effectiveHave > m.need ? effectiveHave - m.need : 0;
    carry = surplus ~/ 3;
    out.add((
      materialId: m.materialId,
      need: m.need,
      have: displayedHave,
      missing: m.need - displayedHave,
    ));
  }
  return out;
}

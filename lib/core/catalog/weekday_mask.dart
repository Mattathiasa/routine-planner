/// Bit0 = Monday ... bit5 = Saturday; Sunday is always open regardless of
/// the stored mask (see `ServerClock`'s "Sunday opens all" rule), so only
/// Monday..Saturday need to be set for a mask to cover every day. Shared
/// between Today's farm cards and Planner's "Most needed" availability
/// text, both of which need the same "is this combined domain-drops mask
/// always open" check and the same human-readable day formatting.
const nonSundayBitsMask = 0x3F;

const _dayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Whether a combined [DomainDrops.weekdayMask] (OR'd across every drop
/// row for a domain) covers every day of the week.
bool isAlwaysOpen(int mask) => (mask & nonSundayBitsMask) == nonSundayBitsMask;

/// Whether [mask] is open on [isoWeekday] (`DateTime.monday..sunday`).
/// Sunday is always open, regardless of the stored mask.
bool isOpenOnWeekday(int mask, int isoWeekday) {
  if (isoWeekday == DateTime.sunday) return true;
  return (mask & (1 << (isoWeekday - DateTime.monday))) != 0;
}

/// `"Tue, Fri, Sun"`-style formatting of the days set in [mask].
String formatWeekdayMask(int mask) {
  return [
    for (var i = 0; i < _dayAbbreviations.length; i++)
      if (mask & (1 << i) != 0) _dayAbbreviations[i],
  ].join(', ');
}

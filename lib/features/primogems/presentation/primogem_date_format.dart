/// Date formatting for the primogem forecast.
///
/// Pure and intl-free, like the rest of this codebase's formatting helpers —
/// one more dependency for one more date string isn't worth it.
library;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `12 Feb`, or `12 Feb 2027` when the date falls outside this year.
///
/// The year only appears when it matters: a forecast months out reads better
/// without it, and one a year out is misleading without it.
String formatForecastDate(DateTime date, {DateTime? relativeTo}) {
  final month = _months[date.month - 1];
  final reference = relativeTo;
  if (reference != null && reference.year == date.year) {
    return '${date.day} $month';
  }
  return '${date.day} $month ${date.year}';
}

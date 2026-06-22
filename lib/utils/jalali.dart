// Pure-Dart Gregorian → Jalali (Shamsi) calendar conversion.
// Algorithm: Borkowski's method, validated against ICU and shamsi_date package.

class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  static const List<String> _monthNames = <String>[
    'فروردین', 'اردیبهشت', 'خرداد',
    'تیر',     'مرداد',    'شهریور',
    'مهر',     'آبان',     'آذر',
    'دی',      'بهمن',     'اسفند',
  ];

  String get monthName => _monthNames[month - 1];
}

JalaliDate toJalali(DateTime gregorian) {
  int gy = gregorian.year;
  int gm = gregorian.month;
  int gd = gregorian.day;

  final List<int> gDaysInMonth = <int>[0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

  int gy2 = (gm > 2) ? gy + 1 : gy;
  int days = 355666
      + (365 * gy)
      + ((gy2 + 3) ~/ 4)
      - ((gy2 + 99) ~/ 100)
      + ((gy2 + 399) ~/ 400)
      + gd
      + gDaysInMonth[gm - 1];

  int jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;

  jy += 4 * (days ~/ 1461);
  days %= 1461;

  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }

  int jm;
  int jd;
  if (days < 186) {
    jm = 1 + (days ~/ 31);
    jd = 1 + (days % 31);
  } else {
    jm = 7 + ((days - 186) ~/ 30);
    jd = 1 + ((days - 186) % 30);
  }

  return JalaliDate(jy, jm, jd);
}

String jalaliLabel(DateTime dt) {
  final JalaliDate j = toJalali(dt);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}

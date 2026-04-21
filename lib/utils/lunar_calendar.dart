/// Bộ chuyển đổi Dương lịch sang Âm lịch đơn giản
/// Sử dụng thuật toán tính toán lịch âm Việt Nam
class LunarCalendar {
  /// Chuyển đổi ngày dương lịch sang âm lịch
  /// Trả về Map chứa: day, month, year, leap (tháng nhuận)
  static Map<String, int> solarToLunar(int solarDay, int solarMonth, int solarYear) {
    final jd = _jdFromDate(solarDay, solarMonth, solarYear);
    final k = _intPart((jd - 2415021.076998695) / 29.530588853);
    var monthStart = _getNewMoonDay(k + 1);
    if (monthStart > jd) {
      monthStart = _getNewMoonDay(k);
    }
    var a11 = _getLunarMonth11(solarYear);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = solarYear;
      a11 = _getLunarMonth11(solarYear - 1);
    } else {
      lunarYear = solarYear + 1;
      b11 = _getLunarMonth11(solarYear + 1);
    }
    final lunarDay = jd - monthStart + 1;
    final diff = _intPart((monthStart - a11) / 29);
    var lunarLeap = 0;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final leapMonthDiff = _getLeapMonthOffset(a11);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          lunarLeap = 1;
        }
      }
    }
    if (lunarMonth > 12) {
      lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }
    return {
      'day': lunarDay.toInt(),
      'month': lunarMonth.toInt(),
      'year': lunarYear,
      'leap': lunarLeap,
    };
  }

  /// Format ngày âm lịch dạng "Ngày DD tháng MM năm YYYY (Âm lịch)"
  static String formatLunar(int solarDay, int solarMonth, int solarYear) {
    final lunar = solarToLunar(solarDay, solarMonth, solarYear);
    final leapStr = lunar['leap'] == 1 ? ' (nhuận)' : '';
    return 'Ngày ${lunar['day']} tháng ${lunar['month']}$leapStr năm ${lunar['year']} (Âm lịch)';
  }

  /// Format ngắn gọn
  static String formatLunarShort(int solarDay, int solarMonth, int solarYear) {
    final lunar = solarToLunar(solarDay, solarMonth, solarYear);
    final leapStr = lunar['leap'] == 1 ? '*' : '';
    return '${lunar['day']}/${lunar['month']}$leapStr/${lunar['year']}';
  }

  // --- Helper functions ---

  static int _jdFromDate(int dd, int mm, int yy) {
    final a = _intPart((14 - mm) / 12);
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    var jd = dd +
        _intPart((153 * m + 2) / 5) +
        365 * y +
        _intPart(y / 4) -
        _intPart(y / 100) +
        _intPart(y / 400) -
        32045;
    if (jd < 2299161) {
      jd = dd + _intPart((153 * m + 2) / 5) + 365 * y + _intPart(y / 4) - 32083;
    }
    return jd;
  }

  static int _getNewMoonDay(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    final dr = 3.14159265358979323846 / 180;
    var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 *
        _sin(166.56 + 132.87 * t - 0.009173 * t2, dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * _sin(m, dr) + 0.0021 * _sin(2 * m, dr);
    c1 = c1 - 0.4068 * _sin(mpr, dr) + 0.0161 * _sin(2 * mpr, dr);
    c1 = c1 - 0.0004 * _sin(3 * mpr, dr);
    c1 = c1 + 0.0104 * _sin(2 * f, dr) - 0.0051 * _sin(m + mpr, dr);
    c1 = c1 - 0.0074 * _sin(m - mpr, dr) + 0.0004 * _sin(2 * f + m, dr);
    c1 = c1 - 0.0004 * _sin(2 * f - m, dr) - 0.0006 * _sin(2 * f + mpr, dr);
    c1 = c1 + 0.0010 * _sin(2 * f - mpr, dr) + 0.0005 * _sin(2 * mpr + m, dr);
    final jd = jd1 + c1;
    return (jd + 0.5 + 7.0 / 24.0).floor();
  }

  static int _getLunarMonth11(int yy) {
    final off = _jdFromDate(31, 12, yy) - 2415021;
    final k = _intPart(off / 29.530588853);
    var nm = _getNewMoonDay(k);
    final sunLong = _getSunLongitude(nm);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1);
    }
    return nm;
  }

  static int _getLeapMonthOffset(int a11) {
    final k = _intPart((a11 - 2415021.076998695) / 29.530588853 + 0.5);
    int last;
    var i = 1;
    var arc = _getSunLongitude(_getNewMoonDay(k + i));
    do {
      last = arc;
      i++;
      arc = _getSunLongitude(_getNewMoonDay(k + i));
    } while (arc != last && i < 14);
    return i - 1;
  }

  static int _getSunLongitude(int jdn) {
    final t = (jdn - 2451545.5) / 36525;
    final t2 = t * t;
    final dr = 3.14159265358979323846 / 180;
    final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.9146 - 0.004817 * t - 0.000014 * t2) * _sin(m, dr);
    dl = dl + (0.019993 - 0.000101 * t) * _sin(2 * m, dr) + 0.00029 * _sin(3 * m, dr);
    var l = l0 + dl;
    l = l * dr;
    l = l - 3.14159265358979323846 * 2 * (l / (3.14159265358979323846 * 2)).floor();
    return (l / 3.14159265358979323846 * 6).floor();
  }

  static double _sin(double deg, double dr) {
    return _sinRad(deg * dr);
  }

  static double _sinRad(double rad) {
    // Taylor series approximation or use dart:math
    return _dartSin(rad);
  }

  static double _dartSin(double x) {
    // Normalize to [-pi, pi]
    const pi = 3.14159265358979323846;
    const twoPi = 2 * pi;
    x = x % twoPi;
    if (x > pi) x -= twoPi;
    if (x < -pi) x += twoPi;

    // Taylor series for sin(x)
    double result = 0;
    double term = x;
    for (int n = 1; n <= 15; n++) {
      result += term;
      term *= -x * x / ((2 * n) * (2 * n + 1));
    }
    return result;
  }

  static int _intPart(double x) {
    return x.floor();
  }
}

class DateTimeService {
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  static String formatToIst(String? isoTimestamp) {
    if (isoTimestamp == null || isoTimestamp.trim().isEmpty) {
      return 'Just now';
    }

    try {
      final utcDateTime = DateTime.parse(isoTimestamp);
      final istDateTime = utcDateTime.add(_istOffset);

      const monthsShort = [
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

      final day = istDateTime.day.toString().padLeft(2, '0');
      final month = monthsShort[istDateTime.month - 1];
      final hour = istDateTime.hour % 12 == 0 ? 12 : istDateTime.hour % 12;
      final minute = istDateTime.minute.toString().padLeft(2, '0');
      final period = istDateTime.hour >= 12 ? 'PM' : 'AM';

      return '$day $month, ${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return isoTimestamp.length > 10
          ? isoTimestamp.substring(0, 10)
          : isoTimestamp;
    }
  }

  static String formatDateOnlyIst(String? isoTimestamp) {
    if (isoTimestamp == null || isoTimestamp.trim().isEmpty) {
      return 'N/A';
    }

    try {
      final utcDateTime = DateTime.parse(isoTimestamp);
      final istDateTime = utcDateTime.add(_istOffset);

      const monthsShort = [
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

      final day = istDateTime.day.toString().padLeft(2, '0');
      final month = monthsShort[istDateTime.month - 1];
      final year = istDateTime.year;

      return '$day $month $year';
    } catch (_) {
      return isoTimestamp.length > 10
          ? isoTimestamp.substring(0, 10)
          : isoTimestamp;
    }
  }
}

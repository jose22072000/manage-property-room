import 'package:intl/intl.dart';

final _dateFormatter = DateFormat('d MMM yyyy', 'es');
final _timeFormatter = DateFormat('HH:mm', 'es');
final _dayFormatter = DateFormat('EEEE d MMM', 'es');

String formatDate(DateTime dt) => _dateFormatter.format(dt);
String formatTime(DateTime dt) => _timeFormatter.format(dt);
String formatDay(DateTime dt) => _dayFormatter.format(dt);

/// Returns human-friendly relative label: "Hoy", "Mañana", "Ayer", or formatted date.
String formatRelativeDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = target.difference(today).inDays;

  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Mañana';
  if (diff == -1) return 'Ayer';
  return formatDate(dt);
}

/// Short timestamp for done chips: "06/05 20:16"
String formatDoneAt(DateTime dt) {
  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$day/$month $hour:$min';
}
/// Whether a card is considered urgent based on checkinDate.
bool isCheckinTomorrow(DateTime? checkinDate) {
  if (checkinDate == null) return false;
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return checkinDate.year == tomorrow.year &&
      checkinDate.month == tomorrow.month &&
      checkinDate.day == tomorrow.day;
}

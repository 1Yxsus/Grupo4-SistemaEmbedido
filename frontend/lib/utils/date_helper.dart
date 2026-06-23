import 'package:flutter/foundation.dart';

/// Convierte una cadena de texto de fecha/hora a un objeto [DateTime].
/// Soporta formatos estándar ISO (con '-') y formatos localizados 'DD/MM/YYYY HH:mm:ss'.
DateTime? parseDateTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return null;
  try {
    if (dateStr.contains('-')) {
      return DateTime.parse(dateStr);
    }

    final parts = dateStr.split(' ');
    if (parts.length < 2) return null;

    final dateParts = parts[0].split('/');
    final timeParts = parts[1].split(':');
    if (dateParts.length != 3 || timeParts.length < 2) return null;

    int day = int.parse(dateParts[0]);
    int month = int.parse(dateParts[1]);
    int year = int.parse(dateParts[2]);
    if (year < 100) year += 2000;

    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    int second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

    return DateTime(year, month, day, hour, minute, second);
  } catch (e) {
    debugPrint("[parseDateTime] Error al parsear fecha '$dateStr': $e");
    return null;
  }
}

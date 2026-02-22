extension MapX on Map<String, dynamic> {
  int? parseInt(String key) {
    final v = this[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double? parseDouble(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool? parseBool(String key) {
    final v = this[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'да' || s == 'yes';
    }
    return null;
  }

  DateTime? parseDateTime(String key) {
    final v = this[key];
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  DateTime? parseDateOnly(String key) {
    final dt = parseDateTime(key);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }
}

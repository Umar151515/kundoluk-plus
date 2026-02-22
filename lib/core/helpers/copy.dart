import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Copy {
  static Future<void> text(
    BuildContext context,
    String value, {
    String? label,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label != null ? '$label скопировано' : 'Скопировано')),
    );
  }
}

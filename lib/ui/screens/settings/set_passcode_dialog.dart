import 'package:flutter/material.dart';

class SetPasscodeDialog extends StatefulWidget {
  const SetPasscodeDialog({super.key});

  @override
  State<SetPasscodeDialog> createState() => _SetPasscodeDialogState();
}

class _SetPasscodeDialogState extends State<SetPasscodeDialog> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  void _ok() {
    final a = _p1.text.trim();
    final b = _p2.text.trim();
    if (a.isEmpty || b.isEmpty) {
      setState(() => _error = 'Заполни оба поля');
      return;
    }
    if (a.length < 4) {
      setState(() => _error = 'Минимум 4 символа');
      return;
    }
    if (a != b) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Задать пароль приложения'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _p1,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Пароль / PIN',
                prefixIcon: const Icon(Icons.password_rounded),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _p2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Повтори',
                prefixIcon: Icon(Icons.password_rounded),
              ),
              onSubmitted: (_) => _ok(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _ok, child: const Text('Сохранить')),
      ],
    );
  }
}

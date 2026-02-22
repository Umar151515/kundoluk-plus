import 'package:flutter/material.dart';

class LoginDialogResult {
  final String username;
  final String password;
  final bool makeActive;
  LoginDialogResult(this.username, this.password, this.makeActive);
}

class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _makeActive = true;

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить аккаунт'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _u,
              decoration: const InputDecoration(
                labelText: 'Логин',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _p,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              value: _makeActive,
              onChanged: (v) => setState(() => _makeActive = v),
              title: const Text('Сделать активным'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final u = _u.text.trim();
            final p = _p.text;
            if (u.isEmpty || p.isEmpty) return;
            Navigator.pop(context, LoginDialogResult(u, p, _makeActive));
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

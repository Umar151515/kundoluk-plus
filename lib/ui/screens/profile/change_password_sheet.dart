import 'package:flutter/material.dart';

import '../../../core/helpers/copy.dart';
import '../../../core/network/api_error_kind.dart';
import '../../../core/network/api_failure.dart';
import '../../../data/api/kundoluk_api.dart';
import '../../../data/stores/auth_store.dart';
import '../../widgets/error_card.dart';

class ChangePasswordSheet extends StatefulWidget {
  final KundolukApi api;
  final AuthStore auth;
  const ChangePasswordSheet({super.key, required this.api, required this.auth});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  bool _loading = false;
  ApiFailure? _failure;
  String? _success;

  @override
  void dispose() {
    _current.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _failure = null;
      _success = null;
      _loading = true;
    });

    final curr = _current.text;
    final n1 = _new1.text.trim();
    final n2 = _new2.text.trim();

    if (curr.trim().isEmpty) {
      setState(() {
        _failure = ApiFailure(
          kind: ApiErrorKind.validation,
          title: 'Нужен текущий пароль',
          message: 'Введи текущий пароль.',
        );
        _loading = false;
      });
      return;
    }

    if (n1.isEmpty) {
      setState(() {
        _failure = ApiFailure(
          kind: ApiErrorKind.validation,
          title: 'Новый пароль пустой',
          message: 'Введи новый пароль.',
        );
        _loading = false;
      });
      return;
    }

    if (n1 != n2) {
      setState(() {
        _failure = ApiFailure(
          kind: ApiErrorKind.validation,
          title: 'Пароли не совпадают',
          message: 'Повтори новый пароль точно так же.',
        );
        _loading = false;
      });
      return;
    }

    final resp = await widget.api.changePassword(currentPassword: curr, newPassword: n1);

    if (!mounted) return;

    if (!resp.isSuccess) {
      setState(() {
        _failure = resp.failure;
        _loading = false;
      });
      return;
    }

    setState(() {
      _success = resp.message.isNotEmpty ? resp.message : 'Пароль изменён';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.password_rounded),
                  title: Text('Смена пароля'),
                  subtitle: Text('Текущий пароль нужно вводить всегда'),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 10),
                TextField(
                  controller: _current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Текущий пароль',
                    prefixIcon: Icon(Icons.lock_rounded),
                    helperText: 'Обязательно',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _new1,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Новый пароль',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _new2,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Повтори новый пароль',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                if (_failure != null)
                  ErrorCard(
                    failure: _failure!,
                    onCopy: () => Copy.text(context, _failure.toString(), label: 'Ошибка'),
                  ),
                if (_success != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _success!,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        child: const Text('Закрыть'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: const Text('Сменить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

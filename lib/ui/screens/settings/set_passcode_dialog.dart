import 'package:flutter/material.dart';

import '../../widgets/pin_pad.dart';

class SetPasscodeDialog extends StatefulWidget {
  const SetPasscodeDialog({super.key});

  @override
  State<SetPasscodeDialog> createState() => _SetPasscodeDialogState();
}

class _SetPasscodeDialogState extends State<SetPasscodeDialog> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _error;
  bool _editingFirst = true;

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
      setState(() => _error = 'Минимум 4 цифры');
      return;
    }
    if (!_isDigitsOnly(a) || !_isDigitsOnly(b)) {
      setState(() => _error = 'PIN-код должен состоять только из цифр');
      return;
    }
    if (a != b) {
      setState(() => _error = 'PIN-коды не совпадают');
      return;
    }
    Navigator.pop(context, a);
  }

  bool _isDigitsOnly(String value) => RegExp(r'^\d+$').hasMatch(value);

  TextEditingController get _activeController => _editingFirst ? _p1 : _p2;

  void _appendDigit(String digit) {
    final controller = _activeController;
    if (controller.text.length >= 8) return;
    setState(() {
      _error = null;
      controller.text += digit;
    });
  }

  void _backspace() {
    final controller = _activeController;
    if (controller.text.isEmpty) return;
    setState(() {
      _error = null;
      controller.text = controller.text.substring(0, controller.text.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Задать PIN-код приложения'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PinEntryField(
              label: 'PIN-код',
              controller: _p1,
              selected: _editingFirst,
              errorText: _error,
              onTap: () => setState(() => _editingFirst = true),
            ),
            const SizedBox(height: 10),
            _PinEntryField(
              label: 'Повтори PIN-код',
              controller: _p2,
              selected: !_editingFirst,
              onTap: () => setState(() => _editingFirst = false),
            ),
            const SizedBox(height: 14),
            PinPad(
              value: _activeController.text,
              onDigit: _appendDigit,
              onBackspace: _backspace,
              actionIcon: Icons.check_rounded,
              onAction: _ok,
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
          onPressed: _ok,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _PinEntryField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool selected;
  final String? errorText;
  final VoidCallback onTap;

  const _PinEntryField({
    required this.label,
    required this.controller,
    required this.selected,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          readOnly: true,
          enableInteractiveSelection: false,
          obscureText: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.pin_rounded,
            ),
            errorText: errorText,
            filled: true,
            fillColor: selected
                ? cs.primaryContainer.withValues(alpha: 0.35)
                : null,
          ),
        ),
      ),
    );
  }
}

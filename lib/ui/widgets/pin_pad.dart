import 'package:flutter/material.dart';

class PinPad extends StatelessWidget {
  final String value;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onAction;
  final IconData actionIcon;

  const PinPad({
    super.key,
    required this.value,
    required this.onDigit,
    required this.onBackspace,
    required this.onAction,
    required this.actionIcon,
  });

  static const _rowSpacing = 10.0;
  static const _columnSpacing = 10.0;
  static const _keyWidth = 72.0;
  static const _keyHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(
          [
            _PinKey(label: '1', onTap: () => onDigit('1')),
            _PinKey(label: '2', onTap: () => onDigit('2')),
            _PinKey(label: '3', onTap: () => onDigit('3')),
          ],
        ),
        const SizedBox(height: _rowSpacing),
        _buildRow(
          [
            _PinKey(label: '4', onTap: () => onDigit('4')),
            _PinKey(label: '5', onTap: () => onDigit('5')),
            _PinKey(label: '6', onTap: () => onDigit('6')),
          ],
        ),
        const SizedBox(height: _rowSpacing),
        _buildRow(
          [
            _PinKey(label: '7', onTap: () => onDigit('7')),
            _PinKey(label: '8', onTap: () => onDigit('8')),
            _PinKey(label: '9', onTap: () => onDigit('9')),
          ],
        ),
        const SizedBox(height: _rowSpacing),
        _buildRow(
          [
            _PinKey(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
            ),
            _PinKey(
              label: '0',
              onTap: () => onDigit('0'),
            ),
            _PinKey(
              icon: actionIcon,
              onTap: onAction,
              filled: value.isNotEmpty,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        children[0],
        const SizedBox(width: _columnSpacing),
        children[1],
        const SizedBox(width: _columnSpacing),
        children[2],
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool filled;

  const _PinKey({
    this.label,
    this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: PinPad._keyWidth,
      height: PinPad._keyHeight,
      child: Material(
        color: filled ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Icon(icon),
          ),
        ),
      ),
    );
  }
}

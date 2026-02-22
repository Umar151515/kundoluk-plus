import 'package:flutter/material.dart';

class AppScaffoldMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const AppScaffoldMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

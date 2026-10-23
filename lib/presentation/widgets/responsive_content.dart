import 'package:flutter/material.dart';

class ResponsiveContent extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ResponsiveContent({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

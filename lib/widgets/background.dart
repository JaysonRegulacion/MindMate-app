import 'package:flutter/material.dart';

class Background extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;

  const Background({
    super.key,
    required this.child,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

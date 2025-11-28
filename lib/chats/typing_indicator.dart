import 'package:flutter/material.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min, // 👈 prevents overflow
        children: [
          const CircleAvatar(
            radius: 12,
            child: Text("🌱", style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min, // 👈 keeps dots compact
            children: const [
              Dot(),
              SizedBox(width: 4),
              Dot(delay: 200),
              SizedBox(width: 4),
              Dot(delay: 400),
            ],
          ),
        ],
      ),
    );
  }
}

class Dot extends StatefulWidget {
  final int delay;
  const Dot({super.key, this.delay = 0});

  @override
  State<Dot> createState() => _DotState();
}

class _DotState extends State<Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
          ..repeat(reverse: true);
    _animation =
        Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () => _controller.forward());
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

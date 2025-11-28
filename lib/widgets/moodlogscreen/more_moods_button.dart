import 'package:flutter/material.dart';

class MoreMoodsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const MoreMoodsButton({
    super.key,
    required this.onPressed,
    this.label = "More moods",
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30), // Softer pill
        ),
        backgroundColor: const Color(0xFFE0F7F5), // Gentle pastel
        foregroundColor: const Color(0xFF007F7B), // Darker teal for readability
      ),
      icon: const Icon(Icons.add_reaction_rounded), // Emotionally friendly icon
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

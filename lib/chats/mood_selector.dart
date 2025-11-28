import 'package:flutter/material.dart';

class MoodSelector extends StatelessWidget {
  final Function(String) onMoodSelected;

  const MoodSelector({super.key, required this.onMoodSelected});

  Widget _moodButton(String emoji, String label) {
    return GestureDetector(
      onTap: () => onMoodSelected(label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _moodButton("😊", "Happy"),
            _moodButton("😴", "Tired"),
            _moodButton("😔", "Sad"),
            _moodButton("😰", "Anxious"),
            _moodButton("😡", "Angry"),
          ],
        ),
      ),
    );
  }
}

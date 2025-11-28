import 'package:flutter/material.dart';

class MoodLegend extends StatelessWidget {
  final Map<String, dynamic> moodLegend;

  const MoodLegend({super.key, required this.moodLegend});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: moodLegend.entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: entry.value['color'],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              "${entry.value['emoji']} ${entry.key}",
              style: const TextStyle(fontSize: 14),
            ),
          ],
        );
      }).toList(),
    );
  }
}

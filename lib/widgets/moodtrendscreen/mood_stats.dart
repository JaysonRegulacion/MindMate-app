import 'package:flutter/material.dart';

class QuickMoodStats extends StatelessWidget {
  final String mostFrequentMoodEmoji;
  final String mostFrequentMoodName;
  final String trendMessage; // Example: "Your overall mood is improving"

  const QuickMoodStats({
    super.key,
    required this.mostFrequentMoodEmoji,
    required this.mostFrequentMoodName,
    required this.trendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Mood Stats",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Most frequent mood: $mostFrequentMoodEmoji $mostFrequentMoodName",
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            trendMessage,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

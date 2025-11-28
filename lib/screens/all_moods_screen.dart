import 'package:flutter/material.dart';

class AllMoodsScreen extends StatelessWidget {
  const AllMoodsScreen({super.key});

  final Map<String, List<String>> moodCategories = const {
    "Happy": ["Excited", "Joyful", "Content", "Loved", "Proud", "Grateful", "Motivated", "Delighted"],
    "Tired": ["Sleepy", "Drained", "Exhausted", "Unfocused", "Lazy", "Overwhelmed", "Unmotivated"],
    "Anxious": ["Worried", "Stressed", "Nervous", "Panicked", "Tense", "Insecure", "Overthinking"],
    "Angry": ["Annoyed", "Frustrated", "Irritated", "Bitter", "Furious", "Upset", "Resentful"],
    "Sad": ["Lonely", "Heartbroken", "Disappointed", "Gloomy", "Hopeless", "Depressed", "Empty"],
  };

  final Map<String, Color> moodColors = const {
    "Happy": Colors.yellow,
    "Tired": Colors.lightBlue,
    "Anxious": Colors.orange,
    "Angry": Colors.red,
    "Sad": Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Mood"),
        backgroundColor: const Color(0xFF50C9C3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: moodCategories.entries.map((entry) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: moodColors[entry.key],
                child: Text(entry.key[0]), // First letter of category
              ),
              title: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((subMood) {
                      return ActionChip(
                        label: Text(subMood),
                        backgroundColor: moodColors[entry.key]?.withOpacity(0.2),
                        onPressed: () {
                          Navigator.pop(context, subMood);
                        },
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

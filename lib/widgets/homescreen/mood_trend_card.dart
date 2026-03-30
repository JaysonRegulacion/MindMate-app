import 'package:flutter/material.dart';
import 'package:mindmate/screens/mood_trend_screen.dart';

class MoodTrendCard extends StatefulWidget {
  final List<Map<String, dynamic>> moods;
  final int selectedTrendIndex; // 0 = today, 1 = week
  final bool isLoading;
  final ValueChanged<int> onTrendChanged;
  final bool isOffline;
  final VoidCallback onOfflineTap;

  const MoodTrendCard({
    super.key,
    required this.moods,
    this.selectedTrendIndex = 0,
    required this.isLoading,
    required this.onTrendChanged,
    required this.isOffline,
    required this.onOfflineTap,
  });

  @override
  State<MoodTrendCard> createState() => _MoodTrendCardState();
}

class _MoodTrendCardState extends State<MoodTrendCard> {
  int trendIndex = 0;
  Set<String> expandedMoods = {};

  @override
  void initState() {
    super.initState();
    trendIndex = widget.selectedTrendIndex;
  }

  @override
  void didUpdateWidget(MoodTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTrendIndex != widget.selectedTrendIndex) {
      trendIndex = widget.selectedTrendIndex;
    }
  }

  // ---------------- FILTER ----------------

  List<Map<String, dynamic>> _applyCardFilter() {
    final now = DateTime.now();
    if (trendIndex == 0) {
      return widget.moods.where((m) {
        final d = DateTime.tryParse(m['created_at']) ?? DateTime(1970);
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();
    } else {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return widget.moods.where((m) {
        final d = DateTime.tryParse(m['created_at']) ?? DateTime(1970);
        return d.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
            d.isBefore(weekEnd.add(const Duration(days: 1)));
      }).toList();
    }
  }

  // ---------------- COUNTS ----------------

  Map<String, int> _getMoodCounts(List<Map<String, dynamic>> moods) {
    final counts = <String, int>{};
    final mainMoods = [
      'angry',
      'disgust',
      'fear',
      'happy',
      'neutral',
      'sad',
      'surprise',
    ];

    for (final mood in mainMoods) {
      counts[mood] = 0;
    }

    for (final m in moods) {
      final mood = (m['main_mood'] ?? '').toString().toLowerCase().trim();
      if (counts.containsKey(mood)) {
        counts[mood] = counts[mood]! + 1;
      }
    }
    return counts;
  }

  Map<String, Map<String, int>> _getSubMoodCounts(List<Map<String, dynamic>> moods) {
    final map = <String, Map<String, int>>{};
    for (final m in moods) {
      final main = (m['main_mood'] ?? '').toString().toLowerCase();
      final sub = (m['sub_mood'] ?? '').toString().toLowerCase();
      if (main.isEmpty) continue;
      map.putIfAbsent(main, () => {});
      if (sub.isNotEmpty) {
        map[main]![sub] = (map[main]![sub] ?? 0) + 1;
      }
    }
    return map;
  }

  // ---------------- UI HELPERS ----------------

  String moodEmoji(String mood) {
    switch (mood) {
      case 'angry':
        return '🤬';
      case 'disgust':
        return '🤢';
      case 'fear':
        return '😨';
      case 'happy':
        return '😀';
      case 'neutral':
        return '😐';
      case 'sad':
        return '😭';
      case 'surprise':
        return '😲';
      default:
        return '😐';
    }
  }

  String moodLabel(String mood) => mood.capitalize();

  LinearGradient moodGradient(String mood) {
    switch (mood) {
      case 'angry':
        return const LinearGradient(colors: [Colors.red, Colors.redAccent]);
      case 'disgust':
        return const LinearGradient(colors: [Colors.green, Colors.lightGreen]);
      case 'fear':
        return const LinearGradient(colors: [Colors.deepPurple, Colors.purpleAccent]);
      case 'happy':
        return const LinearGradient(colors: [Colors.yellow, Colors.orangeAccent]);
      case 'neutral':
        return const LinearGradient(colors: [Colors.grey, Colors.blueGrey]);
      case 'sad':
        return const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]);
      case 'surprise':
        return const LinearGradient(colors: [Colors.pink, Colors.pinkAccent]);
      default:
        return const LinearGradient(colors: [Colors.grey, Colors.white24]);
    }
  }

  String _generateInsight(Map<String, int> moodCounts, int total) {
    if (total == 0) {
      return "No moods logged yet. Start tracking to see insights!";
    }
    final sorted = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = sorted.first;
    final percent = ((top.value / total) * 100).round();

    return "You mostly felt ${moodLabel(top.key)} ${moodEmoji(top.key)} this period ($percent%).";
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    final filtered = _applyCardFilter();
    final mainCounts = _getMoodCounts(filtered);
    final subCounts = _getSubMoodCounts(filtered);

    final sortedMain = mainCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int maxCount =
        sortedMain.isNotEmpty && sortedMain.first.value > 0
            ? sortedMain.first.value
            : 1;

    final int totalMoods = filtered.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mood Trend",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MoodTrendScreen())),
                  child: const Row(
                    children: [
                      Text("View full",
                          style: TextStyle(color: Colors.white70)),
                      Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTrendToggle(context),
            const SizedBox(height: 12),

            if (!widget.isLoading && filtered.isNotEmpty)
              ...sortedMain.map((entry) {
                final mainMood = entry.key;
                final count = entry.value;

                final widthFactor =
                    (count / maxCount).clamp(0.0, 1.0);
                final percent =
                    totalMoods > 0 ? ((count / totalMoods) * 100).round() : 0;

                final isExpanded = expandedMoods.contains(mainMood);

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isExpanded
                              ? expandedMoods.remove(mainMood)
                              : expandedMoods.add(mainMood);
                        });
                      },
                      child: Row(
                        children: [
                          Text(moodEmoji(mainMood)),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 70,
                            child: Text(moodLabel(mainMood),
                                style: const TextStyle(color: Colors.white70)),
                          ),
                          Expanded(
                            child: Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: widthFactor,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: moodGradient(mainMood),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text("$count ($percent%)",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Icon(isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                              color: Colors.white70),
                        ],
                      ),
                    ),

                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, top: 6),
                        child: Wrap(
                          spacing: 6,
                          children: (subCounts[mainMood] ?? {}).entries.map((s) {
                            return Chip(
                              label: Text("${s.key.capitalize()} (${s.value})",
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.white10,
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                );
              }),

            if (!widget.isLoading && filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _generateInsight(mainCounts, totalMoods),
                  style: const TextStyle(
                      color: Colors.white, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),

            if (!widget.isLoading && filtered.isEmpty)
              const Text("Log your first mood 😊",
                  style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ---------------- TOGGLE ----------------

  Widget _buildTrendToggle(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => trendIndex = 0);
              widget.onTrendChanged(0);
            },
            child: Center(
              child: Text("Today",
                  style: TextStyle(
                      color: trendIndex == 0
                          ? Colors.white
                          : Colors.white70)),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => trendIndex = 1);
              widget.onTrendChanged(1);
            },
            child: Center(
              child: Text("This Week",
                  style: TextStyle(
                      color: trendIndex == 1
                          ? Colors.white
                          : Colors.white70)),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- EXTENSION ----------------

extension StringCasing on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

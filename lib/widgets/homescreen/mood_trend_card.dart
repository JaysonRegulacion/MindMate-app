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
  _MoodTrendCardState createState() => _MoodTrendCardState();
}

class _MoodTrendCardState extends State<MoodTrendCard> {
  int trendIndex = 0;
  Map<String, int> previousCounts = {};
  Set<String> expandedMoods = {}; // Tracks which main moods are expanded

  @override
  void initState() {
    super.initState();
    trendIndex = widget.selectedTrendIndex;
  }

  @override
  void didUpdateWidget(MoodTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    previousCounts = _getMoodCounts(oldWidget.moods);

    if (oldWidget.selectedTrendIndex != widget.selectedTrendIndex) {
      setState(() => trendIndex = widget.selectedTrendIndex);
    }

    if (oldWidget.isOffline != widget.isOffline) {
      setState(() {});
    }
  }

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

  Map<String, int> _getMoodCounts(List<Map<String, dynamic>> moods) {
    final counts = <String, int>{};
    final mainMoods = ['happy', 'tired', 'anxious', 'sad', 'angry'];
    for (var mood in mainMoods) counts[mood] = 0;
    for (final m in moods) {
      final mood = (m['main_mood'] ?? '').toString().trim().toLowerCase();
      if (counts.containsKey(mood)) counts[mood] = counts[mood]! + 1;
    }
    return counts;
  }

  Map<String, Map<String, int>> _getSubMoodCounts(List<Map<String, dynamic>> moods) {
    final map = <String, Map<String, int>>{};
    for (final m in moods) {
      final main = (m['main_mood'] ?? '').toString().toLowerCase();
      final sub = (m['sub_mood'] ?? '').toString().toLowerCase();
      if (main.isEmpty) continue;
      if (!map.containsKey(main)) map[main] = {};
      if (sub.isNotEmpty) {
        map[main]![sub] = (map[main]![sub] ?? 0) + 1;
      }
    }
    return map;
  }

  String moodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'tired':
        return '😴';
      case 'anxious':
        return '😰';
      case 'angry':
        return '😡';
      case 'sad':
        return '😢';
      default:
        return '😐';
    }
  }

  String moodLabel(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return 'Happy';
      case 'tired':
        return 'Tired';
      case 'anxious':
        return 'Anxious';
      case 'angry':
        return 'Angry';
      case 'sad':
        return 'Sad';
      default:
        return mood.capitalize();
    }
  }

  LinearGradient moodGradient(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return const LinearGradient(colors: [Colors.green, Colors.greenAccent]);
      case 'tired':
        return const LinearGradient(colors: [Colors.blueGrey, Colors.grey]);
      case 'anxious':
        return const LinearGradient(colors: [Colors.orange, Colors.deepOrangeAccent]);
      case 'angry':
        return const LinearGradient(colors: [Colors.red, Colors.redAccent]);
      case 'sad':
        return const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]);
      default:
        return const LinearGradient(colors: [Colors.grey, Colors.white24]);
    }
  }

  String _generateInsight(Map<String, int> moodCounts, int totalMoods) {
    if (moodCounts.isEmpty) return "No moods logged yet. Start tracking to see insights!";
    final sorted = moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topMood = sorted.first;
    final percent = ((topMood.value / totalMoods) * 100).round();
    if (percent >= 50) {
      return "You mostly felt ${moodLabel(topMood.key)} ${moodEmoji(topMood.key)} this period ($percent%).";
    } else if (sorted.length > 1) {
      final secondMood = sorted[1];
      return "Your moods were mixed. ${moodLabel(topMood.key)} ${moodEmoji(topMood.key)} was most common, followed by ${moodLabel(secondMood.key)} ${moodEmoji(secondMood.key)}.";
    } else {
      return "Your mood entries are balanced. Keep logging to discover patterns!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredMoods = _applyCardFilter();
    final mainCounts = _getMoodCounts(filteredMoods);
    final subCounts = _getSubMoodCounts(filteredMoods);
    final sortedMain = mainCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final int maxCount = sortedMain.isNotEmpty ? sortedMain.first.value : 1;
    final int totalMoods = filteredMoods.length;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: Colors.white.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Mood Trend",
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                InkWell(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const MoodTrendScreen())),
                  child: Row(
                    children: const [
                      Text("View full", style: TextStyle(color: Colors.white70)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTrendToggle(context),
            const SizedBox(height: 12),
            if (!widget.isLoading && filteredMoods.isNotEmpty)
              Column(
                children: [
                  ...sortedMain.map((entry) {
                    final mainMood = entry.key;
                    final count = entry.value;
                    final widthFactor = count / maxCount;
                    final animatedPercent = ((count / totalMoods) * 100).round();
                    final isExpanded = expandedMoods.contains(mainMood);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                expandedMoods.remove(mainMood);
                              } else {
                                expandedMoods.add(mainMood);
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Text(moodEmoji(mainMood), style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 60,
                                child: Text(moodLabel(mainMood),
                                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white12,
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: widthFactor,
                                    child: Container(
                                      decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          gradient: moodGradient(mainMood)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  "$count ($animatedPercent%)",
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: Container(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: (subCounts[mainMood] ?? {}).entries.map((sub) {
                                return Chip(
                                  label: Text(
                                    "${moodLabel(sub.key)} (${sub.value})",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.white10,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ),
                          crossFadeState: isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    );
                  }).toList(),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _generateInsight(mainCounts, totalMoods),
                      style: const TextStyle(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            else if (!widget.isLoading)
              const Text("Log your first mood 😊",
                  style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendToggle(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: trendIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Container(
              width: (MediaQuery.of(context).size.width - 64) / 2,
              decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          Row(
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
                            color: trendIndex == 0 ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold)),
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
                            color: trendIndex == 1 ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension StringCasing on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

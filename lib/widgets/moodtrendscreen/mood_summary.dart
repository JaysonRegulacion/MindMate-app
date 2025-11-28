import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

enum MoodCategory { positive, neutral, negative }

MoodCategory getCategory(int value) {
  if (value >= 5) return MoodCategory.positive;
  if (value == 4) return MoodCategory.neutral;
  return MoodCategory.negative;
}

extension IterableNumExt on Iterable<num> {
  double get average => isEmpty ? 0 : sum / length;
  num get sum => fold(0, (a, b) => a + b);
}

T getValue<T>(Map<String, dynamic> map, String key, T defaultValue) {
  final value = map[key];
  return value is T ? value : defaultValue;
}

class MoodSummary {
  final List<Map<String, dynamic>> moods;

  late final List<Map<String, dynamic>> parsedMoods;

  late final int total;
  late final int positiveCount;
  late final int neutralCount;
  late final int negativeCount;

  late final double positivePct;
  late final double neutralPct;
  late final double negativePct;

  MoodSummary(this.moods) {
    parsedMoods = moods.map((m) {
      final date =
          DateTime.tryParse(getValue<String>(m, 'created_at', '')) ?? DateTime.now();
      final value = getValue<int>(m, 'value', 0);
      return {...m, 'parsed_date': date, 'value': value};
    }).toList();

    total = parsedMoods.length;
    positiveCount = parsedMoods.where((m) => getValue<int>(m, 'value', 0) >= 5).length;
    neutralCount = parsedMoods.where((m) => getValue<int>(m, 'value', 0) == 4).length;
    negativeCount = parsedMoods.where((m) => getValue<int>(m, 'value', 0) <= 3).length;

    positivePct = total > 0 ? positiveCount / total : 0;
    neutralPct = total > 0 ? neutralCount / total : 0;
    negativePct = total > 0 ? negativeCount / total : 0;
  }

  bool get isEmpty => parsedMoods.isEmpty;

  Map<String, dynamic> get dominantMood {
    if (parsedMoods.isEmpty) return {};

    final counts = <String, int>{};
    for (var m in parsedMoods) {
      final mood = getValue<String>(m, 'main_mood', 'mood');
      counts[mood] = (counts[mood] ?? 0) + 1;
    }

    final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return parsedMoods.firstWhere(
        (m) => getValue<String>(m, 'main_mood', '') == dominant);
  }

  String get dominantCategory {
    if (positiveCount >= neutralCount && positiveCount >= negativeCount) return "Positive";
    if (neutralCount >= positiveCount && neutralCount >= negativeCount) return "Neutral";
    return "Negative";
  }

  Map<String, int> getTimeGroupCount({int threshold = 4}) {
    final positiveMoods = parsedMoods.where((m) => getValue<int>(m, 'value', 0) >= threshold);
    return positiveMoods
        .groupListsBy((m) =>
            _getTimeOfDayLabel(getValue<DateTime>(m, 'parsed_date', DateTime.now())))
        .map((k, v) => MapEntry(k, v.length));
  }

  String get mostFrequentTime {
    if (parsedMoods.isEmpty) return '';
    final counts = getTimeGroupCount();
    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Map<String, dynamic> get highestMood {
    if (parsedMoods.isEmpty) return {};
    return parsedMoods.reduce((a, b) =>
        (getValue<int>(a, 'value', 0) > getValue<int>(b, 'value', 0)) ? a : b);
  }

  Map<String, dynamic> get lowestMood {
    if (parsedMoods.isEmpty) return {};
    return parsedMoods.reduce((a, b) =>
        (getValue<int>(a, 'value', 0) < getValue<int>(b, 'value', 0)) ? a : b);
  }

  String get trend {
    if (parsedMoods.length < 2) return 'stable';
    final firstHalf = parsedMoods
        .take(parsedMoods.length ~/ 2)
        .map((m) => getValue<int>(m, 'value', 0));
    final secondHalf = parsedMoods
        .skip(parsedMoods.length ~/ 2)
        .map((m) => getValue<int>(m, 'value', 0));

    final avgFirst = firstHalf.average;
    final avgLast = secondHalf.average;

    if (avgFirst < avgLast) return 'up';
    if (avgFirst > avgLast) return 'down';
    return 'stable';
  }

  String formatFor(DateTime time, String filter) =>
      filter == "Today" ? DateFormat('HH:mm').format(time) : DateFormat('EEEE').format(time);

  String _getTimeOfDayLabel(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return "Mornings";
    if (hour >= 12 && hour < 17) return "Afternoons";
    if (hour >= 17 && hour < 22) return "Evenings";
    return "Late Nights";
  }

  String suggestion(String Function(String) moodEmoji) {
    if (isEmpty) return "No mood data available for suggestions.";

    getValue<String>(highestMood, 'main_mood', 'mood');
    final dominant = getValue<String>(dominantMood, 'main_mood', 'mood');
    final activeTime = mostFrequentTime.isNotEmpty ? mostFrequentTime : "your usual time";

    switch (trend) {
      case 'up':
        return "💡 Great! Your mood is trending upward. Keep doing activities that make you feel ${moodEmoji(dominant)} $dominant, especially during $activeTime.";
      case 'down':
        return "💡 Your mood seems to be trending downward. Try relaxing, journaling, or connecting with friends to improve your $dominant mood.";
      default:
        return "💡 Your mood is stable. Maintain habits that support ${moodEmoji(dominant)} $dominant and stay positive during $activeTime.";
    }
  }
}

class MoodSummaryCard extends StatefulWidget {
  final MoodSummary summary;
  final String filter;
  final String Function(String) moodEmoji;

  const MoodSummaryCard({
    super.key,
    required this.summary,
    required this.filter,
    required this.moodEmoji,
  });

  @override
  _MoodSummaryCardState createState() => _MoodSummaryCardState();
}

class _MoodSummaryCardState extends State<MoodSummaryCard> {
  final Set<String> expandedMoods = {};

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    if (summary.isEmpty) return const SizedBox.shrink();

    final bestTime = summary.formatFor(
        getValue<DateTime>(summary.highestMood, 'parsed_date', DateTime.now()),
        widget.filter);
    final worstTime = summary.formatFor(
        getValue<DateTime>(summary.lowestMood, 'parsed_date', DateTime.now()),
        widget.filter);

    final trendIconColor = {
      "up": Icons.trending_up,
      "down": Icons.trending_down,
      "stable": Icons.trending_flat
    };

    final trendColor = {
      "up": Colors.green,
      "down": Colors.red,
      "stable": Colors.grey
    };

    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(),
            const SizedBox(height: 16),
            _buildTrendRow(trendIconColor[summary.trend]!, trendColor[summary.trend]!),
            const SizedBox(height: 16),
            _buildMoodCards(bestTime, worstTime),
            const SizedBox(height: 16),
            _buildExpandableMoodBreakdown(),
            const SizedBox(height: 16),
            _buildSuggestion(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() => Row(
        children: const [
          Icon(Icons.insights, color: Colors.blue),
          SizedBox(width: 8),
          Text("Mood Summary",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _buildTrendRow(IconData icon, Color color) => Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Overall, your mood ${_formatTrend(widget.summary.trend)}.",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      );

  String _formatTrend(String trend) =>
      trend == 'up' ? 'trended upward' : trend == 'down' ? 'trended downward' : 'remained stable';

  Widget _buildMoodCards(String bestTime, String worstTime) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildMoodCard(
                title: "Dominant",
                emoji: widget.moodEmoji(getValue(widget.summary.dominantMood, 'main_mood', '')),
                value: getValue(widget.summary.dominantMood, 'main_mood', ''),
                color: Colors.green.shade200),
            _buildMoodCard(
                title: "Peak",
                emoji: widget.moodEmoji(getValue(widget.summary.highestMood, 'main_mood', '')),
                value: "${getValue(widget.summary.highestMood, 'main_mood', '')} at $bestTime",
                color: Colors.blue.shade200),
            _buildMoodCard(
                title: "Lowest",
                emoji: widget.moodEmoji(getValue(widget.summary.lowestMood, 'main_mood', '')),
                value: "${getValue(widget.summary.lowestMood, 'main_mood', '')} at $worstTime",
                color: Colors.red.shade200),
            _buildMoodCard(
                title: "Active Time",
                emoji: "🕒",
                value: widget.summary.mostFrequentTime,
                color: Colors.orange.shade200),
          ],
        ),
      );

  Widget _buildMoodCard(
          {required String title,
          required String emoji,
          required String value,
          required Color color}) =>
      Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(value, textAlign: TextAlign.center),
          ],
        ),
      );

  /// 🆕 Expandable main + sub mood breakdown
  Widget _buildExpandableMoodBreakdown() {
    final mainMoods = ["happy", "tired", "anxious", "sad", "angry"];
    final moodCounts = <String, int>{};
    final subCounts = <String, Map<String, int>>{};

    for (var mood in mainMoods) {
      moodCounts[mood] = 0;
      subCounts[mood] = {};
    }

    for (final m in widget.summary.parsedMoods) {
      final main = getValue<String>(m, 'main_mood', '').toLowerCase();
      final sub = getValue<String>(m, 'sub_mood', '').toLowerCase();
      if (main.isEmpty) continue;
      moodCounts[main] = (moodCounts[main] ?? 0) + 1;
      if (sub.isNotEmpty) {
        subCounts[main]![sub] = (subCounts[main]![sub] ?? 0) + 1;
      }
    }

    final total = widget.summary.parsedMoods.length;
    final sorted = moodCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.isNotEmpty ? sorted.first.value : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("📊 Mood Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...sorted.map((entry) {
          final main = entry.key;
          final count = entry.value;
          final percent = total == 0 ? 0 : ((count / total) * 100).round();
          final widthFactor = count / maxCount;
          final emoji = widget.moodEmoji(main);
          final isExpanded = expandedMoods.contains(main);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      expandedMoods.remove(main);
                    } else {
                      expandedMoods.add(main);
                    }
                  });
                },
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 60,
                      child: Text(
                        main[0].toUpperCase() + main.substring(1),
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.black12,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: widthFactor,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: _moodGradient(main),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        "$count ($percent%)",
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
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
                    children: (subCounts[main] ?? {}).entries.map((sub) {
                      return Chip(
                        label: Text("${sub.key.capitalize()} (${sub.value})",
                            style: const TextStyle(fontSize: 12)),
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
        })
      ],
    );
  }

  LinearGradient _moodGradient(String mood) {
    switch (mood) {
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

  Widget _buildSuggestion() => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.yellow.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.summary.suggestion(widget.moodEmoji),
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
}

extension StringCasing on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

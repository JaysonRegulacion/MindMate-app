import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mindmate/widgets/moodtrendscreen/mood_legends.dart';
import 'package:mindmate/widgets/moodtrendscreen/mood_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/mood_repository.dart';

enum MoodPolarity { positive, neutral, negative }

class MoodTrendScreen extends StatefulWidget {
  const MoodTrendScreen({super.key});

  @override
  State<MoodTrendScreen> createState() => _MoodTrendScreenState();
}

class _MoodTrendScreenState extends State<MoodTrendScreen> {
  late final MoodRepository _repo;
  final ScrollController _chartScrollController = ScrollController();

  List<Map<String, dynamic>> _moods = [];
  bool _loading = true;
  String _filter = "This Week";

  final int minY = 1;
  final int maxY = 3;

  final Map<String, dynamic> moodLegendData = {
    "Positive": {"emoji": "😀", "color": Colors.green},
    "Neutral": {"emoji": "😐", "color": Colors.grey},
    "Negative": {"emoji": "😞", "color": Colors.red},
  };

  @override
  void initState() {
    super.initState();
    _repo = MoodRepository(Supabase.instance.client);
    _repo.initConnectivityListener();
    _fetchMoods();
  }

  @override
  void dispose() {
    _repo.disposeConnectivityListener();
    _chartScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMoods() async {
    setState(() => _loading = true);
    final moods = await _repo.fetchMoods();
    setState(() {
      _moods = moods;
      _loading = false;
    });
  }

  // ---------------- POLARITY LOGIC ----------------

  MoodPolarity getMoodPolarity(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'surprise':
        return MoodPolarity.positive;

      case 'neutral':
        return MoodPolarity.neutral;

      case 'angry':
      case 'disgust':
      case 'fear':
      case 'sad':
        return MoodPolarity.negative;

      default:
        return MoodPolarity.neutral;
    }
  }

  int polarityToValue(MoodPolarity polarity) {
    switch (polarity) {
      case MoodPolarity.positive:
        return 3;
      case MoodPolarity.neutral:
        return 2;
      case MoodPolarity.negative:
        return 1;
    }
  }

  String polarityEmoji(MoodPolarity polarity) {
    switch (polarity) {
      case MoodPolarity.positive:
        return "😀";
      case MoodPolarity.neutral:
        return "😐";
      case MoodPolarity.negative:
        return "😞";
    }
  }

  Color polarityColor(MoodPolarity polarity) {
    switch (polarity) {
      case MoodPolarity.positive:
        return Colors.green;
      case MoodPolarity.neutral:
        return Colors.grey;
      case MoodPolarity.negative:
        return Colors.red;
    }
  }

  String emotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
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

  // ---------------- FILTER ----------------

  List<Map<String, dynamic>> _applyFilter() {
    final now = DateTime.now();

    return _moods.where((m) {
      final d = DateTime.parse(m['created_at']);

      switch (_filter) {
        case "Today":
          return d.year == now.year && d.month == now.month && d.day == now.day;
        case "This Week":
          final start = now.subtract(Duration(days: now.weekday - 1));
          final end = start.add(const Duration(days: 6));
          return !d.isBefore(start) && !d.isAfter(end);
        case "This Month":
          return d.year == now.year && d.month == now.month;
        case "This Year":
          return d.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final filteredMoods = _applyFilter().reversed.toList();
    final chartWidth =
        filteredMoods.length <= 3 ? 320.0 : filteredMoods.length * 80.0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            const Text("Mood Trends"),
            Text(_filter,
                style:
                    TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
          ],
        ),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6DD5FA), Color(0xFF2980B9)],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMoods,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip("Today", Icons.today),
                        _buildFilterChip(
                            "This Week", Icons.calendar_view_week),
                        _buildFilterChip(
                            "This Month", Icons.calendar_month),
                        _buildFilterChip("This Year", Icons.calendar_today),
                        _buildFilterChip("All", Icons.all_inclusive),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      height: 260,
                      child: filteredMoods.isEmpty
                          ? const Center(child: Text("No mood data"))
                          : Row(
                              children: [
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text("😀"),
                                    Text("😐"),
                                    Text("😞"),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    controller: _chartScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: chartWidth,
                                      child: LineChart(
                                        LineChartData(
                                          minY: minY.toDouble(),
                                          maxY: maxY.toDouble(),
                                          minX: 0.5,
                                          maxX:
                                              filteredMoods.length + 0.5,
                                          gridData: FlGridData(
                                            show: true,
                                            horizontalInterval: 1,
                                            verticalInterval: 1,
                                          ),
                                          titlesData: FlTitlesData(
                                            leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false)),
                                            topTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false)),
                                            rightTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false)),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (v, _) {
                                                  final i = v.toInt() - 1;
                                                  if (i < 0 ||
                                                      i >=
                                                          filteredMoods
                                                              .length) {
                                                    return const SizedBox();
                                                  }
                                                  final d = DateTime.parse(
                                                      filteredMoods[i]
                                                          ['created_at']);
                                                  return Text(
                                                      DateFormat('MM/dd')
                                                          .format(d),
                                                      style: const TextStyle(
                                                          fontSize: 10));
                                                },
                                              ),
                                            ),
                                          ),
                                          lineBarsData: [
                                            LineChartBarData(
                                              isCurved: true,
                                              barWidth: 3,
                                              spots: List.generate(
                                                  filteredMoods.length, (i) {
                                                final polarity =
                                                    getMoodPolarity(
                                                        filteredMoods[i]
                                                            ['main_mood']);
                                                return FlSpot(
                                                    (i + 1).toDouble(),
                                                    polarityToValue(polarity)
                                                        .toDouble());
                                              }),
                                              dotData: FlDotData(show: true),
                                            )
                                          ],
                                          lineTouchData: LineTouchData(
                                            enabled: true,
                                            touchTooltipData:
                                                LineTouchTooltipData(
                                              getTooltipItems: (spots) {
                                                return spots.map((spot) {
                                                  final mood =
                                                      filteredMoods[
                                                          spot.x.toInt() - 1];
                                                  final polarity =
                                                      getMoodPolarity(
                                                          mood['main_mood']);
                                                  final date =
                                                      DateTime.parse(
                                                          mood['created_at']);
                                                  return LineTooltipItem(
                                                    "${polarity.name.toUpperCase()}\n"
                                                    "${emotionEmoji(mood['main_mood'])} ${mood['main_mood']}\n"
                                                    "${DateFormat('MM/dd HH:mm').format(date)}",
                                                    const TextStyle(
                                                        color: Colors.white),
                                                  );
                                                }).toList();
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 16),
                    MoodLegend(moodLegend: moodLegendData),

                    const SizedBox(height: 16),
                    if (filteredMoods.isNotEmpty)
                      MoodSummaryCard(
                        summary: MoodSummary(filteredMoods),
                        filter: _filter,
                        moodEmoji: emotionEmoji,
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: _filter == label,
      onSelected: (_) => setState(() => _filter = label),
    );
  }
}

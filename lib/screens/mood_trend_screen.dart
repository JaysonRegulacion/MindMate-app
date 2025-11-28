import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:mindmate/widgets/moodtrendscreen/mood_legends.dart';
import 'package:mindmate/widgets/moodtrendscreen/mood_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/mood_repository.dart';

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
  final int maxY = 5;

  final Map<String, String> moodTypes = {
    "Happy": "😊",
    "Tired": "😴",
    "Angry": "😡",
    "Anxious": "😰",
    "Sad": "😢",
  };

  final Map<String, dynamic> moodLegendData = {
    "Happy": {"emoji": "😊", "color": Colors.green},
    "Tired": {"emoji": "😴", "color": Colors.blue},
    "Angry": {"emoji": "😡", "color": Colors.red},
    "Anxious": {"emoji": "😰", "color": Colors.purple},
    "Sad": {"emoji": "😢", "color": Colors.orange},
  };

  @override
  void initState() {
    super.initState();
    _repo = MoodRepository(Supabase.instance.client);
    _repo.initConnectivityListener(); // sync offline moods automatically
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

  int moodToValue(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return 5;
      case 'tired':
        return 4;
      case 'angry':
        return 3;
      case 'anxious':
        return 2;
      case 'sad':
        return 1;
      default:
        return 4;
    }
  }

  String moodEmoji(String mood) {
    return moodTypes.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == mood.toLowerCase(),
          orElse: () => const MapEntry("Other", "🙂"),
        )
        .value;
  }

  Color moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'tired':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'anxious':
        return Colors.purple;
      case 'sad':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _applyFilter() {
    final now = DateTime.now();
    if (_filter == "Today") {
      return _moods.where((m) {
        final d = DateTime.parse(m['created_at']);
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();
    } else if (_filter == "This Week") {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return _moods.where((m) {
        final d = DateTime.parse(m['created_at']);
        return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
      }).toList();
    } else if (_filter == "This Month") {
      return _moods.where((m) {
        final d = DateTime.parse(m['created_at']);
        return d.year == now.year && d.month == now.month;
      }).toList();
    } else if (_filter == "This Year") {
      return _moods.where((m) {
        final d = DateTime.parse(m['created_at']);
        return d.year == now.year;
      }).toList();
    }
    return _moods; // All
  }

  @override
  Widget build(BuildContext context) {
    final filteredMoods = _applyFilter().reversed.toList();

    final double chartWidth =
      filteredMoods.length <= 3 ? 320 : filteredMoods.length * 80;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("Mood Trends"),
                SizedBox(width: 8),
                Text("📈", style: TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _filter,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6DD5FA), Color(0xFF2980B9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMoods,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildFilterChip("Today", Icons.today),
                          _buildFilterChip("This Week", Icons.calendar_view_week),
                          _buildFilterChip("This Month", Icons.calendar_month),
                          _buildFilterChip("This Year", Icons.calendar_today),
                          _buildFilterChip("All", Icons.all_inclusive),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Chart
                      SizedBox(
                        height: 280,
                        child: filteredMoods.isEmpty
                            ? Center(
                                child: Text(
                                  "No moods found for $_filter",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text("😊", style: TextStyle(fontSize: 18)),
                                      Text("😴", style: TextStyle(fontSize: 18)),
                                      Text("😡", style: TextStyle(fontSize: 18)),
                                      Text("😰", style: TextStyle(fontSize: 18)),
                                      Text("😢", style: TextStyle(fontSize: 18)),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _chartScrollController,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _chartScrollController,
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        child: SizedBox(
                                          width: chartWidth,
                                          child: LineChart(
                                            LineChartData(
                                              minY: minY.toDouble(),
                                              maxY: maxY.toDouble(),
                                              minX: 0.5,
                                              maxX: (filteredMoods.length + 0.5).toDouble(),
                                              gridData: FlGridData(
                                                show: true,
                                                drawVerticalLine: true,
                                                drawHorizontalLine: true,
                                                horizontalInterval: 1,   // ← 5 horizontal lines (1,2,3,4,5)
                                                verticalInterval: 1,
                                              ),
                                              borderData: FlBorderData(show: true),
                                              titlesData: FlTitlesData(
                                                leftTitles: AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false),
                                                ),
                                                rightTitles: AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false),
                                                ),
                                                topTitles: AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false),
                                                ),
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    interval: 1,
                                                    getTitlesWidget: (value, _) {
                                                      final index = value.toInt() - 1;
                                                      if (index < 0 || index >= filteredMoods.length) return const SizedBox();
                                                      final date = DateTime.parse(filteredMoods[index]['created_at']);
                                                      return Text(
                                                        DateFormat('MM/dd').format(date),
                                                        style: const TextStyle(fontSize: 10),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              lineBarsData: [
                                                LineChartBarData(
                                                  spots: List.generate(
                                                    filteredMoods.length,
                                                    (i) => FlSpot(
                                                      (i + 1).toDouble(),
                                                      moodToValue(filteredMoods[i]['main_mood']).toDouble(),
                                                    ),
                                                  ),
                                                  isCurved: true,
                                                  curveSmoothness: 0.4,
                                                  color: Colors.blueAccent,
                                                  barWidth: 3,
                                                  isStrokeCapRound: true,
                                                  preventCurveOverShooting: true,
                                                  dotData: FlDotData(
                                                    show: true,
                                                    getDotPainter: (spot, _, __, ___) {
                                                      final mood = filteredMoods[spot.x.toInt() - 1];
                                                      return FlDotCirclePainter(
                                                        radius: 6,
                                                        color: moodColor(mood['main_mood']),
                                                        strokeWidth: 2,
                                                        strokeColor: (mood['synced'] ?? true) ? Colors.white : Colors.orange,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                              lineTouchData: LineTouchData(
                                                enabled: true,
                                                touchTooltipData: LineTouchTooltipData(
                                                  fitInsideHorizontally: true,  // tooltip adjusts if hitting left/right edge
                                                  fitInsideVertically: true,    // tooltip adjusts if hitting top/bottom
                                                  tooltipBorderRadius: BorderRadius.circular(8),
                                                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  getTooltipColor: (touchedSpot) => Colors.black87,
                                                  getTooltipItems: (spots) {
                                                    return spots.map((spot) {
                                                      final mood = filteredMoods[spot.x.toInt() - 1];
                                                      final date = DateTime.parse(mood['created_at']);
                                                      final synced = mood['synced'] == true ? "" : " (offline)";
                                                      final subMood = mood['sub_mood'] != null ? " (${mood['sub_mood']})" : "";
                                                      return LineTooltipItem(
                                                        "${moodEmoji(mood['main_mood'])} ${mood['main_mood']}$subMood$synced\n${DateFormat('MM/dd HH:mm').format(date)}",
                                                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      (maxY - minY + 1),
                                      (i) => Text(
                                        (maxY - i).toString(),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          summary: MoodSummary(
                            filteredMoods.map((m) {
                              return {
                                ...m,
                                'value': moodToValue(m['main_mood']), // precompute value for MoodSummary
                              };
                            }).toList(),
                          ),
                          filter: _filter,
                          moodEmoji: moodEmoji,
                        ),
                    ],
                  ),
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
      selectedColor: Colors.blue.shade100,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mood_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mindmate/widgets/background.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  late final MoodRepository _repo;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _moods = [];
  String _filter = "All";
  bool _loading = true;
  List<bool> _visibleFlags = [];

  @override
  void initState() {
    super.initState();
    _repo = MoodRepository(Supabase.instance.client);
    _repo.initConnectivityListener(); // start syncing automatically
    _fetchMoods();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _repo.disposeConnectivityListener();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMoods() async {
    setState(() {
      _loading = true;
      _moods = [];
      _visibleFlags = [];
    });

    final moods = await _repo.fetchMoods();

    final marked = moods.map((m) {
      final savedOnline = (m['synced'] == true);
      return {...m, 'savedOnline': savedOnline};
    }).toList();

    setState(() {
      _moods = marked;
      _visibleFlags = List.generate(_moods.length, (_) => false);
      _loading = false;
    });

    _animateMoods();
  }

  Future<void> _animateMoods() async {
    for (int i = 0; i < _visibleFlags.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) setState(() => _visibleFlags[i] = true);
    }
  }

  void _onFilterSelected(String filter) {
    setState(() => _filter = filter);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    _visibleFlags = List.generate(_applyFilter().length, (_) => false);
    _animateMoods();
  }

  List<Map<String, dynamic>> _applyFilter() {
    if (_filter == "All") return _moods;

    final now = DateTime.now();
    return _moods.where((mood) {
      final date = DateTime.parse(mood['created_at']);
      switch (_filter) {
        case "Today":
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case "This Week":
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
        case "This Month":
          return date.year == now.year && date.month == now.month;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, dynamic> _moodStyle(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return {'emoji': '😊', 'color': Colors.yellow[100]};
      case 'sad':
        return {'emoji': '😔', 'color': Colors.blue[100]};
      case 'angry':
        return {'emoji': '😡', 'color': Colors.red[100]};
      case 'tired':
        return {'emoji': '😴', 'color': Colors.purple[100]};
      case 'anxious':
        return {'emoji': '😰', 'color': Colors.teal[100]};
      default:
        return {'emoji': '🙂', 'color': Colors.grey[200]};
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) return "Today";
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) return "Yesterday";
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final filteredMoods = _applyFilter();

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var mood in filteredMoods) {
      final key = _formatDateHeader(DateTime.parse(mood['created_at']));
      grouped.putIfAbsent(key, () => []).add(mood);
    }

    final sectionKeys = grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mood History')),
      body: Background(
        gradientColors: const [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        child: SafeArea(
          child: Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : sectionKeys.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: sectionKeys.length,
                            itemBuilder: (context, sectionIndex) {
                              final section = sectionKeys[sectionIndex];
                              final moods = grouped[section]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Text(
                                      section,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87),
                                    ),
                                  ),
                                  ...moods.asMap().entries.map((entry) {
                                    final mood = entry.value;
                                    final globalIndex =
                                        _moods.indexOf(mood);
                                    final date =
                                        DateTime.parse(mood['created_at']);
                                    final savedOnline =
                                        mood['savedOnline'] ?? true;
                                    final moodStyle = _moodStyle(mood['main_mood']);

                                    return AnimatedOpacity(
                                      opacity: globalIndex >= 0 &&
                                              globalIndex < _visibleFlags.length &&
                                              _visibleFlags[globalIndex]
                                          ? 1
                                          : 0,
                                      duration: const Duration(milliseconds: 500),
                                      child: Transform.translate(
                                        offset: globalIndex >= 0 &&
                                                globalIndex < _visibleFlags.length &&
                                                _visibleFlags[globalIndex]
                                            ? Offset.zero
                                            : const Offset(0, 30),
                                        child: Card(
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16)),
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.all(16),
                                            leading: CircleAvatar(
                                              radius: 28,
                                              backgroundColor: moodStyle['color'],
                                              child: Text(
                                                moodStyle['emoji'],
                                                style: const TextStyle(fontSize: 28),
                                              ),
                                            ),
                                            title: Text(
                                              mood['main_mood'] +
                                                  (mood['sub_mood'] != null
                                                      ? " (${mood['sub_mood']})"
                                                      : ""),
                                              style: const TextStyle(
                                                  fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (mood['note'] != null && mood['note'].toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 6),
                                                    child: Text(
                                                      mood['note'],
                                                      style: const TextStyle(
                                                          fontStyle: FontStyle.italic,
                                                          color: Colors.black87,
                                                          fontSize: 14),
                                                    ),
                                                  ),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 6),
                                                  child: Text(
                                                    DateFormat('hh:mm a').format(date),
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600]),
                                                  ),
                                                ),
                                                if (mood['tip'] != null && mood['tip'].toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 6),
                                                    child: Text(
                                                      "💡 Tip: ${mood['tip']}",
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.deepOrange[700],
                                                          fontStyle: FontStyle.italic),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: Icon(
                                              savedOnline
                                                  ? Icons.cloud_done
                                                  : Icons.cloud_upload,
                                              color: savedOnline ? Colors.green : Colors.orange,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ["All", "Today", "This Week", "This Month"];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: filters.map((f) {
          final isSelected = _filter == f;
          return ChoiceChip(
            label: Text(f),
            selected: isSelected,
            onSelected: (_) => _onFilterSelected(f),
            selectedColor: Colors.orange[200],
            backgroundColor: Colors.grey[200],
            labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text("📔", style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              "No moods found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Try switching filters or start logging your moods.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

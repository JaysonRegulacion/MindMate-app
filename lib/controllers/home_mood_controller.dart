import 'package:mindmate/services/mood_repository.dart';

class HomeMoodController {
  final MoodRepository repo;
  
  // All moods from the database
  List<Map<String, dynamic>> allMoods = [];

  // Moods for display (last 7 days)
  List<Map<String, dynamic>> recentMoods = [];

  HomeMoodController(this.repo);

  /// Fetch all moods from the database
  Future<void> fetchAllMoods() async {
    allMoods = await repo.fetchMoods();
    _filterRecentMoods();
  }

  /// Filter moods from the last 7 days for display
  void _filterRecentMoods() {
    final last7Days = DateTime.now().subtract(const Duration(days: 6));

    recentMoods = allMoods.where((m) {
      final date = DateTime.parse(m['created_at']);
      return date.isAfter(last7Days) || date.isAtSameMomentAs(last7Days);
    }).toList()
      ..sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
  }

  /// Filter recent moods by trend (e.g., today)
  List<Map<String, dynamic>> filterByTrend(int selectedTrendIndex) {
    final now = DateTime.now();

    if (selectedTrendIndex == 0) {
      // Only moods for today
      return recentMoods.where((m) {
        final date = DateTime.parse(m['created_at']);
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }).toList();
    }

    return recentMoods;
  }

  /// Calculate the mood streak using all moods
  int calculateStreak() {
    if (allMoods.isEmpty) return 0;

    // Convert all moods to unique dates
    final uniqueDays = allMoods
        .map((m) => DateTime(
              DateTime.parse(m['created_at']).year,
              DateTime.parse(m['created_at']).month,
              DateTime.parse(m['created_at']).day,
            ))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // latest first

    final today = DateTime.now();
    DateTime currentDay = uniqueDays.first;

    int streak = 0;

    for (int i = 0; i < uniqueDays.length; i++) {
      if (i == 0) {
        // Check if first day is today or yesterday
        if (currentDay.isAfter(DateTime(today.year, today.month, today.day).subtract(const Duration(days: 1))) ||
            currentDay.isAtSameMomentAs(DateTime(today.year, today.month, today.day))) {
          streak = 1;
        } else {
          break;
        }
      } else {
        final expectedPrevDay = currentDay.subtract(const Duration(days: 1));
        if (uniqueDays[i] == expectedPrevDay) {
          streak++;
          currentDay = uniqueDays[i];
        } else {
          break;
        }
      }
    }

    return streak;
  }
}

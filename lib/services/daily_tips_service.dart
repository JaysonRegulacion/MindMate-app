class DailyTipsService {
  static const motivationalTips = [
    "Every day is a new beginning, make it count.",
    "You are stronger than you think.",
    "Small steps lead to big changes.",
    "Keep going, you’re doing great.",
    "Believe in yourself and your journey.",
    "Don’t be afraid to start again.",
    "Progress is progress, no matter how small.",
    "Challenges help you grow stronger.",
    "Your effort today will pay off tomorrow.",
    "Focus on what you can control and let go of the rest.",
    "Celebrate small wins—they add up.",
    "Keep your face to the sun, and shadows will fall behind you.",
    "One positive thought in the morning can change your whole day.",
    "You have survived every challenge so far—you can handle today too.",
    "Your potential is limitless—trust yourself.",
    "Difficult roads often lead to beautiful destinations.",
    "Don’t count the days, make the days count.",
    "You don’t have to be perfect to be amazing.",
    "Start where you are, use what you have, do what you can.",
    "Every little step forward is progress.",
    "Storms don’t last forever—better days are ahead.",
    "You are capable of more than you imagine.",
    "Mistakes are proof that you are trying.",
    "Keep planting seeds—your time to bloom will come.",
    "Don’t let yesterday take up too much of today.",
    "The best view comes after the hardest climb.",
    "Dream big, start small, act now.",
    "Your smile can be someone’s sunshine today.",
    "Rest when you need to, but don’t quit.",
    "Believe in progress, not perfection.",
  ];

  /// Deterministic tip per day (same tip shown all day)
  static String getDailyFixedTip() {
    final today = DateTime.now();
    final daySeed = today.year * 1000 + today.dayOfYear;
    final index = daySeed % motivationalTips.length;
    return motivationalTips[index];
  }

  /// Public method with async wrapper (future-proof for API integration)
  static Future<String> getDailyTip() async {
    try {
      return getDailyFixedTip();
    } catch (_) {
      return motivationalTips.first;
    }
  }
}

/// Extension to calculate day of year (1–365/366)
extension DateTimeDayOfYear on DateTime {
  int get dayOfYear {
    final startOfYear = DateTime(year, 1, 1);
    return difference(startOfYear).inDays + 1;
  }
}

import 'package:flutter/material.dart';
import 'package:mindmate/screens/edit_profile_screen.dart';
import 'package:mindmate/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _service = ProfileService();
  Map<String, dynamic>? profile;
  double avgMood = 0;
  int totalLogs = 0;
  int longestStreak = 0;
  List<Map<String, dynamic>> emergencyContacts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  /// Fetch all data for the profile screen
  Future<void> _loadProfileData() async {
    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        _service.fetchUserProfile(),
        _service.fetchAverageMoodThisWeek(),
        _service.fetchTotalMoodLogs(),
        _service.fetchAllMoods(), // fetch all moods to calculate streak
        _service.fetchEmergencyContacts(),
      ]);

      final allMoods = results[3] as List<Map<String, dynamic>>;

      setState(() {
        profile = results[0] as Map<String, dynamic>?;
        avgMood = results[1] as double;
        totalLogs = results[2] as int;
        longestStreak = _calculateStreak(allMoods); // streak logic here
        emergencyContacts = results[4] as List<Map<String, dynamic>>;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading profile data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load profile data.")),
        );
      }
      setState(() => isLoading = false);
    }
  }

  /// Calculate streak based on consecutive days with moods logged
  int _calculateStreak(List<Map<String, dynamic>> moods) {
    if (moods.isEmpty) return 0;

    final uniqueDays = moods
        .map((m) {
          final d = DateTime.parse(m['created_at']);
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // latest first

    final today = DateTime.now();
    DateTime currentDay = uniqueDays.first;

    int streak = 0;

    for (int i = 0; i < uniqueDays.length; i++) {
      if (i == 0) {
        if (currentDay.isAtSameMomentAs(DateTime(today.year, today.month, today.day)) ||
            currentDay.isAfter(DateTime(today.year, today.month, today.day)
                .subtract(const Duration(days: 1)))) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB3E5FC), Color(0xFFE1BEE7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadProfileData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildProfileHeader(),
                                const SizedBox(height: 20),
                                _buildEmergencyContacts(),
                                const SizedBox(height: 30),
                                _buildStatsCards(),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white,
          backgroundImage: profile?['avatar_url'] != null &&
                  profile!['avatar_url'].toString().isNotEmpty
              ? NetworkImage(profile!['avatar_url'])
              : null,
          child: profile?['avatar_url'] == null
              ? const Icon(Icons.person, size: 60, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          "${profile?['first_name']} ${profile?['last_name']}",
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          profile?['email'] ?? '',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('Edit Profile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(profile: profile),
              ),
            );
            _loadProfileData();
          },
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard("Avg Mood", avgMood.toStringAsFixed(1), Icons.mood),
        _statCard("Total Logs", "$totalLogs", Icons.book),
        _statCard("Streak", "$longestStreak", Icons.local_fire_department),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    double width = MediaQuery.of(context).size.width / 3.5;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.deepPurple),
            const SizedBox(height: 5),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Emergency Contact(s)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (emergencyContacts.isEmpty)
          const Text(
            "No contacts added.",
            style: TextStyle(color: Colors.black54),
          )
        else
          Column(
            children: emergencyContacts.map((c) {
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.contact_phone, color: Colors.teal),
                  title: Text(c['name']),
                  subtitle:
                      Text("${c['relationship']} • ${c['phone_number']}"),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

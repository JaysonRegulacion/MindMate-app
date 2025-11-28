import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mindmate/screens/chat_screen.dart';
import 'package:mindmate/screens/journal_screen.dart';
import 'package:mindmate/screens/mood_history_screen.dart';
import 'package:mindmate/screens/mood_log_screen.dart';
import 'package:mindmate/screens/settings_screen.dart';
import 'package:mindmate/screens/signin_screen.dart';
import 'package:mindmate/screens/profile_screen.dart';
import 'package:mindmate/services/user_session.dart';
import 'package:mindmate/widgets/background.dart';
import 'package:mindmate/widgets/homescreen/first_time_notification_prompt.dart';
import 'package:mindmate/widgets/homescreen/mood_trend_card.dart';
import 'package:mindmate/widgets/homescreen/wellness_tip_card.dart';
import 'package:mindmate/widgets/homescreen/home_card_button.dart';
import 'package:mindmate/widgets/homescreen/streak_widget.dart';
import 'package:mindmate/services/mood_repository.dart';
import 'package:mindmate/services/daily_tips_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🧩 Controllers
import 'package:mindmate/controllers/home_animation_controller.dart';
import 'package:mindmate/controllers/home_auth_controller.dart';
import 'package:mindmate/controllers/home_mood_controller.dart';
import 'package:mindmate/controllers/home_connectivity_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // 🧠 Core State
  String? _tip;
  late final MoodRepository _repo;
  late final HomeAnimationController _anim;
  late final HomeAuthController _auth;
  late final HomeMoodController _mood;
  late final HomeConnectivityController _conn;

  bool _loadingMoods = true;
  bool _isOffline = false;
  bool _showBanner = false;
  bool _showChip = false;
  bool _showOnlineBanner = false;
  IconData _bannerIcon = Icons.cloud_off;
  String _bannerMessage = "";
  int _selectedTrendIndex = 0;

  @override
  void initState() {
    super.initState();

    _repo = MoodRepository(Supabase.instance.client);
    _anim = HomeAnimationController(vsync: this);
    _auth = HomeAuthController();
    _mood = HomeMoodController(_repo);

    // 🌐 Connectivity + animation controllers integration
    _conn = HomeConnectivityController(
      repo: _repo,
      bannerController: _anim.bannerController,
      chipController: _anim.chipController,
      onStateChange: ({
        required bool isOffline,
        required bool showBanner,
        required bool showChip,
        required bool showOnlineBanner,
        required IconData bannerIcon,
        required String bannerMessage,
      }) {
        if (!mounted) return;
        setState(() {
          _isOffline = isOffline;
          _showBanner = showBanner;
          _showChip = showChip;
          _showOnlineBanner = showOnlineBanner;
          _bannerIcon = bannerIcon;
          _bannerMessage = bannerMessage;
        });
      },
    );

    // 🌱 Daily tip
    DailyTipsService.getDailyTip().then((value) {
      if (mounted) setState(() => _tip = value);
    });

    // 👤 Auth listener
    _auth.start(() {
      _fetchRecentMoods();
    });

    // 🌤️ Connectivity listener
    _conn.start(
      onRefreshData: _fetchRecentMoods,
      onNewTip: (newTip) {
        if (mounted) setState(() => _tip = newTip);
      },
    );

    // Initial fetch
    if (Supabase.instance.client.auth.currentSession != null) {
      _fetchRecentMoods();
    }
  }

  @override
  void dispose() {
    _auth.dispose();
    _conn.dispose();
    _anim.dispose();
    super.dispose();
  }

  // 📊 Fetch moods using controller
  Future<void> _fetchRecentMoods() async {
    setState(() => _loadingMoods = true);
    await _mood.fetchAllMoods();

    _anim.mainController.reset();
    setState(() => _loadingMoods = false);

    if (_mood.recentMoods.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _anim.mainController.forward();
      });
    }
  }

  // 👋 Greeting logic
  String _getGreetingWithEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning 🌅";
    if (hour < 18) return "Good Afternoon 🌞";
    return "Good Evening 🌙";
  }

  // 🚪 Sign out
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out')),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  // ⚠️ Offline dialog
  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.cloud_off, color: Colors.redAccent), SizedBox(width: 8), Text("Offline Mode")],
        ),
        content: const Text.rich(
          TextSpan(children: [
            TextSpan(text: "You are currently offline.\n\n"),
            TextSpan(text: "❌ Unavailable features:\n", style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: "Profile\n", style: TextStyle(color: Colors.red)),
            TextSpan(text: "Chat with MindMate\n", style: TextStyle(color: Colors.red)),
            TextSpan(text: "Syncing moods with cloud\n\n", style: TextStyle(color: Colors.red)),
            TextSpan(text: "✅ You can still:\n", style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: "Log moods\n", style: TextStyle(color: Colors.green)),
            TextSpan(text: "View your mood trends\n", style: TextStyle(color: Colors.green)),
            TextSpan(text: "View your mood history\n\n", style: TextStyle(color: Colors.green)),
            TextSpan(
              text: "ℹ️ Your logged moods will automatically sync when you are back online.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['first_name'] ?? user?.email?.split('@').first ?? 'Friend';

    final moods = _mood.filterByTrend(_selectedTrendIndex);
    final streak = _mood.calculateStreak();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getGreetingWithEmoji(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'profile') {
                if (_isOffline) {
                  _showOfflineDialog();
                } else {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const ProfileScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        return FadeTransition(
                          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  );
                }
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'logout') {
                await _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Background(
        gradientColors: const [Color(0xFF4A90E2), Color(0xFF50C9C3)],
        child: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  await _fetchRecentMoods();
                  final newTip = await DailyTipsService.getDailyTip();
                  if (mounted) setState(() => _tip = newTip);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tip != null)
                        WellnessTipCard(
                          tip: _tip!,
                          onRefresh: () async {
                            final newTip = await DailyTipsService.getDailyTip();
                            if (mounted) setState(() => _tip = newTip);
                          },
                        ),
                      const SizedBox(height: 24),
                      ScaleTransition(
                        scale: _anim.pulseAnimation,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MoodLogScreen()),
                            ).then((_) async {
                              await _fetchRecentMoods();

                              final hasMoodLogged = await UserSession.hasMoodLogged();
                              final firstPromptShown = await UserSession.getFirstTimeNotificationPrompt();

                              if (mounted && hasMoodLogged && firstPromptShown != true) {
                                showDialog(
                                  context: context,
                                  builder: (_) => const NotificationPermissionPrompt(),
                                );
                              }
                            });
                          },
                          icon: const Icon(Icons.emoji_emotions),
                          label: const Text("Log Today’s Mood"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(55),
                            backgroundColor: const Color(0xFF50C9C3),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MoodTrendCard(
                        moods: moods,
                        selectedTrendIndex: _selectedTrendIndex,
                        isLoading: _loadingMoods,
                        onTrendChanged: (index) => setState(() => _selectedTrendIndex = index),
                        isOffline: _isOffline,
                        onOfflineTap: _showOfflineDialog,
                      ),
                      const SizedBox(height: 24),
                      
                      ScaleTransition(
                        scale: _anim.pulseAnimation,
                        child: SizedBox(
                          width: double.infinity,
                          height: 55, // same as "Log Today's Mood"
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const JournalScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(206, 0, 230, 119),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.book, size: 28, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      "Daily Journal",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🟢 Action buttons 2x2 grid
                      Row(
                        children: [
                          Expanded(
                            child: HomeCardButton(
                              icon: Icons.chat_bubble_outline,
                              label: "Talk to MindMate",
                              screen: const ChatScreen(),
                              isOffline: _isOffline,
                              onOfflineTap: _showOfflineDialog,
                              backgroundColor: Colors.lightBlueAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: HomeCardButton(
                              icon: Icons.history,
                              label: "Mood History",
                              screen: const MoodHistoryScreen(),
                              isOffline: _isOffline,
                              onOfflineTap: _showOfflineDialog,
                              backgroundColor: Colors.purpleAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      StreakWidget(streak: streak),
                    ],
                  ),
                ),
              ),

              // 🔴 Offline / Online banner
              if ((_isOffline && _showBanner) || _showOnlineBanner)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _anim.bannerController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _anim.bannerController,
                        curve: Curves.easeOut,
                      )),
                      child: Container(
                        color: _isOffline ? Colors.redAccent : Colors.green,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_isOffline)
                              Icon(_bannerIcon, color: Colors.white)
                            else
                              RotationTransition(
                                turns: _anim.syncIconRotation,
                                child: Icon(_bannerIcon, color: Colors.white),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _bannerMessage,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 🔴 Persistent offline chip
              if (_isOffline && _showChip)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FadeTransition(
                    opacity: _anim.chipController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _anim.chipController,
                        curve: Curves.easeOut,
                      )),
                      child: ScaleTransition(
                        scale: _anim.chipPulseAnimation,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _showOfflineDialog,
                          child: Chip(
                            avatar: const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                            label: const Text("Offline", style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 🟢 Notification prompt
              const NotificationPermissionPrompt(),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mindmate/screens/all_moods_screen.dart';
import 'package:mindmate/screens/chat_screen.dart';
import 'package:mindmate/screens/home_screen.dart';
import 'package:mindmate/services/user_session.dart';
import 'package:mindmate/widgets/moodlogscreen/mood_tips.dart';
import 'package:mindmate/widgets/moodlogscreen/mood_prompt.dart';
import 'package:mindmate/widgets/moodlogscreen/more_moods_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/mood_repository.dart';
import '../services/connectivity_service.dart';

class MoodLogScreen extends StatefulWidget {
  const MoodLogScreen({super.key});

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen>
    with TickerProviderStateMixin {
  int? _selectedMood;
  String? _selectedSubMood;
  String? _moodId;
  String? _currentTip;
  bool _isOffline = false;

  late ConnectivityService _connectivityService;
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;
  late AnimationController _tipController;
  late Animation<double> _tipOpacity;
  late Animation<double> _tipScale;
  late AnimationController _promptController;
  late Animation<double> _promptOpacity;
  late Animation<Offset> _promptOffset;

  final List<String> _moodEmojis = ["😊", "😴", "😰", "😡", "😔"];
  final List<String> _moodLabels = ["Happy", "Tired", "Anxious", "Angry", "Sad"];
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Animations
    _buttonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buttonScale = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    _tipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _tipOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_tipController);
    _tipScale = Tween<double>(begin: 0.8, end: 1.0).animate(_tipController);
    _promptController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _promptOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_promptController);
    _promptOffset = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(parent: _promptController, curve: Curves.easeOut));

    // Connectivity Service
    _connectivityService = ConnectivityService(
      repo: MoodRepository(supabase),
      onStateChange: ({
        required bool isOffline,
        required bool showBanner,
        required bool showChip,
        required bool showOnlineBanner,
        required IconData bannerIcon,
        required String bannerMessage,
      }) {
        if (mounted) setState(() => _isOffline = isOffline);
      },
      bannerController: AnimationController(vsync: this, duration: const Duration(milliseconds: 500)),
      chipController: AnimationController(vsync: this, duration: const Duration(milliseconds: 500)),
    );

    _connectivityService.startListening(onRefreshData: () async {}, onNewTip: (_) {});
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _tipController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    _connectivityService.dispose();
    super.dispose();
  }

  /// Save mood (supports main + sub mood)
  Future<void> _saveMood(String subMood, int mainMoodIndex) async {
    final tip = MoodTips.getTip(mainMoodIndex);
    final repo = MoodRepository(supabase);
    final mainMood = _moodLabels[mainMoodIndex];

    final entry = await repo.saveMood(
      mainMood: mainMood,
      subMood: subMood != mainMood ? subMood : null,
      tip: tip,
    );

    setState(() {
      _moodId = entry['id'];
      _currentTip = tip;
      _selectedSubMood = subMood;
    });

    await UserSession.setMoodLogged();
  }

  void _openChat() {
    if (_selectedMood == null || _moodId == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          moodId: _moodId!,
          moodText: _selectedSubMood ?? _moodLabels[_selectedMood!],
        ),
      ),
    );
  }

  Widget _moodButton(String emoji, String label, int index) {
    final selected = _selectedMood == index;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedMood = index;
          _selectedSubMood = label;
        });
        _buttonController.forward().then((_) => _buttonController.reverse());
        await _saveMood(label, index);
        await _tipController.forward();
        await Future.delayed(const Duration(milliseconds: 150));
        await _promptController.forward();
        await Future.delayed(const Duration(milliseconds: 300));
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      },
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: Column(
          children: [
            ScaleTransition(
              scale: selected ? _buttonScale : const AlwaysStoppedAnimation(1.0),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: selected ? const Color(0xFF50C9C3) : Colors.grey[200],
                child: Text(emoji, style: const TextStyle(fontSize: 34)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.black87 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getMoodGradient(int moodIndex) {
    switch (moodIndex) {
      case 0:
        return const LinearGradient(
            colors: [Color(0xFFFFF176), Color(0xFFFFB74D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      case 1:
        return const LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFF9575CD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      case 2:
        return const LinearGradient(
            colors: [Color(0xFF80CBC4), Color(0xFF4DB6AC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      case 3:
        return const LinearGradient(
            colors: [Color(0xFFEF5350), Color(0xFFFF7043)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      case 4:
        return const LinearGradient(
            colors: [Color(0xFF81D4FA), Color(0xFFB0BEC5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
      default:
        return const LinearGradient(
            colors: [Color(0xFFD4EDDA), Color(0xFFA8E6CF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MindMate 🌱"),
        backgroundColor: const Color(0xFF50C9C3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text("How are you feeling today?",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text("Tap the emoji that matches your mood",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center),
              const SizedBox(height: 30),

              // Mood Buttons
              LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 3;
                  final itemWidth = (constraints.maxWidth - 40) / crossAxisCount;
                  final rows = <Widget>[];
                  for (var i = 0; i < _moodEmojis.length; i += crossAxisCount) {
                    final chunk = _moodEmojis.asMap().entries
                        .where((e) => e.key >= i && e.key < i + crossAxisCount)
                        .map((e) => SizedBox(
                            width: itemWidth,
                            child: _moodButton(e.value, _moodLabels[e.key], e.key)))
                        .toList();
                    rows.add(Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: chunk.length < crossAxisCount
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.spaceEvenly,
                        children: chunk,
                      ),
                    ));
                  }
                  return Column(children: rows);
                },
              ),

              // More Moods
              MoreMoodsButton(
                onPressed: () async {
                  final selectedMood = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AllMoodsScreen()));
                  if (selectedMood != null) {
                    int moodIndex = 0;
                    if (["Excited","Joyful","Content","Loved","Proud","Grateful","Motivated","Delighted"].contains(selectedMood)) moodIndex = 0;
                    else if (["Sleepy","Drained","Exhausted","Unfocused","Lazy","Overwhelmed","Unmotivated"].contains(selectedMood)) moodIndex = 1;
                    else if (["Worried","Stressed","Nervous","Panicked","Tense","Insecure","Overthinking"].contains(selectedMood)) moodIndex = 2;
                    else if (["Annoyed","Frustrated","Irritated","Bitter","Furious","Upset","Resentful"].contains(selectedMood)) moodIndex = 3;
                    else if (["Lonely","Heartbroken","Disappointed","Gloomy","Hopeless","Depressed","Empty"].contains(selectedMood)) moodIndex = 4;

                    setState(() {
                      _selectedMood = moodIndex;
                      _selectedSubMood = selectedMood;
                    });
                    await _saveMood(selectedMood, moodIndex);
                    await _tipController.forward();
                    await Future.delayed(const Duration(milliseconds: 150));
                    await _promptController.forward();
                    await Future.delayed(const Duration(milliseconds: 300));
                    
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),

              const SizedBox(height: 40),

              // Mood Tip
              if (_selectedMood != null && _currentTip != null)
                FadeTransition(
                  opacity: _tipOpacity,
                  child: ScaleTransition(
                    scale: _tipScale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: _getMoodGradient(_selectedMood!),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 6),
                              blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(_moodEmojis[_selectedMood!],
                              style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 14),
                          Text(_currentTip!,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),

              // Mood Prompt
              if (_selectedMood != null && _selectedSubMood != null)
                SlideTransition(
                  position: _promptOffset,
                  child: FadeTransition(
                    opacity: _promptOpacity,
                    child: MoodPrompt(
                      moodText: _selectedSubMood!,
                      isOffline: _isOffline,
                      onTalkTap: !_isOffline ? _openChat : null,
                      onSaveNote: _isOffline
                          ? (note) async {
                              await MoodRepository(supabase).updateOfflineMoodNote(
                                  mainMood: _moodLabels[_selectedMood!],
                                  subMood: _selectedSubMood!,
                                  note: note);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text("Your note was saved locally!")));
                            }
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

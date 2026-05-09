import 'package:flutter/material.dart';
import 'package:mindmate/services/journal_repository.dart';
import 'package:mindmate/services/risk_detection_service.dart';
import 'package:mindmate/services/emotion_detection_service.dart';
import 'package:mindmate/services/user_session.dart';
import 'package:mindmate/widgets/homescreen/first_time_notification_prompt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddJournalScreen extends StatefulWidget {
  final String? journalId; // null = new, not null = edit

  const AddJournalScreen({super.key, this.journalId});

  @override
  State<AddJournalScreen> createState() => _AddJournalScreenState();
}

class _AddJournalScreenState extends State<AddJournalScreen> {
  final TextEditingController _contentCtrl = TextEditingController();

  bool _isLoading = true;
  String? _journalId;
  String _initialContent = ''; // 🔑 for change detection

  late final JournalRepository _journalRepo;
  late final RiskDetectionService _riskService;
  late final EmotionDetectionService _emotionService;
  final supabase = Supabase.instance.client;

  // NEW: Store detected emotion to show in UI
  String? _detectedMainEmotion;
  String? _detectedSubEmotion;
  double? _emotionConfidence;

  @override
  void initState() {
    super.initState();

    _journalId = widget.journalId;

    _journalRepo = JournalRepository(supabase);
    _journalRepo.initConnectivityListener();

    _riskService = RiskDetectionService(
      supabase,
      moodHistoryLimit: 50,
      journalHistoryLimit: 10,
      chatHistoryLimit: 30,
      riskThreshold: 9.0,
      notificationCooldownMinutes: 1,
    );

    _emotionService = EmotionDetectionService(supabase);

    if (_journalId != null) {
      _loadJournal();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _journalRepo.disposeConnectivityListener();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadJournal() async {
    final journal = await _journalRepo.loadJournal(_journalId!);
    if (journal != null) {
      _initialContent = journal['content'] ?? '';
      _contentCtrl.text = _initialContent;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  bool get _hasUnsavedChanges {
    return _contentCtrl.text.trim() != _initialContent.trim();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them or keep editing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveJournal() async {
    print('🟢 Save button clicked');

    final content = _contentCtrl.text.trim();

    if (content.isEmpty) {
      print('⚠️ Save aborted: content is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something...')),
      );
      return;
    }
    print('⏳ Starting journal save...');

    setState(() => _isLoading = true);

    try {
      // 1️⃣ Save journal FAST (critical path)
      print('📄 Saving journal to database...');
      final savedJournalId = await _journalRepo.saveJournal(
        journalId: _journalId,
        content: content,
      );
      print('✅ Journal saved successfully. ID: $savedJournalId');

      final userId = supabase.auth.currentUser!.id;

      // 2️⃣ Release UI immediately (important UX fix)
      if (!mounted) return;

      setState(() {
        _journalId ??= savedJournalId;
        _initialContent = content;
        _isLoading = false;
      });
      print('🚀 UI released immediately after save');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal saved')),
      );

      // ✅ Mark first journal written (NO UI here)
      final hasJournal = await UserSession.hasJournalLogged();
      if (!hasJournal) {
        await UserSession.setFirstJournalLogged();

        // Show notification permission prompt
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const NotificationPermissionPrompt(),
          );
        }
      }

      // 3️⃣ Run emotion + risk detection in background (DO NOT await)
      print('🧠 Starting background emotion & risk detection...');
      _runBackgroundDetections(
        content: content,
        journalId: savedJournalId,
        userId: userId,
      );
    } catch (e) {
      print('❌ Error while saving journal: $e');

      // 4️⃣ Close screen if editing OR if new journal saved
      if (mounted) {
        Navigator.pop(context, true); // Always notify HomeScreen that a new journal was saved
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save journal: $e')),
      );
    }
  }

  Future<void> _runBackgroundDetections({
    required String content,
    required String journalId,
    required String userId,
  }) async {
    try {
      // 🔹 Emotion detection
      print('🎭 Emotion detection started...');
      final emotionResult = await _emotionService.detect(content);

      if (emotionResult != null && emotionResult['primary_mood'] != 'Unclear') {
        final mainEmotion = emotionResult['primary_mood'] as String;
        final subEmotion =
            (emotionResult['sub_moods'] as List?)?.isNotEmpty == true
                ? emotionResult['sub_moods'][0]
                : null;
        final confidence = (emotionResult['confidence'] as num?)?.toDouble();

        print(
          '🎯 Emotion detected → Main: $mainEmotion, Sub: $subEmotion, Confidence: $confidence',
        );

        // ✅ Save mood with UTC timestamp
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        await supabase.from('moods').upsert({
          'user_id': userId,
          'journal_id': journalId,
          'main_mood': mainEmotion,
          'note': content,
          'tip': null,
          'created_at': nowUtc, // <-- UTC timestamp
        }, onConflict: 'journal_id');

        print('✅ Mood saved successfully (UTC)');

        if (mounted) {
          setState(() {
            _detectedMainEmotion = mainEmotion;
            _detectedSubEmotion = subEmotion;
            _emotionConfidence = confidence;
          });
        }
      } else {
        print('🤔 Emotion detection returned Unclear or null');
      }

      // 🔹 Risk detection
      print('🚨 Risk detection started...');
      final List contacts = await supabase
          .from('emergency_contacts')
          .select('contact_number')
          .eq('user_id', userId);

      final emergencyPhones = contacts
        .map((c) => c['contact_number'])
        .where((phone) => phone != null && phone.toString().trim().isNotEmpty)
        .map((phone) => phone.toString())
        .toList();

      final profile = await supabase
        .from('profiles')
        .select('first_name, last_name')
        .eq('id', userId)
        .maybeSingle();

      final firstName = profile?['first_name']?.toString().trim() ?? '';
      final lastName = profile?['last_name']?.toString().trim() ?? '';

      final userName = (firstName + ' ' + lastName).trim();
      final safeUserName = userName.isNotEmpty ? userName : 'User';

      if (emergencyPhones.isNotEmpty) {
        await _riskService.detectAndNotifyMultiple(
          userId: userId,
          userName: safeUserName,
          emergencyPhones: emergencyPhones,
        );
      }
    } catch (e) {
      debugPrint('Background detection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_journalId != null ? 'Edit Journal' : 'New Journal'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveJournal,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _contentCtrl,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Write your thoughts...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // NEW: Show detected emotion
                    if (_detectedMainEmotion != null)
                      Text(
                        "Detected Emotion: $_detectedMainEmotion"
                        "${_detectedSubEmotion != null ? " ($_detectedSubEmotion)" : ""} "
                        "- Confidence: ${(_emotionConfidence ?? 0).toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.blueGrey,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

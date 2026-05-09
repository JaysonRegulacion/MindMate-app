import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mindmate/chats/widgets.dart';
import 'package:mindmate/services/ai_service.dart';
import 'package:mindmate/services/chat_repository.dart';
import 'package:mindmate/services/risk_detection_service.dart';
import 'package:mindmate/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ChatScreen extends StatefulWidget {
  final String? moodId;
  final String? moodText;
  final String? journalId;

  const ChatScreen({super.key, this.moodId, this.moodText, this.journalId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  late final ChatRepository _chatRepo;

  final List<Map<String, dynamic>> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _chatRepo = ChatRepository(supabase);

    if (widget.moodText != null && widget.moodText!.isNotEmpty) {
      _controller.text = "I feel ${widget.moodText!.toLowerCase()} because...";
    }

    _loadMessages();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final messages = await _chatRepo.loadMessages(user.id);
      setState(() {
        _messages
          ..clear()
          ..addAll(messages.map((msg) => {
                "id": msg['id'],
                "role": msg['role'],
                "content": msg['content'],
                "time": DateTime.parse(msg['created_at']),
              }));
      });
    }
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    // USER MESSAGE → Add to UI instantly
    final userMsg = {
      "id": UniqueKey().toString(),
      "role": "user",
      "content": text.trim(),
      "time": now,
    };

    setState(() {
      _messages.add(userMsg);
      _controller.clear();
      _loading = true;
    });
    _scrollToBottom();

    // Save user message (non-blocking)
    unawaited(_chatRepo.saveMessage(
      userId: user.id,
      moodId: widget.moodId,
      journalId: widget.journalId,
      role: "user",
      content: text.trim(),
    ));

    try {
      // Load mood + journal context in parallel
      final results = await Future.wait([
        _chatRepo.loadMoodHistory(user.id, limit: 15),
        _chatRepo.loadJournalHistory(user.id, limit: 5),
      ]);

      final moodHistory = results[0] as List;
      final journalHistory = results[1] as List;

      // Background risk detection (non-blocking)
      () async {
        try {
          final contacts = await supabase
              .from('emergency_contacts')
              .select('contact_email')
              .eq('user_id', user.id);

          final emails = (contacts as List)
              .map((c) => c['contact_email']?.toString())
              .where((e) => e != null && e.isNotEmpty)
              .cast<String>()
              .toList();

          if (emails.isNotEmpty) {
            final riskService = RiskDetectionService(
              supabase,
              moodHistoryLimit: 50,
              journalHistoryLimit: 10,
              chatHistoryLimit: 30,
              riskThreshold: 9.0,
              notificationCooldownMinutes: 1,
            );

            await riskService.detectAndNotifyMultiple(
              userId: user.id,
              userName: user.email ?? "Anonymous",
              emergencyPhones: emails,
            );
          }
        } catch (e) {
          print("⚠️ Risk detection error: $e");
        }
      }();

      // PREPARE AI CONTEXT (USE LOCAL MESSAGES)
      final recentChats = _messages
          .take(20)
          .map((msg) => {
                "type": "chat",
                "role": msg["role"],
                "content": msg["content"],
                "created_at": msg["time"].toString(),
              })
          .toList()
          .reversed
          .toList();

      final recentMoods = moodHistory
          .map((m) => {
                "mainMood": m['main_mood'],
                "subMood": m['sub_mood'],
                "note": m['note'],
                "created_at": m['created_at'],
              })
          .toList();

      final recentJournals = journalHistory
          .map((j) => {
                "content": j['content'],
                "created_at": j['created_at'],
              })
          .toList();

      // ----------------------------------------
      // AI STREAMING RESPONSE
      // ----------------------------------------
      String generated = "";

      // Create an "empty bubble" for the streaming AI response
      final aiMessageId = UniqueKey().toString();
      setState(() {
        _messages.add({
          "id": aiMessageId,
          "role": "ai",
          "content": "",
          "time": DateTime.now(),
        });
      });
      _scrollToBottom();

      final stream = AIService.chatWithAIStream(
        text,
        conversationHistory: recentChats,
        recentMoods: recentMoods,
        recentJournals: recentJournals,
      );

      StreamSubscription<String>? sub;

      sub = stream.listen(
        (token) {
          generated += token;

          // Update the streaming AI bubble
          setState(() {
            final index =
                _messages.indexWhere((m) => m["id"] == aiMessageId);
            if (index != -1) {
              _messages[index] = {
                ..._messages[index],
                "content": generated,
              };
            }
          });

          _scrollToBottom();
        },
        onDone: () async {
          // Save final AI message
          unawaited(_chatRepo.saveMessage(
            userId: user.id,
            moodId: widget.moodId,
            journalId: widget.journalId,
            role: "ai",
            content: generated.trim(),
          ));

          setState(() => _loading = false);
          _scrollToBottom();

          sub?.cancel();
        },
        onError: (err) {
          print("❌ Streaming error: $err");
          setState(() => _loading = false);
        },
      );
    } catch (e) {
      print("❌ Error in sendMessage: $e");
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("MindMate 🌱"),
        backgroundColor: const Color(0xFF50C9C3),
      ),
      body: Background(
        gradientColors: const [Color(0xFFE3F2FD), Color(0xFFF3E5F5)],
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_loading && index == 0) return const TypingIndicator();
                    final msgIndex = _loading ? index - 1 : index;
                    final msg = _messages[_messages.length - 1 - msgIndex];
                    final prevMsg = msgIndex < _messages.length - 1
                        ? _messages[_messages.length - 2 - msgIndex]
                        : null;
                    return ChatBubble(msg: msg, prevMsg: prevMsg);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Type your message...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF50C9C3)),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
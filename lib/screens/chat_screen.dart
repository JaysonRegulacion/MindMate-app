import 'package:flutter/material.dart';
import 'package:mindmate/chats/widgets.dart';
import 'package:mindmate/services/ai_service.dart';
import 'package:mindmate/services/chat_repository.dart';
import 'package:mindmate/widgets/background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String? moodId;
  final String? moodText;

  const ChatScreen({
    super.key,
    this.moodId,
    this.moodText,
  });

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

    // 👇 If mood passed in, prefill input
    if (widget.moodText != null && widget.moodText!.isNotEmpty) {
      _controller.text = "I feel ${widget.moodText!.toLowerCase()} because...";
    }

    _loadMessagesWithLoading();

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

  Future<void> _loadMessagesWithLoading() async {
    setState(() => _loading = true);
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
    setState(() => _loading = false);
    _scrollToBottom();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1️⃣ Save USER message to DB
    final savedUserMsg = await _chatRepo.saveMessage(
      userId: user.id,
      moodId: widget.moodId,
      moodText: widget.moodText,
      role: "user",
      content: text,
    );

    setState(() {
      _messages.add({
        "id": savedUserMsg?['id'],
        "role": "user",
        "content": text,
        "time": DateTime.now(),
      });
      _controller.clear();
      _loading = true;
    });

    // 2️⃣ Get AI reply
    final reply = await AIService.chatWithAI(text);

    // 3️⃣ Save AI message to DB
    final savedAiMsg = await _chatRepo.saveMessage(
      userId: user.id,
      moodId: widget.moodId,
      moodText: widget.moodText,
      role: "ai",
      content: reply.trim(),
    );

    setState(() {
      _messages.add({
        "id": savedAiMsg?['id'],
        "role": "ai",
        "content": reply.trim(),
        "time": DateTime.now(),
      });
      _loading = false;
    });

    _scrollToBottom();
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
              // Chat history
              Expanded(
                child: _loading && _messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length + (_loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_loading && index == 0) {
                            return const TypingIndicator();
                          }
                          final msgIndex = _loading ? index - 1 : index;
                          final msg = _messages[_messages.length - 1 - msgIndex];
                          final prevMsg = msgIndex < _messages.length - 1
                              ? _messages[_messages.length - 2 - msgIndex]
                              : null;
                          return ChatBubble(msg: msg, prevMsg: prevMsg);
                        },
                      ),
              ),

              // Single unified message input
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

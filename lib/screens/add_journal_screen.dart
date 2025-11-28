import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mindmate/services/journal_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class AddJournalScreen extends StatefulWidget {
  final String? journalId; // Optional: edit mode
  const AddJournalScreen({super.key, this.journalId});

  @override
  State<AddJournalScreen> createState() => _AddJournalScreenState();
}

class _AddJournalScreenState extends State<AddJournalScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isLoading = true;

  late JournalRepository _journalRepo;

  // Replace with your deployed Supabase function URL
  static const String supabaseFunctionUrl =
      "https://jvvesomjnzzjzakxcdmj.supabase.co/functions/v1/analyze-journal";

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    _journalRepo = JournalRepository(supabase);
    _journalRepo.initConnectivityListener();

    if (widget.journalId != null) {
      _loadJournal();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _journalRepo.disposeConnectivityListener();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadJournal() async {
    final journal = await _journalRepo.loadJournal(widget.journalId!);
    if (journal != null) {
      _titleCtrl.text = journal['title'] ?? '';
      _contentCtrl.text = journal['content'] ?? '';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Calls Supabase Edge Function to analyze journal mood
  Future<String> _analyzeMood(String text) async {
    if (text.trim().isEmpty) return "Neutral";

    try {
      final response = await http.post(
        Uri.parse(supabaseFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['mood'] ?? "Neutral";
      } else {
        print("Mood analysis error: ${response.body}");
        return "Neutral";
      }
    } catch (e) {
      print("Mood analysis exception: $e");
      return "Neutral";
    }
  }

  Future<void> _saveJournal() async {
    final content = _contentCtrl.text.trim();
    final title = _titleCtrl.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please write something...'),
      ));
      return;
    }

    setState(() => _isLoading = true);

    // Analyze mood from journal content
    final inferredMood = await _analyzeMood(content);

    await _journalRepo.saveJournal(
      journalId: widget.journalId,
      title: title,
      content: content,
      mood: inferredMood,
    );

    if (!mounted) return;
    Navigator.pop(context, true); // Return true to refresh journal list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.journalId != null ? 'Edit Journal' : 'New Journal'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveJournal),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        labelText: 'Write your thoughts...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

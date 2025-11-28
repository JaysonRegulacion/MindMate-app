import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mindmate/services/journal_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'add_journal_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final JournalRepository _journalRepo;
  final supabase = Supabase.instance.client;

  // Replace with your deployed Supabase Edge Function URL
  static const String supabaseFunctionUrl =
      "https://jvvesomjnzzjzakxcdmj.supabase.co/functions/v1/analyze-journal";

  @override
  void initState() {
    super.initState();
    _journalRepo = JournalRepository(supabase);
    _journalRepo.initConnectivityListener();
  }

  @override
  void dispose() {
    _journalRepo.disposeConnectivityListener();
    super.dispose();
  }

  Future<String> _getMood(Map<String, dynamic> journal) async {
    if (journal['mood'] != null) return journal['mood'];

    final content = journal['content'] ?? '';
    if (content.trim().isEmpty) return "Neutral";

    try {
      final response = await http.post(
        Uri.parse(supabaseFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': content}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['mood'] ?? "Neutral";
      }
    } catch (e) {
      print("Mood analysis error: $e");
    }
    return "Neutral";
  }

  Future<List<Map<String, dynamic>>> _fetchJournals() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final box = await Hive.openBox('offline_journals');

    // Offline journals
    final offline = box.values
        .where((j) => j['user_id'] == user.id)
        .map((j) => Map<String, dynamic>.from(j))
        .toList();

    // Online journals
    List<Map<String, dynamic>> online = [];
    try {
      final res = await supabase
          .from('journals')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      online = List<Map<String, dynamic>>.from(res);

      // Cache online journals
      for (var j in online) {
        await box.put(j['id'], {...j, 'synced': true});
      }
    } catch (_) {}

    // Normalize offline entries
    final normalizedOffline = offline.map((j) {
      if (j['synced'] == true && j['idOnline'] != null) {
        return {...j, 'id': j['idOnline']};
      }
      return j;
    }).toList();

    // Merge offline and online
    final merged = {for (var j in [...normalizedOffline, ...online]) j['id']: j}.values.toList();

    // Sort: unsynced first, then newest
    merged.sort((a, b) {
      final aSynced = a['synced'] == true;
      final bSynced = b['synced'] == true;
      if (aSynced != bSynced) return aSynced ? 1 : -1;

      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return merged;
  }

  Future<void> _deleteJournal(Map<String, dynamic> journal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Journal'),
        content: const Text('Are you sure you want to delete this journal entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    final box = await Hive.openBox('offline_journals');
    final isOffline = journal['synced'] == false;

    if (isOffline) {
      await box.delete(journal['id']);
    } else {
      try {
        await supabase.from('journals').delete().eq('id', journal['id']);
        await box.delete(journal['id']);
      } catch (_) {}
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('My Journal'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchJournals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) return const Center(child: Text('Error fetching journals'));

          final journals = snapshot.data ?? [];
          if (journals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 20),
                  Text(
                    "Your journal is empty",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the + button to add your first entry",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: journals.length,
            itemBuilder: (context, index) {
              final journal = journals[index];
              final isOffline = journal['synced'] == false;

              final createdAt = journal['created_at'];
              String formattedDate = '';
              if (createdAt != null) {
                final date = DateTime.parse(createdAt).toLocal();
                formattedDate =
                    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
                    "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
              }

              return FutureBuilder<String>(
                future: _getMood(journal),
                builder: (context, moodSnapshot) {
                  final mood = moodSnapshot.data ?? "Neutral";
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: isOffline ? Colors.orange.shade50 : Colors.white,
                    child: ListTile(
                      title: Text(
                        journal['title'] ?? 'Untitled',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "$formattedDate • Mood: $mood${isOffline ? ' • Offline' : ''}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteJournal(journal),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddJournalScreen(journalId: journal['id']),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orangeAccent,
        tooltip: 'Add Journal Entry',
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddJournalScreen()),
          ).then((_) => setState(() {}));
        },
      ),
    );
  }
}

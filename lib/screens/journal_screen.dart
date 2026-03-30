import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mindmate/services/journal_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_journal_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final JournalRepository _journalRepo;
  final supabase = Supabase.instance.client;
  late Box _journalBox;
  Future<List<Map<String, dynamic>>>? _journalsFuture;

  @override
  void initState() {
    super.initState();
    _journalRepo = JournalRepository(supabase);
    _journalRepo.initConnectivityListener();
    _initialize();
  }

  Future<void> _initialize() async {
    _journalBox = await Hive.openBox('offline_journals');
    _journalsFuture = _fetchJournals();
    if (mounted) setState(() {}); // rebuild after initialization
  }

  @override
  void dispose() {
    _journalRepo.disposeConnectivityListener();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchJournals() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    // Offline journals
    final offline = _journalBox.values
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

      // Cache online journals in parallel
      await Future.wait(
        online.map((j) => _journalBox.put(j['id'], {...j, 'synced': true})),
      );
    } catch (_) {}

    // Remove duplicates in parallel
    await Future.wait(
      offline
          .where((offlineJournal) {
            final onlineId = offlineJournal['idOnline'];
            return onlineId != null &&
                online.any((j) => j['id'] == onlineId);
          })
          .map((j) => _journalBox.delete(j['id'])),
    );

    // Refresh offline after cleanup
    final cleanedOffline = _journalBox.values
        .where((j) => j['user_id'] == user.id)
        .map((j) => Map<String, dynamic>.from(j))
        .toList();

    // Merge offline and online
    final merged = {
      for (var j in [...cleanedOffline, ...online])
        j['idOnline'] ?? j['id']: {
          ...j,
          'source': j['synced'] == true ? 'Online' : 'Offline'
        }
    }.values.toList();

    // Sort: offline first, then newest
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

  void _openEditor(String journalId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddJournalScreen(journalId: journalId),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _journalsFuture = _fetchJournals(); // refresh only when returning
        });
      }
    });
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
      body: _journalsFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _journalsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching journals'));
                }

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
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
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

                    final content = journal['content'] ?? '';
                    final titleWords = content.split(' ').take(5).join(' ');
                    final displayTitle =
                        titleWords.isNotEmpty ? '$titleWords...' : 'Untitled';

                    final createdAt = journal['created_at'];
                    String formattedDate = '';
                    if (createdAt != null) {
                      final date = DateTime.parse(createdAt).toLocal();
                      formattedDate =
                          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
                          "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: isOffline ? Colors.orange.shade50 : Colors.white,
                      child: ListTile(
                        title: Text(
                          displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "$formattedDate${isOffline ? ' • Offline' : ''}",
                          style:
                              TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          tooltip: 'Edit journal',
                          onPressed: () => _openEditor(journal['id']),
                        ),
                        onTap: () => _openEditor(journal['id']),
                      ),
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
          ).then((_) {
            if (mounted) {
              setState(() {
                _journalsFuture = _fetchJournals();
              });
            }
          });
        },
      ),
    );
  }
}

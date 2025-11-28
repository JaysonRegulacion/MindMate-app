import 'package:flutter/material.dart';

class MoodPrompt extends StatelessWidget {
  final String moodText;
  final VoidCallback? onTalkTap;
  final Future<void> Function(String note)? onSaveNote;
  final bool isOffline; // 👈 NEW

  const MoodPrompt({
    super.key,
    required this.moodText,
    this.onTalkTap,
    this.onSaveNote,
    required this.isOffline, // 👈 NEW
  });

  Future<void> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Why do you feel $moodText?"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: "Share your thoughts...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty && onSaveNote != null) {
                await onSaveNote!(controller.text.trim());
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = moodText.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isOffline
                ? "You're offline. You can still write why you feel $displayText."
                : "If you’d like to share why you feel $displayText,",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 👇 Conditional button display
          if (!isOffline)
            TextButton.icon(
              onPressed: onTalkTap,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text("Talk to MindMate 🌱"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                backgroundColor: Colors.blue.withOpacity(0.05),
              ),
            )
          else
            TextButton.icon(
              onPressed: () => _showNoteDialog(context),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text("Write why"),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                backgroundColor: Colors.orange.withOpacity(0.05),
              ),
            ),
        ],
      ),
    );
  }
}

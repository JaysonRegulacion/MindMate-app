import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final Map<String, dynamic>? prevMsg;

  const ChatBubble({
    super.key,
    required this.msg,
    this.prevMsg,
  });

  @override
  Widget build(BuildContext context) {
    final currentTime = msg["time"] as DateTime;
    final prevTime = prevMsg?["time"] as DateTime?;

    bool showHeader = false;

    if (prevTime == null) {
      showHeader = true;
    } else {
      final difference = currentTime.difference(prevTime);
      if (difference.inMinutes > 30 || currentTime.day != prevTime.day) {
        showHeader = true;
      }
    }

    String headerText = "";
    if (showHeader) {
      final now = DateTime.now();
      if (currentTime.year == now.year &&
          currentTime.month == now.month &&
          currentTime.day == now.day) {
        headerText = "Today";
      } else {
        headerText = DateFormat("MMM d, yyyy").format(currentTime);
      }
    }

    return Column(
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              headerText,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        _buildBubble(context),
      ],
    );
  }

  Widget _buildBubble(BuildContext context) {
    final scale = MediaQuery.of(context).textScaleFactor;
    final isUser = msg["role"] == "user";
    final time = msg["time"] as DateTime;
    final formattedTime = DateFormat("h:mm a").format(time);

    if (msg["isMood"] == true) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.deepPurple[100],
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(
            "🌡️ Mood check-in: ${msg["content"]} • $formattedTime",
            style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 6, bottom: 2),
            child: Text(
              isUser ? "You" : "MindMate 🌱",
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue[200] : Colors.green[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              msg["content"] ?? "",
              style: TextStyle(
                fontSize: 16 * scale,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
          if (msg["note"] != null && msg["note"].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Text(
                "Note: ${msg["note"]}",
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
            child: Text(
              formattedTime,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

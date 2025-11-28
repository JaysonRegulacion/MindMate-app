import 'package:flutter/material.dart';
import 'package:mindmate/services/notification_service.dart';
import 'package:mindmate/services/user_session.dart';
import 'dart:async';

class NotificationPermissionPrompt extends StatefulWidget {
  const NotificationPermissionPrompt({super.key});

  @override
  State<NotificationPermissionPrompt> createState() =>
      _NotificationPermissionPromptState();
}

class _NotificationPermissionPromptState
  extends State<NotificationPermissionPrompt> with SingleTickerProviderStateMixin {

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation for gentle fade-in
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _checkAndPrompt();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAndPrompt() async {
    // Check if already prompted
    final prompted = await UserSession.getFirstTimeNotificationPrompt();
    if (prompted == true) return;

    // Check if user has logged a mood at least once
    final hasMood = await UserSession.hasMoodLogged();
    if (!hasMood) return;

    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;

    // Start fade-in animation
    _animationController.forward();

    // Show dialog
    final granted = await _showExplanationDialog();
    if (granted == true) {
      // Request system notification permission
      final permissionGranted = await NotificationService.requestPermission();
      if (permissionGranted == true) {
        await UserSession.saveNotifEnabled(true);
        final firstName = await UserSession.getFirstName();
        await NotificationService.scheduleDailyReminders(userName: firstName);
        print("✅ Notifications enabled & reminders scheduled!");
      } else {
        await UserSession.saveNotifEnabled(false);
        print("⚠️ Notifications denied by system. Toggle remains OFF.");
      }
    }

    // Mark prompt as shown
    await UserSession.setFirstTimeNotificationPrompt();

    // Close the dialog
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _showExplanationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.notifications_active, color: Colors.blueAccent),
                SizedBox(width: 8),
                Expanded(child: Text("Stay on Track with Daily Reminders ✨")),
              ],
            ),
            content: const Text(
              "MindMate can gently remind you to log your mood every day, helping you stay mindful and track your mental wellness. Would you like to enable notifications?",
              style: TextStyle(height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Not now", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Yes, remind me!", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget is invisible, dialog appears programmatically
    return const SizedBox.shrink();
  }
}

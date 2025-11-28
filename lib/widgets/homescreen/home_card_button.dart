import 'package:flutter/material.dart';

class HomeCardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget screen;
  final bool isOffline;
  final VoidCallback onOfflineTap;
  final Color? backgroundColor;

  const HomeCardButton({
    super.key,
    required this.label,
    required this.icon,
    required this.screen,
    required this.isOffline,
    required this.onOfflineTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isOffline && label == "Talk to MindMate") {
            // Disable chat when offline
            onOfflineTap();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screen),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

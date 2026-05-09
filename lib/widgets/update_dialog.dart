import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchApk(String url) async {
  final uri = Uri.parse(url);

  if (!await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  )) {
    throw 'Could not launch APK URL';
  }
}

Future<void> showUpdateDialog(
  BuildContext context, {
  required bool forceUpdate,
  required String apkUrl,
  required String latestVersion,
}) {
  return showDialog(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (_) => WillPopScope(
      onWillPop: () async => !forceUpdate,
      child: AlertDialog(
        title: const Text('Update Available'),
        content: Text(
          'A new version of MindMate ($latestVersion) is available.\n\n'
          'Please update to continue using the app.',
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          TextButton(
            onPressed: () async {
              try {
                await launchApk(apkUrl);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch update: $e')),
                );
              }
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    ),
  );
}
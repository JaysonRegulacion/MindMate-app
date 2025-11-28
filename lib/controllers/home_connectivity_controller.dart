import 'package:flutter/material.dart';
import 'package:mindmate/services/connectivity_service.dart';
import 'package:mindmate/services/mood_repository.dart';

class HomeConnectivityController {
  final ConnectivityService connectivityService;

  HomeConnectivityController({
    required MoodRepository repo,
    required AnimationController bannerController,
    required AnimationController chipController,
    required void Function({
      required bool isOffline,
      required bool showBanner,
      required bool showChip,
      required bool showOnlineBanner,
      required IconData bannerIcon,
      required String bannerMessage,
    }) onStateChange,
  }) : connectivityService = ConnectivityService(
          repo: repo,
          bannerController: bannerController,
          chipController: chipController,
          onStateChange: onStateChange,
        );

  void start({
    required Future<void> Function() onRefreshData,
    required Function(String newTip) onNewTip,
  }) {
    connectivityService.startListening(onRefreshData: onRefreshData, onNewTip: onNewTip);
  }

  void dispose() => connectivityService.dispose();
}

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mindmate/services/mood_repository.dart';

/// Handles connectivity state changes, offline/online transitions,
/// and calls the provided callbacks to update UI and data.
class ConnectivityService {
  final MoodRepository repo;
  final void Function({
    required bool isOffline,
    required bool showBanner,
    required bool showChip,
    required bool showOnlineBanner,
    required IconData bannerIcon,
    required String bannerMessage,
  }) onStateChange;

  final AnimationController bannerController;
  final AnimationController chipController;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService({
    required this.repo,
    required this.onStateChange,
    required this.bannerController,
    required this.chipController,
  });

  /// Start listening for connectivity changes and check initial state.
  void startListening({
    required Future<void> Function() onRefreshData,
    required void Function(String newTip) onNewTip,
  }) async {
    // ✅ 1️⃣ Check initial connectivity immediately
    final initialResults = await Connectivity().checkConnectivity();
    final isOnline = initialResults.isNotEmpty &&
        initialResults.first != ConnectivityResult.none;

    if (isOnline) {
      onStateChange(
        isOffline: false,
        showBanner: false,
        showChip: false,
        showOnlineBanner: false,
        bannerIcon: Icons.sync,
        bannerMessage: "",
      );
    } else {
      onStateChange(
        isOffline: true,
        showBanner: true,
        showChip: false,
        showOnlineBanner: false,
        bannerIcon: Icons.cloud_off,
        bannerMessage: "You are offline. Some features may not work.",
      );

      bannerController.forward();

      Future.delayed(const Duration(seconds: 3), () {
        bannerController.reverse();
        onStateChange(
          isOffline: true,
          showBanner: false,
          showChip: true,
          showOnlineBanner: false,
          bannerIcon: Icons.cloud_off,
          bannerMessage: "You are offline.",
        );
        chipController.forward();
      });
    }

    // ✅ 2️⃣ Continue listening for connectivity changes
    _subscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final nowOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      if (nowOnline) {
        // 🔵 When back online
        await repo.syncOfflineMoods();

        onStateChange(
          isOffline: false,
          showBanner: true,
          showChip: false,
          showOnlineBanner: true,
          bannerIcon: Icons.sync,
          bannerMessage: "Back online! Syncing your moods...",
        );
        await bannerController.forward();

        Future.delayed(const Duration(seconds: 3), () async {
          await bannerController.reverse();
          onStateChange(
            isOffline: false,
            showBanner: false,
            showChip: false,
            showOnlineBanner: false,
            bannerIcon: Icons.sync,
            bannerMessage: "",
          );
        
        // await onRefreshData();

        });
      } else {
        // 🔴 When offline
        onStateChange(
          isOffline: true,
          showBanner: true,
          showChip: false,
          showOnlineBanner: false,
          bannerIcon: Icons.cloud_off,
          bannerMessage: "You are offline. Some features may not work.",
        );

        bannerController.forward();

        Future.delayed(const Duration(seconds: 3), () {
          bannerController.reverse();
          onStateChange(
            isOffline: true,
            showBanner: false,
            showChip: true,
            showOnlineBanner: false,
            bannerIcon: Icons.cloud_off,
            bannerMessage: "You are offline.",
          );
          chipController.forward();
        });
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}

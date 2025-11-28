import 'package:flutter/material.dart';

class HomeAnimationController {
  late final AnimationController mainController;
  late final AnimationController pulseController;
  late final Animation<double> pulseAnimation;
  late final AnimationController chipPulseController;
  late final Animation<double> chipPulseAnimation;
  late final AnimationController bannerController;
  late final AnimationController chipController;
  late final AnimationController syncIconController;
  late final Animation<double> syncIconRotation;

  HomeAnimationController({required TickerProvider vsync}) {
    mainController = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 900));

    pulseController = AnimationController(vsync: vsync, duration: const Duration(seconds: 1))..repeat(reverse: true);
    pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: pulseController, curve: Curves.easeInOut));

    chipPulseController = AnimationController(vsync: vsync, duration: const Duration(seconds: 1))..repeat(reverse: true);
    chipPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: chipPulseController, curve: Curves.easeInOut));

    bannerController = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 300));
    chipController = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 300));

    syncIconController = AnimationController(vsync: vsync, duration: const Duration(seconds: 2))..repeat();
    syncIconRotation = Tween<double>(begin: 0, end: 1).animate(syncIconController);
  }

  void dispose() {
    mainController.dispose();
    pulseController.dispose();
    chipPulseController.dispose();
    bannerController.dispose();
    chipController.dispose();
    syncIconController.dispose();
  }
}

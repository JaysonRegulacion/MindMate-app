import 'package:flutter/material.dart';
import 'package:mindmate/services/connectivity_service.dart';

class OnlineWrapper extends StatefulWidget {
  final Widget child;
  final ConnectivityService connectivityService;

  const OnlineWrapper({
    super.key,
    required this.child,
    required this.connectivityService,
  });

  @override
  State<OnlineWrapper> createState() => _OnlineWrapperState();
}

class _OnlineWrapperState extends State<OnlineWrapper> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    widget.connectivityService.startListening(
      onRefreshData: () async {
        // Optional: refresh data after connection restores
      },
      onNewTip: (tip) {},
    );

    // Listen for state changes from your service
    widget.connectivityService.onStateChange(
      isOffline: _isOffline,
      showBanner: false,
      showChip: false,
      showOnlineBanner: false,
      bannerIcon: Icons.sync,
      bannerMessage: "",
    );
  }

  @override
  void dispose() {
    widget.connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Connecting...\nPlease check your network connection.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

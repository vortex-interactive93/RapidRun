import 'package:flutter/material.dart';
import '../services/connectivity_permission_service.dart';

/// Slim animated banner indicating offline or missing permission states.
class RuntimeStatusBanner extends StatefulWidget {
  final EdgeInsets padding;
  final Stream<DriverRuntimeStatus>? statusStream; // test injection
  final DriverRuntimeStatus? initialStatus; // test override
  const RuntimeStatusBanner({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.statusStream,
    this.initialStatus,
  });
  @override
  State<RuntimeStatusBanner> createState() => _RuntimeStatusBannerState();
}

class _RuntimeStatusBannerState extends State<RuntimeStatusBanner> {
  late DriverRuntimeStatus _status;
  Stream<DriverRuntimeStatus>? _subStream;
  @override
  void initState() {
    super.initState();
    _status =
        widget.initialStatus ?? ConnectivityPermissionService.instance.current;
    _subStream =
        widget.statusStream ?? ConnectivityPermissionService.instance.stream;
    if (widget.statusStream == null) {
      // Only start service if using live singleton
      ConnectivityPermissionService.instance.start();
    }
    _subStream!.listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final missingLocation = !_status.locationGranted;
    final offline = !_status.online;
    if (!offline && !missingLocation) {
      return const SizedBox.shrink();
    }
    String msg;
    if (offline && missingLocation) {
      msg = 'Offline • Location permission needed';
    } else if (offline) {
      msg = 'Offline – reconnect to receive offers';
    } else {
      msg = 'Location permission required';
    }
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: Offset.zero,
      child: Container(
        width: double.infinity,
        padding: widget.padding.add(const EdgeInsets.symmetric(vertical: 10)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              if (offline) const Color(0xFF8A1F1F) else const Color(0xFF4E2E04),
              if (offline) const Color(0xFF501010) else const Color(0xFF3A2403),
            ],
          ),
          border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(.4), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              offline ? Icons.wifi_off : Icons.location_off,
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (missingLocation)
              TextButton(
                onPressed: () =>
                    ConnectivityPermissionService.instance.refreshAll(),
                child: const Text('Grant', style: TextStyle(fontSize: 12)),
              )
            else
              TextButton(
                onPressed: () =>
                    ConnectivityPermissionService.instance.refreshAll(),
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

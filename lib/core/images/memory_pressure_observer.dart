import 'package:flutter/widgets.dart';

/// Registers with Flutter only while the image service is visible.
class MemoryPressureObserver extends StatefulWidget {
  const MemoryPressureObserver({
    required this.onPressure,
    required this.child,
    this.onBackground,
    super.key,
  });

  final VoidCallback onPressure;
  final VoidCallback? onBackground;
  final Widget child;

  @override
  State<MemoryPressureObserver> createState() => _MemoryPressureObserverState();
}

class _MemoryPressureObserverState extends State<MemoryPressureObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didHaveMemoryPressure() {
    widget.onPressure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.onBackground?.call();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

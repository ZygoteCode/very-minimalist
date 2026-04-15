import 'package:flutter/material.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';

class AppItem extends StatefulWidget {
  final String name;
  final String package;

  const AppItem({super.key, required this.name, required this.package});

  @override
  State<AppItem> createState() => _AppItemState();
}

class _AppItemState extends State<AppItem> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  void _setHovered(bool value) {
    if (_hovered != value) {
      setState(() => _hovered = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _pressed
        ? Colors.white.withValues(alpha: 0.18)
        : _hovered
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: () async {
          try {
            await FlutterDeviceApps.openApp(widget.package);
          } catch (e) {
            debugPrint('Errore apertura app: $e');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

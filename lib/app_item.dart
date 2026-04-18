import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const platform = MethodChannel('lock_channel');

  static const Color _pressedColor = Color(0x2EFFFFFF);
  static const Color _hoverColor = Color(0x14FFFFFF);
  static const Color _transparent = Colors.transparent;
  static const Color _borderColor = Color(0x99FFFFFF);
  static const Color _shadowColor = Color(0x14FFFFFF);
  static const Color _iconColor = Color(0xCCFFFFFF);

  static const EdgeInsets _itemMargin = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  );
  static const EdgeInsets _itemPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );
  static const Duration _animDuration = Duration(milliseconds: 120);

  static const TextStyle _textStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: 'SF Pro',
  );

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
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onLongPress: () => _showContextMenu(context),
          onTap: () async {
            try {
              await FlutterDeviceApps.openApp(widget.package);
            } catch (e) {
              debugPrint('Error while opening app: $e');
            }
          },
          child: AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeOut,
            margin: _itemMargin,
            padding: _itemPadding,
            decoration: BoxDecoration(
              color: _pressed
                  ? _pressedColor
                  : _hovered
                  ? _hoverColor
                  : _transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.name,
                    style: _textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) {
        return RepaintBoundary(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: const Border.fromBorderSide(
                BorderSide(color: _borderColor, width: 2),
              ),
              boxShadow: const [
                BoxShadow(
                  color: _shadowColor,
                  blurRadius: 32,
                  spreadRadius: 12,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuItem(
                  icon: Icons.info_outline,
                  label: 'App info',
                  onTap: () {
                    Navigator.pop(context);
                    _openAppInfo();
                  },
                ),
                _buildMenuItem(
                  icon: Icons.delete_outline,
                  label: 'Uninstall app',
                  onTap: () {
                    Navigator.pop(context);
                    _uninstallApp();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _iconColor, size: 20),
            const SizedBox(width: 16),
            Text(label, style: _textStyle),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppInfo() async {
    try {
      await platform.invokeMethod('openAppInfo', {'package': widget.package});
    } catch (e) {
      debugPrint('Error while getting app info: $e');
    }
  }

  Future<void> _uninstallApp() async {
    try {
      await platform.invokeMethod('uninstallApp', {'package': widget.package});
    } catch (e) {
      debugPrint('Error while trying to uninstall app: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import 'package:signals_flutter/signals_flutter.dart';

class AppItem extends StatefulWidget {
  final String name;
  final String package;

  const AppItem({super.key, required this.name, required this.package});

  @override
  State<AppItem> createState() => _AppItemState();
}

class _AppItemState extends State<AppItem> {
  final Signal<bool> _isHovered = signal(false);
  final Signal<bool> _isPressed = signal(false);

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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _isHovered.value = true,
        onExit: (_) => _isHovered.value = false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _isPressed.value = true,
          onTapUp: (_) => _isPressed.value = false,
          onTapCancel: () => _isPressed.value = false,
          onLongPress: () async => await _showContextMenu(context),
          onTap: () async {
            try {
              await FlutterDeviceApps.openApp(widget.package);
            } catch (e) {
              debugPrint('Error while opening app: $e');
            }
          },
          child: Watch((context) {
            return AnimatedContainer(
              duration: _animDuration,
              curve: Curves.easeOut,
              margin: _itemMargin,
              padding: _itemPadding,
              decoration: BoxDecoration(
                color: _isPressed.value
                    ? _pressedColor
                    : _isHovered.value
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
            );
          }),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomInset + 16,
          ),
          child: RepaintBoundary(
            child: Container(
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
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openAppInfo();
                    },
                  ),
                ],
              ),
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
}
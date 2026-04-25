import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

class CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const CircleIconButton({super.key, required this.icon, this.onTap});

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  final Signal<bool> _isHovered = signal(false);
  final Signal<bool> _isPressed = signal(false);

  static const Color _pressedColor = Color(0x2EFFFFFF);
  static const Color _hoverColor = Color(0x14FFFFFF);
  static const Color _normalColor = Colors.black;
  static const Color _borderColor = Color(0x99FFFFFF);
  static const Color _shadowColor = Color(0x1AFFFFFF);

  static const Duration _animationDuration = Duration(milliseconds: 120);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => _isHovered.value = true,
        onExit: (_) => _isHovered.value = false,
        child: GestureDetector(
          onTapDown: (_) => _isPressed.value = true,
          onTapUp: (_) => _isPressed.value = false,
          onTapCancel: () => _isPressed.value = false,
          onTap: widget.onTap,
          child: Watch((context) {
            return AnimatedContainer(
              duration: _animationDuration,
              curve: Curves.easeOut,
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _isPressed.value
                    ? _pressedColor
                    : _isHovered.value
                    ? _hoverColor
                    : _normalColor,
                shape: BoxShape.circle,
                border: const Border.fromBorderSide(
                  BorderSide(color: _borderColor, width: 2),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: _shadowColor,
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 28,
              ),
            );
          }),
        ),
      ),
    );
  }
}
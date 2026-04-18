import 'package:flutter/material.dart';

class CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const CircleIconButton({super.key, required this.icon, this.onTap});

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  static const Color _pressedColor = Color(0x2EFFFFFF);
  static const Color _hoverColor = Color(0x14FFFFFF);
  static const Color _normalColor = Colors.black;
  static const Color _borderColor = Color(0x99FFFFFF);
  static const Color _shadowColor = Color(0x1AFFFFFF);

  // Ottimizzazione: Durata e Curve costanti per fluidità 120fps
  static const Duration _animationDuration = Duration(milliseconds: 120);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOut,
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _pressed
                  ? _pressedColor
                  : _hovered
                  ? _hoverColor
                  : _normalColor,
              shape: BoxShape.circle,
              border: const Border.fromBorderSide(
                BorderSide(color: _borderColor, width: 2),
              ),
              boxShadow: const [
                BoxShadow(color: _shadowColor, blurRadius: 32, spreadRadius: 8),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

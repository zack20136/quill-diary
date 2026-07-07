import 'package:flutter/material.dart';

class HomePinGlyph extends StatelessWidget {
  const HomePinGlyph({
    required this.icon,
    required this.size,
    required this.color,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color color;

  static const double rotationRadians = 0.38;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotationRadians,
      child: Icon(icon, size: size, color: color),
    );
  }
}

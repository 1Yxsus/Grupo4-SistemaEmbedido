import 'package:flutter/material.dart';

/// Widget animado que muestra un círculo parpadeante de color verde esmeralda.
/// Se utiliza para indicar que el sistema de monitoreo está en vivo/tiempo real.
class LivePulseIndicator extends StatefulWidget {
  const LivePulseIndicator({super.key});

  @override
  State<LivePulseIndicator> createState() => _LivePulseIndicatorState();
}

class _LivePulseIndicatorState extends State<LivePulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF10B981), // Emerald Green
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0xFF10B981), blurRadius: 4, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

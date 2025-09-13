import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class CelebrationAnimation extends StatefulWidget {
  final bool showConfetti;
  final VoidCallback? onConfettiComplete;
  final Widget child;

  const CelebrationAnimation({
    super.key,
    required this.showConfetti,
    this.onConfettiComplete,
    required this.child,
  });

  @override
  State<CelebrationAnimation> createState() => _CelebrationAnimationState();
}

class _CelebrationAnimationState extends State<CelebrationAnimation> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    
    if (widget.showConfetti) {
      _confettiController.play();
    }
  }

  @override
  void didUpdateWidget(covariant CelebrationAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.showConfetti && !oldWidget.showConfetti) {
      _confettiController.play();
    } else if (!widget.showConfetti && oldWidget.showConfetti) {
      _confettiController.stop();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showConfetti)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.01,
              numberOfParticles: 50,
              maxBlastForce: 100,
              minBlastForce: 80,
              gravity: 0.3,
            ),
          ),
      ],
    );
  }
}
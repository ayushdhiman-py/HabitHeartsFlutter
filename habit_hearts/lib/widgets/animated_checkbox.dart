import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;
  final double size;

  const AnimatedCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor = Colors.green,
    this.size = 24.0,
  });

  @override
  State<AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // If the checkbox starts as checked, we want to show the full animation
    if (widget.value) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Play animation when value changes
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onChanged != null) {
          widget.onChanged!(!widget.value);
        }
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.value
            ? Lottie.asset(
                'assets/animations/tick-animation.json',
                width: widget.size,
                height: widget.size,
                repeat: false,
                fit: BoxFit.contain,
              )
            : Icon(
                Icons.check_box_outline_blank,
                color: Theme.of(context).disabledColor,
                size: widget.size,
              ),
      ),
    );
  }
}
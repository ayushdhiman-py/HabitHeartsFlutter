import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? highlightColor;
  final Duration? duration;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.highlightColor,
    this.duration,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700] 
                    : Colors.grey[300])!,
                (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[600] 
                    : Colors.grey[200])!,
                (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700] 
                    : Colors.grey[300])!,
              ],
              stops: [
                _animation.value - 0.2,
                _animation.value,
                _animation.value + 0.2,
              ].map((e) => e.clamp(0.0, 1.0)).toList().cast<double>(),
            ),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import 'gradient_progress_bar.dart';
import 'celebration_animation.dart';

class SwipeableGoalItem extends StatefulWidget {
  final Goal goal;
  final double progress;
  final Function(Goal) onEdit;
  final Function(Goal) onDelete;
  final Function(String) onToggle;

  const SwipeableGoalItem({
    super.key,
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  State<SwipeableGoalItem> createState() => _SwipeableGoalItemState();
}

class _SwipeableGoalItemState extends State<SwipeableGoalItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleToggle() {
    // Start animation
    _animationController.forward().then((_) {
      // Reset animation
      _animationController.reverse();
      // Call the toggle function
      widget.onToggle(widget.goal.id);
      
      // Show confetti if goal is completed
      if (!widget.goal.completed && widget.progress < 100) {
        setState(() {
          _showConfetti = true;
        });
        
        // Hide confetti after animation
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _showConfetti = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CelebrationAnimation(
      showConfetti: _showConfetti,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Slidable(
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => widget.onEdit(widget.goal),
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'Edit',
                      borderRadius: BorderRadius.circular(24),
                    ),
                    SlidableAction(
                      onPressed: (_) => widget.onDelete(widget.goal),
                      backgroundColor: AppColors.brightRed,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Delete',
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: _handleToggle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        leading: Icon(
                          widget.goal.completed ? Icons.check_box : Icons.check_box_outline_blank,
                          color: widget.goal.completed ? AppColors.electricGreen : AppColors.secondaryTextColor,
                        ),
                        title: Text(
                          widget.goal.text,
                          style: TextStyle(
                            decoration: widget.goal.completed ? TextDecoration.lineThrough : null,
                            color: widget.goal.completed ? AppColors.secondaryTextColor : AppColors.textColor,
                            fontWeight: widget.goal.completed ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                        trailing: widget.goal.emoji != null
                            ? Text(
                                widget.goal.emoji!,
                                style: const TextStyle(fontSize: 24),
                              )
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Progress bar
                            GradientProgressBar(
                              value: widget.progress / 100,
                              height: 12,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.progress.toStringAsFixed(0)}% completed',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
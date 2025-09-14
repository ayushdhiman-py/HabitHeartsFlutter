import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'celebration_animation.dart';

class SwipeableTaskItem extends StatefulWidget {
  final Task task;
  final Function(Task) onToggle;
  final Function(Task) onEdit;
  final Function(Task) onDelete;

  const SwipeableTaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<SwipeableTaskItem> createState() => _SwipeableTaskItemState();
}

class _SwipeableTaskItemState extends State<SwipeableTaskItem> with SingleTickerProviderStateMixin {
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
      widget.onToggle(widget.task);
      
      // Show confetti if task is completed
      if (!widget.task.completed) {
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
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Slidable(
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => widget.onEdit(widget.task),
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'Edit',
                      borderRadius: BorderRadius.circular(24),
                    ),
                    SlidableAction(
                      onPressed: (_) => widget.onDelete(widget.task),
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
                  child: ListTile(
                    leading: Icon(
                      widget.task.completed ? Icons.check_box : Icons.check_box_outline_blank,
                      color: widget.task.completed ? AppColors.electricGreen : AppColors.secondaryTextColor,
                    ),
                    title: Text(
                      widget.task.text,
                      style: TextStyle(
                        decoration: widget.task.completed ? TextDecoration.lineThrough : null,
                        color: widget.task.completed ? AppColors.secondaryTextColor : AppColors.textColor,
                        fontWeight: widget.task.completed ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                    subtitle: widget.task.startTime != null || widget.task.endTime != null
                        ? Text(
                            '${widget.task.startTime ?? ''} - ${widget.task.endTime ?? ''}',
                            style: const TextStyle(
                              color: AppColors.secondaryTextColor,
                            ),
                          )
                        : null,
                    trailing: widget.task.emoji != null
                        ? Text(
                            widget.task.emoji!,
                            style: const TextStyle(fontSize: 24),
                          )
                        : null,
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
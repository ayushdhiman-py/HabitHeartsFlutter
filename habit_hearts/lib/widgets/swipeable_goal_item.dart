import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import 'gradient_progress_bar.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100), // Reduced duration for faster response
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
                        size: 24,
                      ),
                      title: Text(
                        widget.goal.text,
                        style: TextStyle(
                          decoration: widget.goal.completed ? TextDecoration.lineThrough : null,
                          color: widget.goal.completed ? AppColors.secondaryTextColor : AppColors.textColor,
                          fontWeight: widget.goal.completed ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                      trailing: SizedBox(
                        height: 30,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Show "habit" tag for habit goals
                            if (widget.goal.isHabit)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.electricBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.electricBlue,
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'habit',
                                  style: TextStyle(
                                    color: AppColors.electricBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            // Show emoji if available
                            if (widget.goal.emoji != null)
                              Text(
                                widget.goal.emoji!,
                                style: const TextStyle(fontSize: 20),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Progress bar - only show for non-habit goals
                    if (!widget.goal.isHabit)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Progress bar
                            GradientProgressBar(
                              completedPercentage: widget.progress / 100,
                              missedPercentage: 0.0,
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
    );
  }
}
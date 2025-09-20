import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

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
      widget.onToggle(widget.task);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.darkCardBackground 
                  : AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.darkBorderColor 
                    : AppColors.borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: _handleToggle,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(
                  widget.task.completed ? Icons.check_box : Icons.check_box_outline_blank,
                  color: widget.task.completed 
                      ? AppColors.electricGreen 
                      : (Theme.of(context).brightness == Brightness.dark 
                          ? AppColors.darkSecondaryTextColor 
                          : AppColors.secondaryTextColor),
                  size: 24,
                ),
                title: Text(
                  widget.task.text,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: widget.task.completed ? TextDecoration.lineThrough : null,
                    color: widget.task.completed 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? AppColors.darkSecondaryTextColor 
                            : AppColors.secondaryTextColor)
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? AppColors.darkTextColor 
                            : AppColors.textColor),
                    fontWeight: widget.task.completed ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: widget.task.startTime != null || widget.task.endTime != null
                    ? Text(
                        '${widget.task.startTime ?? ''} - ${widget.task.endTime ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppColors.darkSecondaryTextColor 
                              : AppColors.secondaryTextColor,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.task.emoji != null)
                      Text(
                        widget.task.emoji!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        onPressed: () => widget.onEdit(widget.task),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppColors.darkTextColor 
                              : AppColors.textColor,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        onPressed: () => widget.onDelete(widget.task),
                        icon: Icon(
                          Icons.delete_outlined,
                          size: 20,
                          color: AppColors.brightRed,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
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
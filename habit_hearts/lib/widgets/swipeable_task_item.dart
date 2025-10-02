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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: const Text('Are you sure you want to delete this task?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDelete(widget.task);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: double.infinity, // Make the container take full width
            margin: const EdgeInsets.symmetric(vertical: 2), // Reduced from 4 to 2 for more compact spacing
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.darkCardBackground 
                  : AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(12), // Reduced from 16 to 12
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Reduced from 4 to 2 for more compact spacing
                visualDensity: const VisualDensity(horizontal: 0, vertical: -2), // Add visual density to reduce overall height
                leading: Icon(
                  widget.task.completed ? Icons.check_box : Icons.check_box_outline_blank,
                  color: widget.task.completed 
                      ? AppColors.vibrantGreen 
                      : (Theme.of(context).brightness == Brightness.dark 
                          ? AppColors.darkSecondaryTextColor 
                          : AppColors.secondaryTextColor),
                  size: 20, // Reduced from 24 to 20
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.task.text,
                          style: TextStyle(
                            fontSize: 15, // Reduced from 16 to 15
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
                        if (widget.task.isShared) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.group,
                              size: 10,
                              color: Theme.of(context).primaryColor,
                            ),
                          )
                        ],
                      ],
                    ),
                    Visibility(
                      visible: widget.task.creatorName.isNotEmpty && widget.task.creatorName != 'You',
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'by ${widget.task.creatorName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? AppColors.darkSecondaryTextColor 
                                : AppColors.secondaryTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: widget.task.startTime != null || widget.task.endTime != null
                    ? Text(
                        '${widget.task.startTime ?? ''} - ${widget.task.endTime ?? ''}',
                        style: TextStyle(
                          fontSize: 11, // Reduced from 12 to 11
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
                      width: 20, // Reduced from 24 to 20
                      height: 20, // Reduced from 24 to 20
                      child: IconButton(
                        onPressed: () => widget.onEdit(widget.task),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18, // Reduced from 20 to 18
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppColors.darkTextColor 
                              : AppColors.textColor,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ),
                    const SizedBox(width: 6), // Reduced from 8 to 6
                    SizedBox(
                      width: 20, // Reduced from 24 to 20
                      height: 20, // Reduced from 24 to 20
                      child: IconButton(
                        onPressed: () => _confirmDelete(context),
                        icon: Icon(
                          Icons.delete_outlined,
                          size: 18, // Reduced from 20 to 18
                          color: AppColors.coralRed,
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

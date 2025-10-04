import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class SwipeableTaskItem extends StatefulWidget {
  final Task task;
  final Function(Task) onToggle;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final String? currentUserId; // Add current user ID to check ownership

  const SwipeableTaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.currentUserId, // Optional current user ID
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
      duration: const Duration(milliseconds: 100),
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
    if (widget.task.isShared &&
        widget.task.isCompletedByLinkedUser &&
        widget.task.completedBy != widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This task was completed by your partner.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _animationController.forward().then((_) {
      _animationController.reverse();
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

  String _getTaskCreatorText() {
    String creatorText = widget.currentUserId == widget.task.createdBy
        ? 'by You'
        : 'by ${widget.task.creatorName}';

    if (widget.task.completed && widget.task.completedBy != null) {
      String completerName = widget.currentUserId == widget.task.completedBy
          ? 'You'
          : (widget.task.completedByName ?? "Unknown");
      return '$creatorText, Completed by $completerName';
    }

    return creatorText;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkCardBackground
                  : AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(12),
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
            child: ListTile(
              onTap: _handleToggle,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
              leading: Icon(
                widget.task.completed ? Icons.check_box : Icons.check_box_outline_blank,
                color: widget.task.completed
                    ? AppColors.vibrantGreen
                    : (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkSecondaryTextColor
                        : AppColors.secondaryTextColor),
                size: 20,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.task.text,
                          style: TextStyle(
                            fontSize: 15,
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
                      ),
                    ],
                  ),
                  Visibility(
                    visible: widget.task.isShared,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _getTaskCreatorText(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSecondaryTextColor
                              : AppColors.secondaryTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: widget.task.startTime != null || widget.task.endTime != null
                  ? Text(
                      '${widget.task.startTime ?? ''} - ${widget.task.endTime ?? ''}',
                      style: TextStyle(
                        fontSize: 11,
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
                  if (widget.currentUserId != null &&
                      (widget.task.createdBy == widget.currentUserId || !widget.task.isShared))
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: IconButton(
                        onPressed: () => widget.onEdit(widget.task),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextColor
                              : AppColors.textColor,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ),
                  if (widget.currentUserId != null &&
                      (widget.task.createdBy == widget.currentUserId || !widget.task.isShared))
                    const SizedBox(width: 6),
                  if (widget.currentUserId != null &&
                      widget.task.createdBy == widget.currentUserId)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: IconButton(
                        onPressed: () => _confirmDelete(context),
                        icon: Icon(
                          Icons.delete_outlined,
                          size: 18,
                          color: AppColors.coralRed,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ),
                  if (widget.currentUserId != null &&
                      widget.task.createdBy == widget.currentUserId)
                    const SizedBox(width: 6),
                  if (widget.currentUserId != null &&
                      widget.task.createdBy == widget.currentUserId)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: IconButton(
                        onPressed: () => widget.onEdit(widget.task),
                        icon: Icon(
                          widget.task.isShared ? Icons.group : Icons.share_outlined,
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
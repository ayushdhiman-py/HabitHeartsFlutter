import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../providers/goals_provider.dart';
import 'gradient_progress_bar.dart';

class ModernGoalItem extends StatefulWidget {
  final Goal goal;
  final double progress;
  final Function(Goal) onEdit;
  final Function(Goal) onDelete;
  final Function(String) onToggle;

  const ModernGoalItem({
    super.key,
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  State<ModernGoalItem> createState() => _ModernGoalItemState();
}

class _ModernGoalItemState extends State<ModernGoalItem> with SingleTickerProviderStateMixin {
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
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4), // Reduced vertical margin from 8 to 4
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _handleToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.goal.isHabit
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Checkbox
                              Icon(
                                widget.goal.completed ? Icons.check_box : Icons.check_box_outline_blank,
                                color: widget.goal.completed ? AppColors.vibrantGreen : AppColors.secondaryTextColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),

                              // Emoji if available
                              if (widget.goal.emoji != null)
                                Text(
                                  widget.goal.emoji!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(width: 8),
                              // Title
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.goal.text,
                                            style: TextStyle(
                                              decoration: widget.goal.completed ? TextDecoration.lineThrough : null,
                                              color: widget.goal.completed
                                                  ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor)
                                                  : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextColor : AppColors.textColor),
                                              fontWeight: widget.goal.completed ? FontWeight.normal : FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (widget.goal.isShared) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).primaryColor.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.group,
                                              size: 14,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          )
                                        ],
                                      ],
                                    ),
                                    Visibility(
                                      visible: widget.goal.creatorName.isNotEmpty && widget.goal.creatorName != 'You',
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'by ${widget.goal.creatorName}',
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
                              ),
                              // Action buttons - positioned directly adjacent
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: IconButton(
                                      onPressed: () => widget.onEdit(widget.goal),
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
                                  const SizedBox(width: 8), // Increased gap
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: IconButton(
                                      onPressed: () => widget.onDelete(widget.goal),
                                      icon: Icon(
                                        Icons.delete_outlined,
                                        size: 20,
                                        color: AppColors.coralRed,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row( // Full layout for goals with progress
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Checkbox
                              Icon(
                                widget.goal.completed ? Icons.check_box : Icons.check_box_outline_blank,
                                color: widget.goal.completed ? AppColors.vibrantGreen : AppColors.secondaryTextColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              // Emoji if available
                              if (widget.goal.emoji != null)
                                Text(
                                  widget.goal.emoji!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(width: 8),
                              // Title
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.goal.text,
                                            style: TextStyle(
                                              decoration: widget.goal.completed ? TextDecoration.lineThrough : null,
                                              color: widget.goal.completed
                                                  ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor)
                                                  : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextColor : AppColors.textColor),
                                              fontWeight: widget.goal.completed ? FontWeight.normal : FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (widget.goal.isShared) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).primaryColor.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.group,
                                              size: 14,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                          )
                                        ],
                                      ],
                                    ),
                                    Visibility(
                                      visible: widget.goal.creatorName.isNotEmpty && widget.goal.creatorName != 'You',
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'by ${widget.goal.creatorName}',
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
                              ),
                              // Action buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: IconButton(
                                      onPressed: () => widget.onEdit(widget.goal),
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
                                  const SizedBox(width: 8), // Increased gap
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: IconButton(
                                      onPressed: () => widget.onDelete(widget.goal),
                                      icon: Icon(
                                        Icons.delete_outlined,
                                        size: 20,
                                        color: AppColors.coralRed,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
                // Progress section for non-habit goals
                if (!widget.goal.isHabit && widget.goal.startDate != null && widget.goal.endDate != null) ...[
                  Consumer<GoalsProvider>(
                    builder: (context, goalsProvider, child) {
                      final progressDetails = goalsProvider.calculateProgressAndMissedPercentage(widget.goal);
                      final completedPercentage = progressDetails['completedPercentage']!;
                      final missedPercentage = progressDetails['missedPercentage']!;

                      return Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Progress bar
                            GradientProgressBar(
                              completedPercentage: completedPercentage / 100,
                              missedPercentage: missedPercentage / 100,
                              height: 8,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${completedPercentage.toStringAsFixed(0)}% completed, ${missedPercentage.toStringAsFixed(0)}% missed',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

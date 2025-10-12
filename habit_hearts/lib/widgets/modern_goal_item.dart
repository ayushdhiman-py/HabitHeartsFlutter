import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../providers/goals_provider.dart';
import '../providers/habit_hearts_auth_provider.dart';

import 'gradient_progress_bar.dart';

class ModernGoalItem extends StatefulWidget {
  final Goal goal;
  final Function(Goal)? onEdit;  // Make nullable
  final Function(Goal)? onDelete;  // Make nullable
  final Function(String) onToggle;
  final String? currentUserId; // Add current user ID parameter

  const ModernGoalItem({
    super.key,
    required this.goal,
    this.onEdit,  // Update to be optional
    this.onDelete,  // Update to be optional
    required this.onToggle,
    this.currentUserId, // Add the new parameter
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
      duration: const Duration(milliseconds: 150), // Slightly longer for a smoother feel
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleToggle() {
    // Immediately call the toggle function for responsiveness
    widget.onToggle(widget.goal.id);

    // Play the animation for visual feedback
    _animationController.forward().then((_) {
      _animationController.reverse();
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
                              // Checkbox - for habits, use individual progress; for goals, use shared completion status
                              Consumer2<GoalsProvider, HabitHeartsAuthProvider>(
                                builder: (context, goalsProvider, authProvider, child) {
                                  bool displayCompleted;
                                  
                                  // Determine the current user ID
                                  final currentUserId = authProvider.user?.uid;
                                  
                                  if (widget.goal.isHabit) {
                                    // For habits (shared or non-shared), use individual progress for the current user
                                    displayCompleted = goalsProvider.isGoalCompletedForDate(widget.goal.id, DateTime.now());
                                  } else {
                                    // For goals (shared or non-shared), use the shared completion status
                                    displayCompleted = widget.goal.completed;
                                  }
                                  
                                  return Icon(
                                    displayCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: displayCompleted ? AppColors.vibrantGreen : AppColors.secondaryTextColor,
                                    size: 24,
                                  );
                                },
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
                                        Consumer<GoalsProvider>(
                                          builder: (context, goalsProvider, child) {
                                            bool displayCompleted;
                                            
                                            if (widget.goal.isHabit) {
                                              // For habits (shared or non-shared), use individual progress for the current user
                                              displayCompleted = goalsProvider.isGoalCompletedForDate(widget.goal.id, DateTime.now());
                                            } else {
                                              // For goals (shared or non-shared), use the shared completion status
                                              displayCompleted = widget.goal.completed;
                                            }
                                            
                                            return Flexible(
                                              child: Text(
                                                widget.goal.text,
                                                style: TextStyle(
                                                  decoration: displayCompleted ? TextDecoration.lineThrough : null,
                                                  color: displayCompleted
                                                      ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor)
                                                      : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextColor : AppColors.textColor),
                                                  fontWeight: displayCompleted ? FontWeight.normal : FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          },
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
                                      visible: widget.goal.creatorName.isNotEmpty,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Consumer2<HabitHeartsAuthProvider, GoalsProvider>(
                                          builder: (context, authProvider, goalsProvider, child) {
                                            String displayText;
                                            final currentUserId = authProvider.user?.uid;
                                            
                                            // Check if the goal was created by the current user
                                            if (widget.goal.createdBy == currentUserId) {
                                              displayText = 'by you';
                                            } else {
                                              // Check if the goal was created by a linked user
                                              final isLinkedUser = authProvider.habitHeartsUser?.linkedUsers.contains(widget.goal.createdBy) == true;
                                              if (isLinkedUser) {
                                                displayText = 'by ${widget.goal.creatorName}';
                                              } else {
                                                displayText = 'by ${widget.goal.creatorName}';
                                              }
                                            }
                                            
                                            bool isCompleted;
                                            
                                            if (widget.goal.isHabit) {
                                              // For habits, show if the current user completed it today
                                              isCompleted = goalsProvider.isGoalCompletedForDate(widget.goal.id, DateTime.now());
                                            } else {
                                              // For goals, show if the goal is completed (shared status)
                                              isCompleted = widget.goal.completed;
                                            }
                                               
                                            if (isCompleted) {
                                              // Check if this is the current user's completion for shared goals
                                              if (widget.goal.isShared && currentUserId != null) {
                                                displayText = '$displayText • completed by you';
                                              } else {
                                                displayText = '$displayText • completed';
                                              }
                                            }
                                            
                                            return Text(
                                              displayText,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context).brightness == Brightness.dark 
                                                    ? AppColors.darkSecondaryTextColor 
                                                    : AppColors.secondaryTextColor,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Action buttons - positioned directly adjacent
                              Builder(
                                builder: (context) {
                                  // Show edit/delete buttons only if the callbacks are provided and user is the owner
                                  bool isOwner = widget.goal.createdBy == widget.currentUserId;
                                  if (widget.onEdit != null && widget.onDelete != null && isOwner) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: IconButton(
                                            onPressed: () {
                                              widget.onEdit?.call(widget.goal);
                                            },
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
                                            onPressed: () {
                                              widget.onDelete?.call(widget.goal);
                                            },
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
                                    );
                                  } else {
                                    // For non-owner viewing shared goals or other scenarios, show no action buttons
                                    return Container(); // Empty container
                                  }
                                },
                              ),
                            ],
                          )
                        : Row( // Full layout for goals with progress
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Checkbox - for habits, use individual progress; for goals, use shared completion status
                              Consumer2<GoalsProvider, HabitHeartsAuthProvider>(
                                builder: (context, goalsProvider, authProvider, child) {
                                  bool displayCompleted;
                                  
                                  // Determine the current user ID
                                  final currentUserId = authProvider.user?.uid;
                                  
                                  if (widget.goal.isHabit) {
                                    // For habits (shared or non-shared), use individual progress for the current user
                                    displayCompleted = goalsProvider.isGoalCompletedForDate(widget.goal.id, DateTime.now());
                                  } else {
                                    // For goals (shared or non-shared), use the shared completion status
                                    displayCompleted = widget.goal.completed;
                                  }
                                  
                                  return Icon(
                                    displayCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: displayCompleted ? AppColors.vibrantGreen : AppColors.secondaryTextColor,
                                    size: 24,
                                  );
                                },
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
                                        Consumer<GoalsProvider>(
                                          builder: (context, goalsProvider, child) {
                                            bool displayCompleted;
                                            
                                            if (widget.goal.isHabit) {
                                              // For habits (shared or non-shared), use individual progress for the current user
                                              displayCompleted = goalsProvider.isGoalCompletedForDate(widget.goal.id, DateTime.now());
                                            } else {
                                              // For goals (shared or non-shared), use the shared completion status
                                              displayCompleted = widget.goal.completed;
                                            }
                                            
                                            return Flexible(
                                              child: Text(
                                                widget.goal.text,
                                                style: TextStyle(
                                                  decoration: displayCompleted ? TextDecoration.lineThrough : null,
                                                  color: displayCompleted
                                                      ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor)
                                                      : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextColor : AppColors.textColor),
                                                  fontWeight: displayCompleted ? FontWeight.normal : FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          },
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
                                      visible: widget.goal.creatorName.isNotEmpty,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Consumer2<HabitHeartsAuthProvider, GoalsProvider>(
                                          builder: (context, authProvider, goalsProvider, child) {
                                            String displayText;
                                            final currentUserId = authProvider.user?.uid;
                                            
                                            // Check if the goal was created by the current user
                                            if (widget.goal.createdBy == currentUserId) {
                                              displayText = 'by you';
                                            } else {
                                              // Check if the goal was created by a linked user
                                              final isLinkedUser = authProvider.habitHeartsUser?.linkedUsers.contains(widget.goal.createdBy) == true;
                                              if (isLinkedUser) {
                                                displayText = 'by ${widget.goal.creatorName}';
                                              } else {
                                                displayText = 'by ${widget.goal.creatorName}';
                                              }
                                            }
                                            
                                            bool isCompleted;
                                            
                                            if (widget.goal.isHabit) {
                                              // For habits, show if the current user completed it today
                                              isCompleted = goalsProvider.isGoalCompletedForDate(widget.goal.id, DateTime.now());
                                            } else {
                                              // For goals, show if the goal is completed (shared status)
                                              isCompleted = widget.goal.completed;
                                            }
                                               
                                            if (isCompleted) {
                                              // Check if this is the current user's completion for shared goals
                                              if (widget.goal.isShared && currentUserId != null) {
                                                displayText = '$displayText • completed by you';
                                              } else {
                                                displayText = '$displayText • completed';
                                              }
                                            }
                                            
                                            return Text(
                                              displayText,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context).brightness == Brightness.dark 
                                                    ? AppColors.darkSecondaryTextColor 
                                                    : AppColors.secondaryTextColor,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Action buttons
                              Builder(
                                builder: (context) {
                                  // Show edit/delete buttons only if the callbacks are provided and user is the owner
                                  bool isOwner = widget.goal.createdBy == widget.currentUserId;
                                  if (widget.onEdit != null && widget.onDelete != null && isOwner) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: IconButton(
                                            onPressed: () => widget.onEdit?.call(widget.goal),
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
                                            onPressed: () => widget.onDelete?.call(widget.goal),
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
                                    );
                                  } else {
                                    // For non-owner viewing shared goals or other scenarios, show no action buttons
                                    return Container(); // Empty container
                                  }
                                },
                              ),
                            ],
                          ),
                  ),
                ),
                // Progress section for goals with date range
                if (!widget.goal.isHabit && widget.goal.startDate != null && widget.goal.endDate != null) ...[
                  Consumer<GoalsProvider>(
                    builder: (context, goalsProvider, child) {
                      final progressMap = goalsProvider.calculateProgressAndMissedPercentage(widget.goal);
                      final double completedPercentage = progressMap['completedPercentage'] ?? 0.0;
                      final double missedPercentage = progressMap['missedPercentage'] ?? 0.0;

                      return Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GradientProgressBar(
                              completedPercentage: completedPercentage / 100.0,
                              missedPercentage: missedPercentage / 100.0,
                              height: 8,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress: ${completedPercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Missed: ${missedPercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                // Streak display for habits
                if (widget.goal.isHabit) ...[
                  Consumer<GoalsProvider>(
                    builder: (context, goalsProvider, child) {
                      if (widget.goal.isHabit) {
                        // For habits, show streak-based progress
                        final currentStreak = goalsProvider.getCurrentStreak(widget.goal.id);
                        // Represent the streak as a percentage with a reasonable max (e.g., 100 days)
                        final double maxStreak = 100.0; // Adjustable max for visualization
                        final double streakPercentage = (currentStreak / maxStreak).clamp(0.0, 1.0);

                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GradientProgressBar(
                                completedPercentage: streakPercentage,
                                missedPercentage: 0.0, // Missed percentage is not directly applicable to current streak visualization
                                height: 8,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Current Streak: $currentStreak days',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Longest Streak: ${goalsProvider.getLongestStreak(widget.goal.id)} days',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else {
                        // For goals, show completion-based progress
                        final double goalProgress = goalsProvider.calculateGoalProgress(widget.goal.id);
                        
                        // Calculate missed percentage based on days that have passed without completion
                        final DateTime today = DateTime.now();
                        final DateTime startDate = widget.goal.startDate!;
                        final DateTime endDate = widget.goal.endDate!;
                        final int totalDays = endDate.difference(startDate).inDays + 1;
                        
                        // Calculate days that have passed (up to end date or today)
                        final int daysPassed = today.isBefore(startDate) 
                            ? 0 
                            : (today.isAfter(endDate) 
                                ? totalDays 
                                : today.difference(startDate).inDays + 1).clamp(0, totalDays);
                        
                        // Count actual completed days in the period that has passed
                        int actualCompletedDays = 0;
                        for (int i = 0; i < daysPassed; i++) {
                          final currentDate = startDate.add(Duration(days: i));
                          if (goalsProvider.isGoalCompletedForDate(widget.goal.id, currentDate)) {
                            actualCompletedDays++;
                          }
                        }
                        
                        // Calculate missed days (days that passed without completion)
                        final int missedDays = daysPassed - actualCompletedDays;
                        final double missedPercentage = totalDays > 0 ? (missedDays / totalDays).clamp(0.0, 1.0) : 0.0;
                        final double completedPercentage = (goalProgress / 100).clamp(0.0, 1.0);

                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GradientProgressBar(
                                completedPercentage: completedPercentage,
                                missedPercentage: missedPercentage,
                                height: 8,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progress: ${goalProgress.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Due: ${widget.goal.endDate!.day}/${widget.goal.endDate!.month}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
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
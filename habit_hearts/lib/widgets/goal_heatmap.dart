import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:habit_hearts/providers/goals_provider.dart';
import 'package:habit_hearts/models/goal.dart';
import 'package:habit_hearts/theme/app_theme.dart';
import 'package:intl/intl.dart';

class GoalHeatmap extends StatefulWidget {
  final Goal goal;
  final Function(String, bool) onDayToggle;

  const GoalHeatmap({
    super.key,
    required this.goal,
    required this.onDayToggle,
  });

  @override
  State<GoalHeatmap> createState() => _GoalHeatmapState();
}

class _GoalHeatmapState extends State<GoalHeatmap> {
  late DateTime _currentMonth;
  late List<DateTime> _daysInMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _daysInMonth = _getDaysInMonth(_currentMonth);
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final List<DateTime> days = [];
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    final DateTime lastDay = DateTime(month.year, month.month + 1, 0);
    
    // Add empty cells for days before the first day of the month
    for (int i = 0; i < firstDay.weekday - 1; i++) {
      days.add(firstDay.subtract(Duration(days: firstDay.weekday - 1 - i)));
    }
    
    // Add all days of the month
    for (int i = 0; i < lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    
    // Add empty cells to complete the grid (6 rows max)
    while (days.length < 42) { // 6 rows * 7 columns
      days.add(lastDay.add(Duration(days: days.length - lastDay.day + 1)));
    }
    
    return days;
  }

  bool _isDayCompleted(GoalsProvider goalsProvider, DateTime day) {
    return goalsProvider.isGoalCompletedForDate(widget.goal.id, day);
  }

  Color _getDayColor(GoalsProvider goalsProvider, DateTime day) {
    if (day.month != _currentMonth.month) {
      return Colors.transparent;
    }
    
    if (_isDayCompleted(goalsProvider, day)) {
      return AppColors.electricGreen; // Completed day
    } else {
      return AppColors.borderColor; // Incomplete day
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    
    return Consumer<GoalsProvider>(
      builder: (context, goalsProvider, child) {
        return Column(
          children: [
            // Weekday headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekdays.map((day) => 
                SizedBox(
                  width: 24,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ).toList(),
            ),
            const SizedBox(height: 4),
            // Calendar grid with bigger cells
            SizedBox(
              height: 140, // Increased height
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double cellSize = constraints.maxWidth / 7 - 4; // Increased cell size
                  return Wrap(
                    spacing: 2, // Increased spacing
                    runSpacing: 2, // Increased run spacing
                    children: List.generate(_daysInMonth.length, (index) {
                      final DateTime day = _daysInMonth[index];
                      final bool isCurrentMonth = day.month == _currentMonth.month;
                      
                      // Get the color based on completion status
                      final Color dayColor = _getDayColor(goalsProvider, day);
                      
                      // Check if we should show the target emoji
                      bool showTargetEmoji = false;
                      if (!widget.goal.isHabit && 
                          widget.goal.endDate != null && 
                          day.isAtSameMomentAs(widget.goal.endDate!)) {
                        showTargetEmoji = true;
                      }
                      
                      return GestureDetector(
                        onTap: () {
                          if (isCurrentMonth) {
                            // Add visual feedback animation
                            setState(() {
                              // Trigger a rebuild with animation
                            });
                            
                            // Toggle the day's completion status
                            final bool isCompleted = _isDayCompleted(goalsProvider, day);
                            widget.onDayToggle(widget.goal.id, !isCompleted);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: cellSize > 24 ? 24 : cellSize,
                          height: cellSize > 24 ? 24 : cellSize,
                          decoration: BoxDecoration(
                            color: isCurrentMonth ? dayColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(6), // Slightly rounded squares
                            border: isCurrentMonth 
                              ? null 
                              : Border.all(color: Colors.grey[200]!, width: 1),
                          ),
                          child: Center(
                            child: showTargetEmoji
                              ? Text(
                                  '${day.day}🎯', // Day number + Target emoji
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AppColors.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Text(
                                  isCurrentMonth ? '${day.day}' : '',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: dayColor == AppColors.electricGreen ? Colors.white : AppColors.textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
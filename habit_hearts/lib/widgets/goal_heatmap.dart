import 'dart:math';

import 'package:flutter/material.dart';
import 'package:habit_hearts/models/goal.dart';
import 'package:intl/intl.dart';

class GoalHeatmap extends StatefulWidget {
  final Goal goal;
  final Map<String, Map<String, String>> userGoalProgress;
  final Function(String, bool) onDayToggle;
  final Color baseColor;

  const GoalHeatmap({
    super.key,
    required this.goal,
    required this.userGoalProgress,
    required this.onDayToggle,
    required this.baseColor,
  });

  @override
  State<GoalHeatmap> createState() => _GoalHeatmapState();
}

class _GoalHeatmapState extends State<GoalHeatmap> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }

  bool _isDayCompleted(DateTime day) {
    final yearMonth = '${day.year}-${day.month.toString().padLeft(2, '0')}';
    final dayOfMonth = day.day;

    if (!widget.userGoalProgress.containsKey(widget.goal.id)) return false;
    if (!widget.userGoalProgress[widget.goal.id]!.containsKey(yearMonth)) return false;

    final bitString = widget.userGoalProgress[widget.goal.id]![yearMonth]!;
    if (dayOfMonth < 1 || dayOfMonth > bitString.length) return false;

    final index = dayOfMonth - 1;
    return index < bitString.length && bitString[index] == '1';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildWeekdayLabels(),
          const SizedBox(height: 4),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) => Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    // Get the days within the goal's date range if available
    List<DateTime> days;
    if (goal.startDate != null && goal.endDate != null) {
      days = _getGoalRangeDays(goal.startDate!, goal.endDate!);
    } else {
      // Fallback to default calendar view if no date range is set
      days = _getCalendarDays(DateTime.now());
    }
    
    final darkerShade = HSLColor.fromColor(baseColor).withLightness(0.7).toColor();
    final darkestShade = HSLColor.fromColor(baseColor).withLightness(0.4).toColor();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final isCompleted = _isDayCompleted(day);
        
        // Check if the day falls within the goal's date range
        bool isWithinGoalRange = true;
        if (goal.startDate != null && goal.endDate != null) {
          isWithinGoalRange = day.isAfter(goal.startDate!.subtract(const Duration(days: 1))) && 
                              day.isBefore(goal.endDate!.add(const Duration(days: 1)));
        }

        Color cellColor;
        if (isCompleted) {
          cellColor = darkestShade;
        } else if (isWithinGoalRange) {
          cellColor = darkerShade;
        } else {
          cellColor = Colors.grey[300]!;
        }

        return Container(
          height: 25,
          width: 25,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: isCompleted || isCurrentMonth ? Colors.white : Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  List<DateTime> _getGoalRangeDays(DateTime startDate, DateTime endDate) {
    List<DateTime> days = [];
    
    // We'll create a grid that fits the date range, but with a 7-day width
    // Calculate the total number of days in the range
    int totalDays = endDate.difference(startDate).inDays + 1;
    
    // Create a list of all the dates in the range
    for (int i = 0; i < totalDays; i++) {
      days.add(startDate.add(Duration(days: i)));
    }
    
    // If needed, we can add padding days to make it look like a calendar grid
    // We'll calculate leading days (before the start date) to align to weekday
    int startDayOfWeek = startDate.weekday % 7; // Sunday = 0, Monday = 1, etc.
    if (startDayOfWeek == 0) startDayOfWeek = 7; // Sunday should be 7 in our calculation
    
    // Add leading empty days for alignment
    List<DateTime> paddedDays = [];
    for (int i = 0; i < startDayOfWeek - 1; i++) { // -1 because Monday is weekday 1
      paddedDays.add(DateTime(1900, 1, 1)); // Use a placeholder date for empty cells
    }
    paddedDays.addAll(days);
    
    // Pad to make it a multiple of 7 for grid display, if needed
    while (paddedDays.length % 7 != 0) {
      paddedDays.add(DateTime(1900, 1, 1)); // Use a placeholder date for empty cells
    }
    
    return paddedDays;
  }

  List<DateTime> _getCalendarDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    final List<DateTime> days = [];

    // Add trailing days from the previous month
    int daysBefore = firstDayOfMonth.weekday;
    if (daysBefore == 7) daysBefore = 0; // Sunday is 7, but we want it to be 0
    for (int i = daysBefore; i > 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i)));
    }

    // Add all days of the current month
    for (int i = 0; i < lastDayOfMonth.day; i++) {
      days.add(firstDayOfMonth.add(Duration(days: i)));
    }

    // Add leading days from the next month
    final daysAfter = 42 - days.length; // 6 weeks * 7 days
    for (int i = 1; i <= daysAfter; i++) {
      days.add(lastDayOfMonth.add(Duration(days: i)));
    }

    return days;
  }
}
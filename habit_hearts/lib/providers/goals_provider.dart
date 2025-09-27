import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../models/user.dart' as habit_hearts_user;
import '../models/goal_progress_summary.dart';

// Extension to add firstWhereOrNull method to List
extension FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class GoalsProvider with ChangeNotifier {
  List<Goal> _goals = [];
  bool _isLoading = false;
  Map<String, Map<String, String>> _userGoalProgress = {}; // goalId -> {yearMonth -> bitString}
  Map<String, int> _currentStreaks = {}; // goalId -> streak count
  Map<String, int> _longestStreaks = {}; // goalId -> streak count

  HabitHeartsAuthProvider? _authProvider;

  List<Goal> get goals => _goals;
  bool get isLoading => _isLoading;
  Map<String, Map<String, String>> get userGoalProgress => _userGoalProgress;
  Map<String, int> get currentStreaks => _currentStreaks;
  Map<String, int> get longestStreaks => _longestStreaks;

  void update(HabitHeartsAuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      loadGoals();
    } else {
      _goals = [];
      notifyListeners();
    }
  }

  // Load goals and progress from API
  Future<void> loadGoals() async {
    if (_isLoading) return;
    if (_authProvider == null || !_authProvider!.isAuthenticated) {
      return;
    }

    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final user = _authProvider!.user;
      if (user == null) return;

      final List<Goal> allGoals = [];

      // Get the current user's goals (all of them)
      try {
        final myGoals = await ApiService.getGoals(user.uid);
        allGoals.addAll(myGoals);
      } catch (e) {
        print('Error loading goals for user ${user.uid}: $e');
      }

      // Get linked users' shared goals
      final habitHeartsUser = _authProvider?.habitHeartsUser;
      if (habitHeartsUser != null) {
        for (String linkedId in habitHeartsUser.linkedUsers) {
          try {
            final linkedUserGoals = await ApiService.getGoals(linkedId);
            allGoals.addAll(linkedUserGoals.where((goal) => goal.isShared));
          } catch (e) {
            print('Error loading goals for user $linkedId: $e');
          }
        }
      }
      _goals = allGoals;

      // Load user's goal progress data
      final userData = await ApiService.getUserGoalProgress(user.uid);
      if (userData != null && userData.goalProgress != null) {
        _userGoalProgress.clear();
        _currentStreaks.clear();
        _longestStreaks.clear();

        userData.goalProgress.forEach((goalId, progressSummary) {
          _userGoalProgress[goalId] = Map<String, String>.from(progressSummary.monthlyData);
          _currentStreaks[goalId] = progressSummary.currentStreak;
          _longestStreaks[goalId] = progressSummary.longestStreak;
        });
      }
    } catch (e) {
      print('Error loading goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new goal
  Future<void> addGoal(BuildContext context, Map<String, dynamic> goalData) async {
    try {
      final now = DateTime.now();
      final goal = Goal(
        id: '', // ID will be assigned by Firestore
        text: goalData['text'],
        completed: false,
        createdBy: goalData['createdBy'],
        creatorName: goalData['creatorName'],
        createdAt: now,
        updatedAt: now,
        status: 'active',
        emoji: goalData['emoji'],
        startDate: goalData['startDate'],
        endDate: goalData['endDate'],
        isHabit: goalData['isHabit'],
      );

      // This will trigger validation in the createGoal method
      final newGoal = await ApiService.createGoal(goal);
      if (newGoal != null) {
        _goals.add(newGoal);
        notifyListeners();
      }
    } catch (e) {
      print('Error adding goal: $e');
      rethrow; // Rethrow to let the UI handle it
    }
  }

  // Update a goal
  Future<void> updateGoal(BuildContext context, Goal updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index == -1) return;

    final originalGoal = _goals[index];
    _goals[index] = updatedGoal;
    notifyListeners();

    try {
      final result = await ApiService.updateGoal(updatedGoal);
      if (result == null) {
        // Revert if the API call fails
        _goals[index] = originalGoal;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating goal: $e');
      // Revert on error
      _goals[index] = originalGoal;
      notifyListeners();
    }
  }

  // Delete a goal
  Future<void> deleteGoal(BuildContext context, String goalId) async {
    try {
      final userId = _authProvider?.user?.uid;

      if (userId == null) {
        throw Exception("User not logged in.");
      }

      // Optimistically remove from UI
      _goals.removeWhere((goal) => goal.id == goalId);
      notifyListeners();

      // Call API to delete
      final goalDeletionSuccess = await ApiService.deleteGoal(goalId);
      final progressDeletionSuccess = await ApiService.removeGoalProgressForUser(userId, goalId);

      if (!goalDeletionSuccess || !progressDeletionSuccess) {
        // If either fails, reload goals to revert UI
        await loadGoals();
      }
    } catch (e) {
      print('Error deleting goal: $e');
      await loadGoals();
    }
  }

  // Toggle goal progress for a specific date (NEW: Bit-based approach)
  Future<bool> toggleGoalProgressForUser(String userId, String goalId, bool completed) async {
    try {
      final result = await ApiService.toggleGoalProgressForUser(userId, goalId, completed);

      if (result != null) {
        // Update local state with new data
        if (result['currentStreak'] != null) {
          _currentStreaks[goalId] = result['currentStreak'];
        }
        if (result['longestStreak'] != null) {
          _longestStreaks[goalId] = result['longestStreak'];
        }
        if (result['monthlyData'] != null) {
          _userGoalProgress[goalId] = Map<String, String>.from(result['monthlyData']);
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      print('Error toggling goal progress for user: $e');
      return false;
    }
  }

  // Calculate current streak locally based on the provided progress data
  int _calculateCurrentStreakLocal(String goalId, Map<String, Map<String, String>> progressData) {
    final goal = _goals.firstWhereOrNull((g) => g.id == goalId);
    if (goal == null || !goal.isHabit) return 0; // Only habits have streaks

    int streak = 0;
    DateTime currentDate = DateTime.now();

    // Iterate backwards from today to find consecutive completed days
    while (true) {
      final yearMonth = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';
      final day = currentDate.day;

      if (progressData.containsKey(goalId) &&
          progressData[goalId]!.containsKey(yearMonth)) {
        final bitString = progressData[goalId]![yearMonth]!;
        if (day >= 1 && day <= bitString.length) {
          final index = day - 1;
          if (bitString[index] == '1') {
            streak++;
            currentDate = currentDate.subtract(const Duration(days: 1));
          } else {
            break; // Streak broken
          }
        } else {
          break; // Day out of bounds for bit string
        }
      } else {
        break; // No progress data for this month
      }
    }
    return streak;
  }

  // Optimistically toggle goal progress for a specific day (used by UI components)
  Future<void> toggleHeatmapDayCompletion(String goalId, DateTime date, bool completed) async {
    final userId = _authProvider?.user?.uid;
    if (userId == null) return;

    // Store original progress for rollback
    final originalProgress = Map<String, Map<String, String>>.from(_userGoalProgress);

    // Optimistically update local state and UI
    _optimisticallyUpdateHeatmapLocal(userId, goalId, date, completed);

    try {
      // Call API to update progress for the specific day
      final result = await ApiService.toggleGoalProgressForUser(userId, goalId, completed, date: date);

      if (result == null) {
        // If API call fails, revert local state
        _userGoalProgress = originalProgress;
        notifyListeners();
        print('Failed to update heatmap day, reverted UI.');
      } else {
        // Update streaks from API response
        if (result['currentStreak'] != null) {
          _currentStreaks[goalId] = result['currentStreak'];
        }
        if (result['longestStreak'] != null) {
          _longestStreaks[goalId] = result['longestStreak'];
        }
        // The monthlyData should already be updated by _optimisticallyUpdateHeatmapLocal
        // but we can re-sync if the API returns a more accurate monthlyData
        if (result['monthlyData'] != null) {
          _userGoalProgress[goalId] = Map<String, String>.from(result['monthlyData']);
        }
        notifyListeners();
      }
    } catch (e) {
      // If API call throws an error, revert local state
      _userGoalProgress = originalProgress;
      notifyListeners();
      print('Error updating heatmap day, reverted UI: $e');
    }
  }

  // Optimistically update the UI for a specific day (used by heatmap for instant feedback)
  void _optimisticallyUpdateHeatmapLocal(String userId, String goalId, DateTime date, bool completed) {
    final yearMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final day = date.day;

    // Create a deep copy of the progress data to modify
    final updatedProgress = Map<String, Map<String, String>>.from(
      _userGoalProgress.map(
        (key, value) => MapEntry(key, Map<String, String>.from(value)),
      ),
    );

    // Initialize the goal entry if it doesn't exist
    if (!updatedProgress.containsKey(goalId)) {
      updatedProgress[goalId] = {};
    }

    // Initialize the month entry if it doesn't exist
    if (!updatedProgress[goalId]!.containsKey(yearMonth)) {
      updatedProgress[goalId]![yearMonth] = '';
    }

    // Get the current bit string for the month
    String bitString = updatedProgress[goalId]![yearMonth]!;

    // Ensure the bit string is long enough for the current day
    if (bitString.length < day) {
      bitString = bitString.padRight(day, '0');
    }

    // Update the bit for the current day
    final index = day - 1;
    final newBitString = bitString.replaceRange(index, index + 1, completed ? '1' : '0');

    // Update the progress data
    updatedProgress[goalId]![yearMonth] = newBitString;

    // Update the state and notify listeners
    _userGoalProgress = updatedProgress;
    notifyListeners();
  }

  // Optimistically toggle entire goal completion status (used by goal items)
  Future<void> optimisticallyToggleGoalProgress(String userId, String goalId, bool completed, {bool updateGoalStatus = true}) async {
    try {
      if (updateGoalStatus) {
        final goal = _goals.firstWhere((g) => g.id == goalId);
        final originalCompletedStatus = goal.completed; // Store original status for rollback
        final updatedGoal = goal.copyWith(completed: completed);

        // Optimistically update the UI
        final index = _goals.indexWhere((g) => g.id == goalId);
        if (index != -1) {
          _goals[index] = updatedGoal;
        }
        notifyListeners();

        try {
          final result = await ApiService.updateGoal(updatedGoal);
          if (result == null) {
            // If API call fails, revert the UI
            final revertGoal = goal.copyWith(completed: originalCompletedStatus);
            if (index != -1) {
              _goals[index] = revertGoal;
            }
            notifyListeners();
            print('Failed to update goal status, reverted UI.');
          } else {
            // If goal status update is successful, also update goal progress for heatmap
            await toggleGoalProgressForUser(userId, goalId, completed);
          }
        } catch (e) {
          // If API call throws an error, revert the UI
          final revertGoal = goal.copyWith(completed: originalCompletedStatus);
          if (index != -1) {
            _goals[index] = revertGoal;
          }
          notifyListeners();
          print('Error updating goal status, reverted UI: $e');
        }
      } else {
        final success = await toggleGoalProgressForUser(userId, goalId, completed);
        if (success) {
          await loadGoals();
        }
      }
    } catch (e) {
      print('Error toggling goal progress: $e');
      await loadGoals();
    }
  }

  // Check if a goal is completed for a specific date
  bool isGoalCompletedForDate(String goalId, DateTime date) {
    final yearMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final day = date.day;

    if (!_userGoalProgress.containsKey(goalId)) return false;
    if (!_userGoalProgress[goalId]!.containsKey(yearMonth)) return false;

    final bitString = _userGoalProgress[goalId]![yearMonth]!;
    if (day < 1 || day > bitString.length) return false;

    final index = day - 1;
    return index < bitString.length && bitString[index] == '1';
  }

  // Get current streak for a goal
  int getCurrentStreak(String goalId) {
    if (!_userGoalProgress.containsKey(goalId)) {
      return _currentStreaks[goalId] ?? 0;
    }
    
    // Use the new method from the model which calculates in real-time
    final progressSummary = GoalProgressSummary(
      monthlyData: _userGoalProgress[goalId] ?? {},
      currentStreak: _currentStreaks[goalId] ?? 0,
      longestStreak: _longestStreaks[goalId] ?? 0,
      lastUpdated: DateTime.now(),
    );
    
    return progressSummary.getCurrentStreak();
  }

  // Get longest streak for a goal
  int getLongestStreak(String goalId) {
    if (!_userGoalProgress.containsKey(goalId)) {
      return _longestStreaks[goalId] ?? 0;
    }
    
    // Use the new method from the model which calculates in real-time
    final progressSummary = GoalProgressSummary(
      monthlyData: _userGoalProgress[goalId] ?? {},
      currentStreak: _currentStreaks[goalId] ?? 0,
      longestStreak: _longestStreaks[goalId] ?? 0,
      lastUpdated: DateTime.now(),
    );
    
    return progressSummary.getLongestStreak();
  }

  List<DateTime> getDatesInCurrentStreak(String goalId) {
    final goal = _goals.firstWhereOrNull((g) => g.id == goalId);
    if (goal == null) return [];

    final List<DateTime> streakDates = [];
    DateTime currentDate = DateTime.now();

    // Adjust for today: if today is not completed, start checking from yesterday
    if (!isGoalCompletedForDate(goalId, currentDate)) {
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    while (isGoalCompletedForDate(goalId, currentDate)) {
      streakDates.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    return streakDates;
  }

  // Calculate progress percentage for a goal based on actual completion data
  double calculateGoalProgress(String goalId) {
    // Get the goal to determine the date range
    final goal = _goals.firstWhereOrNull((g) => g.id == goalId);
    if (goal == null || goal.isHabit || goal.startDate == null || goal.endDate == null) {
      return 0.0;
    }

    final startDate = goal.startDate!;
    final endDate = goal.endDate!;
    final today = DateTime.now();

    // Calculate total days in the goal period
    int totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) return 0.0;

    // Calculate days that have passed in the goal period (up to today)
    DateTime periodEnd = today.isBefore(endDate) ? today : endDate;
    if (periodEnd.isBefore(startDate)) {
      return 0.0;
    }
    
    int daysInPeriod = periodEnd.difference(startDate).inDays + 1;

    // Count completed days in the period that has passed
    int completedDays = 0;
    for (int i = 0; i < daysInPeriod; i++) {
      final currentDate = startDate.add(Duration(days: i));
      if (isGoalCompletedForDate(goalId, currentDate)) {
        completedDays++;
      }
    }

    // Calculate percentage based on days completed vs days that have passed
    // This makes more sense as it shows actual progress vs planned progress
    return (completedDays / daysInPeriod) * 100;
  }

  // Calculate current streak for a goal
  int calculateCurrentStreak(String goalId) {
    return getCurrentStreak(goalId);
  }

  // Calculate longest streak for a goal
  int calculateLongestStreak(String goalId) {
    return getLongestStreak(goalId);
  }

  // Calculate progress and missed percentage for a goal based on date range
  Map<String, double> calculateProgressAndMissedPercentage(Goal goal) {
    if (goal.isHabit || goal.startDate == null || goal.endDate == null) {
      return {'completedPercentage': 0.0, 'missedPercentage': 0.0};
    }

    final startDate = goal.startDate!;
    final endDate = goal.endDate!;

    if (endDate.isBefore(startDate)) {
      return {'completedPercentage': 0.0, 'missedPercentage': 0.0};
    }

    int totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) {
      return {'completedPercentage': 0.0, 'missedPercentage': 0.0};
    }

    int completedDays = 0;
    int missedDays = 0;

    for (int i = 0; i < totalDays; i++) {
      final currentDate = startDate.add(Duration(days: i));
      if (isGoalCompletedForDate(goal.id, currentDate)) {
        completedDays++;
      } else {
        // Only count as missed if the day is in the past or today
        if (currentDate.isBefore(DateTime.now()) || currentDate.isAtSameMomentAs(DateTime.now())) {
          missedDays++;
        }
      }
    }

    final completedPercentage = (completedDays / totalDays) * 100;
    final missedPercentage = (missedDays / totalDays) * 100;

    return {
      'completedPercentage': completedPercentage,
      'missedPercentage': missedPercentage,
    };
  }
}

import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../models/user.dart' as habit_hearts_user;

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
      final userId = _authProvider!.user!.uid;
      
      // Load goals from API (now includes goals from linked users)
      final goals = await ApiService.getGoals(userId);
      _goals = goals;

      // Load user's goal progress data
      final userData = await ApiService.getUserGoalProgress(userId);
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

      final newGoal = await ApiService.createGoal(goal);
      if (newGoal != null) {
        await loadGoals();
      }
    } catch (e) {
      print('Error adding goal: $e');
      // Optionally show an error message to the user
    }
  }

  // Update a goal
  Future<void> updateGoal(BuildContext context, Goal updatedGoal) async {
    try {
      final result = await ApiService.updateGoal(updatedGoal);
      if (result != null) {
        await loadGoals();
      }
    } catch (e) {
      print('Error updating goal: $e');
      // Optionally show an error message to the user
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

        // Instead of reloading all goals, just update the specific goal's progress
        // This is much more efficient than reloading everything
        final userData = await ApiService.getUserGoalProgress(userId);
        if (userData != null && userData.goalProgress != null) {
          final progressData = userData.goalProgress[goalId];
          if (progressData != null) {
            _userGoalProgress[goalId] = Map<String, String>.from(progressData.monthlyData);
          }
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

  // Optimistically toggle goal progress for a specific day (used by "Done Today" button)
  Future<void> markDayAsComplete(String userId, String goalId, bool completed) async {
    // Make a copy of the current progress data for optimistic update
    final originalProgress = Map<String, Map<String, String>>.from(_userGoalProgress);

    try {
      final success = await toggleGoalProgressForUser(userId, goalId, completed);
      if (!success) {
        // Revert on failure
        _userGoalProgress = originalProgress;
        notifyListeners();
      }
      // If successful, the backend will have updated our progress data
      // and we'll get the updated data through the normal data loading mechanism
    } catch (e) {
      // Revert on error
      _userGoalProgress = originalProgress;
      notifyListeners();
    }
  }

  // Immediately update the UI for a specific day (used by "Done Today" button for instant feedback)
  void immediatelyToggleGoalProgress(String goalId, bool completed) {
    final DateTime today = DateTime.now();
    final yearMonth = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final day = today.day;

    // Create a copy of the progress data to modify
    final updatedProgress = Map<String, Map<String, String>>.from(_userGoalProgress);

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
        final updatedGoal = goal.copyWith(completed: completed);
        final result = await ApiService.updateGoal(updatedGoal);
        if (result != null) {
          await loadGoals();
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
    return _currentStreaks[goalId] ?? 0;
  }

  // Get longest streak for a goal
  int getLongestStreak(String goalId) {
    return _longestStreaks[goalId] ?? 0;
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

    // Calculate total days in the goal period
    int totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) return 0.0;

    // Count completed days
    int completedDays = 0;
    for (int i = 0; i < totalDays; i++) {
      final currentDate = startDate.add(Duration(days: i));
      if (isGoalCompletedForDate(goalId, currentDate)) {
        completedDays++;
      }
    }

    // Calculate percentage
    return (completedDays / totalDays) * 100;
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

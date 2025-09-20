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

  List<Goal> get goals => _goals;
  bool get isLoading => _isLoading;
  Map<String, Map<String, String>> get userGoalProgress => _userGoalProgress;
  Map<String, int> get currentStreaks => _currentStreaks;
  Map<String, int> get longestStreaks => _longestStreaks;

  // Load goals and progress from API
  Future<void> loadGoals(String userId, List<String> linkedUserIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Load goals from API
      final goals = await ApiService.getGoals(userId);
      _goals = goals;
      
      // Load goals for linked users
      for (String linkedUserId in linkedUserIds) {
        final linkedGoals = await ApiService.getGoals(linkedUserId);
        _goals.addAll(linkedGoals);
      }

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
  Future<void> addGoal(BuildContext context, Goal goal) async {
    try {
      final newGoal = await ApiService.createGoal(goal);
      if (newGoal != null) {
        _goals.add(newGoal);
        notifyListeners();
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
        final index = _goals.indexWhere((goal) => goal.id == updatedGoal.id);
        if (index != -1) {
          _goals[index] = result; // Use the returned goal from API
          // After updating the goal, reload the user's goal progress to ensure consistency
          final userData = await ApiService.getUserGoalProgress(updatedGoal.createdBy);
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
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error updating goal: $e');
      // Optionally show an error message to the user
    }
  }

  // Delete a goal
  Future<void> deleteGoal(BuildContext context, String goalId) async {
    try {
      // Get the user ID from the auth provider
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception("User not logged in. Cannot delete goal progress.");
      }

      // Step 1: Delete the user's progress for this goal from the 'users' table.
      // Note: This requires a new function in your ApiService and backend.
      final progressDeletionSuccess = await ApiService.removeGoalProgressForUser(userId, goalId);
      print('DEBUG: ApiService.removeGoalProgressForUser success: $progressDeletionSuccess');

      if (progressDeletionSuccess) {
        // Step 2: Delete the actual goal document from the 'goals' table.
        final goalDeletionSuccess = await ApiService.deleteGoal(goalId);
        print('DEBUG: ApiService.deleteGoal success: $goalDeletionSuccess');

        if (goalDeletionSuccess) {
          // Update local state to reflect the deletion in the UI
          _goals = _goals.where((goal) => goal.id != goalId).toList();
          _userGoalProgress.remove(goalId);
          _currentStreaks.remove(goalId);
          _longestStreaks.remove(goalId);
          notifyListeners();
        }
      } else {
        // Handle the case where progress deletion failed
        print('Error deleting goal progress for goalId: $goalId');
      }
    } catch (e) {
      print('Error deleting goal: $e');
      // Optionally show an error message to the user
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

  // Optimistically toggle entire goal completion status (used by goal items)
  Future<void> optimisticallyToggleGoalProgress(String userId, String goalId, bool completed, {bool updateGoalStatus = true}) async {
    // Store original state for rollback
    final originalProgress = Map<String, Map<String, String>>.from(_userGoalProgress);
    Goal? originalGoal;
    int goalIndex = -1;
    
    // If we need to update the goal's overall status, store original goal
    if (updateGoalStatus) {
      goalIndex = _goals.indexWhere((g) => g.id == goalId);
      if (goalIndex != -1) {
        originalGoal = _goals[goalIndex];
      }
    }

    // Update UI optimistically
    if (updateGoalStatus && goalIndex != -1 && originalGoal != null) {
      final updatedGoal = originalGoal.copyWith(completed: completed);
      _goals[goalIndex] = updatedGoal;
    }
    notifyListeners();

    try {
      if (updateGoalStatus && goalIndex != -1 && originalGoal != null) {
        final updatedGoal = originalGoal.copyWith(completed: completed);
        final result = await ApiService.updateGoal(updatedGoal);
        if (result == null) {
          // Revert on failure
          _goals[goalIndex] = originalGoal;
          notifyListeners();
        }
      } else {
        // This is for daily progress updates (e.g., from "Done Today" button)
        final success = await toggleGoalProgressForUser(userId, goalId, completed);
        if (!success) {
          // Revert on failure
          _userGoalProgress = originalProgress;
          notifyListeners();
        }
      }
    } catch (e) {
      // Revert on error
      _userGoalProgress = originalProgress;
      if (updateGoalStatus && goalIndex != -1 && originalGoal != null) {
        _goals[goalIndex] = originalGoal;
      }
      notifyListeners();
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

    int totalDays = endDate.difference(startDate).inDays + 1;
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
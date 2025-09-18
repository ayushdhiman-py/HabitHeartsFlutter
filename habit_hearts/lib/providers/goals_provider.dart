import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../models/user.dart' as habit_hearts_user;
import '../models/user.dart' as habit_hearts_user;

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
  Future<void> loadGoals(String userId) async {
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

      if (progressDeletionSuccess) {
        // Step 2: Delete the actual goal document from the 'goals' table.
        final goalDeletionSuccess = await ApiService.deleteGoal(goalId);

        if (goalDeletionSuccess) {
          // Update local state to reflect the deletion in the UI
          _goals.removeWhere((goal) => goal.id == goalId);
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
        
        // Update the goal's completed property based on today's completion status
        final goalIndex = _goals.indexWhere((g) => g.id == goalId);
        if (goalIndex != -1) {
          final isCompletedToday = isGoalCompletedForDate(goalId, DateTime.now());
          _goals[goalIndex] = _goals[goalIndex].copyWith(completed: isCompletedToday);
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

  // Calculate progress percentage for a goal (last 7 days)
  double calculateGoalProgress(String goalId) {
    // This is a simplified version - in a real implementation you might want to calculate this differently
    final currentStreak = getCurrentStreak(goalId);
    final longestStreak = getLongestStreak(goalId);
    
    if (longestStreak == 0) return 0.0;
    return (currentStreak / longestStreak) * 100;
  }

  // Calculate current streak for a goal
  int calculateCurrentStreak(String goalId) {
    return getCurrentStreak(goalId);
  }

  // Calculate longest streak for a goal
  int calculateLongestStreak(String goalId) {
    return getLongestStreak(goalId);
  }
}
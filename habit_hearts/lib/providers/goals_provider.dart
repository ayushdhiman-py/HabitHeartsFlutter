import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';

class GoalsProvider with ChangeNotifier {
  List<Goal> _goals = [];
  List<GoalProgress> _goalProgress = [];
  bool _isLoading = false;

  List<Goal> get goals => _goals;
  List<GoalProgress> get goalProgress => _goalProgress;
  bool get isLoading => _isLoading;

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
      
      // Load progress for all goals in parallel
      final allProgressFutures = _goals.map((goal) => ApiService.getGoalProgress(goal.id)).toList();
      final allProgressLists = await Future.wait(allProgressFutures);
      _goalProgress = allProgressLists.expand((list) => list).toList();
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
        // Fetch progress for the newly added goal
        final progress = await ApiService.getGoalProgress(newGoal.id);
        _goalProgress.addAll(progress);
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
      final success = await ApiService.deleteGoal(goalId);
      if (success) {
        _goals.removeWhere((goal) => goal.id == goalId);
        _goalProgress.removeWhere((progress) => progress.goalId == goalId);
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting goal: $e');
      // Optionally show an error message to the user
    }
  }

  // Add or update goal progress
  Future<bool> updateGoalProgress(GoalProgress progress) async {
    try {
      bool success;
      final existingIndex = _goalProgress.indexWhere(
        (p) => p.goalId == progress.goalId && p.date == progress.date,
      );
      
      if (existingIndex >= 0) {
        success = await ApiService.updateGoalProgress(progress);
        if (success) {
          _goalProgress[existingIndex] = progress;
        }
      } else {
        success = await ApiService.createGoalProgress(progress);
        if (success) {
          _goalProgress.add(progress);
        }
      }
      
      if (success) {
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('Error updating goal progress: $e');
      return false;
    }
  }

  // Toggle goal progress for a specific date
  Future<bool> toggleGoalProgress(String goalId, String date, String userId) async {
    try {
      final success = await ApiService.toggleGoalProgress(goalId, date, userId);
      
      if (success) {
        // Update local state by reloading progress for this goal
        final progressList = await ApiService.getGoalProgress(goalId);
        
        // Remove existing progress for this goal
        _goalProgress.removeWhere((p) => p.goalId == goalId);
        
        // Add updated progress
        _goalProgress.addAll(progressList);
        
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      print('Error toggling goal progress: $e');
      return false;
    }
  }

  // Set goal progress for a specific date to a specific status
  Future<bool> setGoalProgress(String goalId, String date, String userId, bool completed) async {
    try {
      print('Setting goal progress for goal $goalId on date $date to $completed for user $userId');
      
      // Optimistically update the UI
      final optimisticProgress = GoalProgress(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        goalId: goalId,
        date: date,
        completed: completed,
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Check if progress already exists for this date and goal
      final existingIndex = _goalProgress.indexWhere(
        (p) => p.goalId == goalId && p.date == date && p.userId == userId,
      );
      
      if (existingIndex >= 0) {
        // Update existing progress
        final existingProgress = _goalProgress[existingIndex];
        final updatedProgress = existingProgress.copyWith(
          completed: completed,
          updatedAt: DateTime.now(),
        );
        _goalProgress[existingIndex] = updatedProgress;
      } else {
        // Add new progress
        _goalProgress.add(optimisticProgress);
      }
      
      notifyListeners();
      
      // Now make the actual API call
      bool success;
      if (existingIndex >= 0) {
        // Update existing progress
        final existingProgress = _goalProgress[existingIndex];
        success = await ApiService.updateGoalProgress(existingProgress);
      } else {
        // Create new progress
        success = await ApiService.createGoalProgress(optimisticProgress);
      }
      
      if (!success) {
        // Revert the optimistic update if the API call fails
        if (existingIndex >= 0) {
          // Revert to previous state
          final existingProgress = _goalProgress[existingIndex];
          final revertedProgress = existingProgress.copyWith(
            completed: !completed, // Revert to previous state
            updatedAt: DateTime.now(),
          );
          _goalProgress[existingIndex] = revertedProgress;
        } else {
          // Remove the newly added progress
          _goalProgress.removeWhere(
            (p) => p.goalId == goalId && p.date == date && p.userId == userId,
          );
        }
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      print('Error setting goal progress: $e');
      return false;
    }
  }

  // Get progress for a specific goal and date
  GoalProgress? getProgressForDate(String goalId, String date) {
    try {
      return _goalProgress.firstWhere(
        (p) => p.goalId == goalId && p.date == date,
      );
    } catch (e) {
      return null;
    }
  }

  // Calculate progress percentage for a goal (last 7 days)
  double calculateGoalProgress(String goalId) {
    final now = DateTime.now();
    int completedDays = 0;
    int totalDays = 7;

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final progress = getProgressForDate(goalId, dateString);
      
      if (progress != null && progress.completed) {
        completedDays++;
      }
    }

    return (completedDays / totalDays) * 100;
  }
}
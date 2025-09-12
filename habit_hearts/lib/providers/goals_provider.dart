import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../models/goal_progress.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';

class GoalsProvider with ChangeNotifier {
  List<Goal> _goals = [];
  List<GoalProgress> _goalProgress = [];

  List<Goal> get goals => _goals;
  List<GoalProgress> get goalProgress => _goalProgress;

  // Load goals and progress from API
  Future<void> loadGoals(BuildContext context) async {
    try {
      final authProvider = Provider.of<HabitHeartsAuthProvider>(context, listen: false);
      if (authProvider.user == null) return;
      
      // Load goals from API
      final goals = await ApiService.getGoals(authProvider.user!.uid);
      _goals = goals;
      
      // Load progress for each goal
      _goalProgress = [];
      for (var goal in _goals) {
        final progress = await ApiService.getGoalProgress(goal.id);
        _goalProgress.addAll(progress);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading goals: $e');
    }
  }

  // Add a new goal
  Future<bool> addGoal(Goal goal) async {
    try {
      final success = await ApiService.createGoal(goal);
      if (success) {
        _goals.add(goal);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding goal: $e');
      return false;
    }
  }

  // Update a goal
  Future<bool> updateGoal(Goal updatedGoal) async {
    try {
      final success = await ApiService.updateGoal(updatedGoal);
      if (success) {
        _goals = _goals.map((goal) {
          if (goal.id == updatedGoal.id) {
            return updatedGoal;
          }
          return goal;
        }).toList();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating goal: $e');
      return false;
    }
  }

  // Delete a goal
  Future<bool> deleteGoal(String goalId) async {
    try {
      final success = await ApiService.deleteGoal(goalId);
      if (success) {
        _goals.removeWhere((goal) => goal.id == goalId);
        // Also remove associated progress
        _goalProgress.removeWhere((progress) => progress.goalId == goalId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting goal: $e');
      return false;
    }
  }

  // Toggle goal completion
  Future<bool> toggleGoalCompletion(String goalId) async {
    try {
      final goal = _goals.firstWhere((g) => g.id == goalId);
      final updatedGoal = goal.copyWith(completed: !goal.completed);
      return await updateGoal(updatedGoal);
    } catch (e) {
      print('Error toggling goal completion: $e');
      return false;
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
      
      // First try to get existing progress from API
      final progressList = await ApiService.getGoalProgress(goalId);
      print('Retrieved ${progressList.length} progress items for goal $goalId');
      
      final existingProgress = progressList.firstWhere(
        (p) => p.date == date && p.userId == userId,
        orElse: () => GoalProgress(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          goalId: goalId,
          date: date,
          completed: false,
          userId: userId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      
      print('Existing progress: ${existingProgress.id}, completed: ${existingProgress.completed}');
      
      // Set completion status
      final updatedProgress = existingProgress.copyWith(
        completed: completed,
        updatedAt: DateTime.now(),
      );
      
      print('Updated progress: ${updatedProgress.id}, completed: ${updatedProgress.completed}');
      
      // Update or create progress
      bool success;
      if (existingProgress.id == updatedProgress.id && 
          existingProgress.createdAt.millisecondsSinceEpoch == updatedProgress.createdAt.millisecondsSinceEpoch) {
        // This is a new progress item
        print('Creating new progress item');
        success = await ApiService.createGoalProgress(updatedProgress);
      } else {
        // This is an existing progress item
        print('Updating existing progress item');
        success = await ApiService.updateGoalProgress(updatedProgress);
      }
      
      print('API call success: $success');
      
      if (success) {
        // Update local state
        final localIndex = _goalProgress.indexWhere(
          (p) => p.goalId == goalId && p.date == date && p.userId == userId,
        );
        
        if (localIndex >= 0) {
          print('Updating existing progress in local state');
          _goalProgress[localIndex] = updatedProgress;
        } else {
          print('Adding new progress to local state');
          _goalProgress.add(updatedProgress);
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
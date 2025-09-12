import 'dart:async';
import '../models/goal.dart';
import '../services/api_service.dart';

class GoalService {
  // Get goals for user and linked users
  Stream<List<Goal>> getGoals(String userId, List<String> linkedUserIds) {
    try {
      // For now, we'll create a simple stream that fetches goals once
      // In a real implementation, you might want to implement polling or WebSockets
      StreamController<List<Goal>> controller = StreamController();
      
      // Fetch goals - this would need to be implemented in the backend
      // For now, we'll return an empty list
      controller.add([]);
      controller.close();
      
      return controller.stream;
    } catch (e) {
      print('Error getting goals: $e');
      return Stream.value([]);
    }
  }

  // Create a new goal
  Future<void> createGoal(Goal goal) async {
    try {
      await ApiService.createGoal(goal);
    } catch (e) {
      print('Error creating goal: $e');
    }
  }

  // Update a goal
  Future<void> updateGoal(Goal goal) async {
    try {
      await ApiService.updateGoal(goal);
    } catch (e) {
      print('Error updating goal: $e');
    }
  }

  // Delete a goal
  Future<void> deleteGoal(String goalId) async {
    try {
      await ApiService.deleteGoal(goalId);
    } catch (e) {
      print('Error deleting goal: $e');
    }
  }

  // Toggle goal completion
  Future<void> toggleGoalCompletion(Goal goal) async {
    try {
      // Update the goal with toggled completion status
      Goal updatedGoal = goal.copyWith(
        completed: !goal.completed,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await updateGoal(updatedGoal);
    } catch (e) {
      print('Error toggling goal completion: $e');
    }
  }
}
import 'dart:async';
import '../models/goal.dart';
import '../services/api_service.dart';

class GoalService {
  // Get goals for user and linked users
  Stream<List<Goal>> getGoals(String userId, List<String> linkedUserIds) {
    try {
      StreamController<List<Goal>> controller = StreamController();

      Future<void> fetchGoals() async {
        try {
          List<Goal> allGoals = [];
          List<String> allUserIds = [userId, ...linkedUserIds];

          for (String id in allUserIds) {
            List<Goal> userGoals = await ApiService.getGoals(id);
            allGoals.addAll(userGoals);
          }

          controller.add(allGoals);
          controller.close();
        } catch (error) {
          print('Error getting goals: $error');
          controller.add([]);
          controller.close();
        }
      }

      fetchGoals();

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
        updatedAt: DateTime.now(),
      );
      await updateGoal(updatedGoal);
    } catch (e) {
      print('Error toggling goal completion: $e');
    }
  }
}
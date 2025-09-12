import 'dart:async';
import '../models/goal_progress.dart';
import '../services/api_service.dart';

class GoalProgressService {
  // Get progress for a specific goal
  Stream<List<GoalProgress>> getGoalProgress(String goalId) {
    try {
      // For now, we'll create a simple stream that fetches progress once
      // In a real implementation, you might want to implement polling or WebSockets
      StreamController<List<GoalProgress>> controller = StreamController();
      
      // Fetch progress - this would need to be implemented in the backend
      // For now, we'll return an empty list
      controller.add([]);
      controller.close();
      
      return controller.stream;
    } catch (e) {
      print('Error getting goal progress: $e');
      return Stream.value([]);
    }
  }

  // Get progress for multiple goals
  Stream<List<GoalProgress>> getGoalsProgress(List<String> goalIds, String userId) {
    try {
      // For now, we'll create a simple stream that fetches progress once
      // In a real implementation, you might want to implement polling or WebSockets
      StreamController<List<GoalProgress>> controller = StreamController();
      
      // Fetch progress - this would need to be implemented in the backend
      // For now, we'll return an empty list
      controller.add([]);
      controller.close();
      
      return controller.stream;
    } catch (e) {
      print('Error getting goals progress: $e');
      return Stream.value([]);
    }
  }

  // Update goal progress for a specific date
  Future<void> updateGoalProgress(GoalProgress progress) async {
    try {
      await ApiService.updateGoalProgress(progress);
    } catch (e) {
      print('Error updating goal progress: $e');
    }
  }

  // Toggle goal progress for a specific date
  Future<void> toggleGoalProgress(String goalId, String date, String userId) async {
    try {
      await ApiService.toggleGoalProgress(goalId, date, userId);
    } catch (e) {
      print('Error toggling goal progress: $e');
    }
  }
}
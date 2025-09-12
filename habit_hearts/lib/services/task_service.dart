import 'dart:async';
import '../models/task.dart';
import '../services/api_service.dart';

class TaskService {
  // Get tasks for a specific date
  Stream<List<Task>> getTasksForDate(String userId, List<String> linkedUserIds, DateTime date) {
    try {
      // For now, we'll create a simple stream that fetches tasks once
      // In a real implementation, you might want to implement polling or WebSockets
      StreamController<List<Task>> controller = StreamController();
      
      // Fetch tasks for the user only (simplified for now)
      ApiService.getTasksForDate(userId, date).then((tasks) {
        controller.add(tasks);
        controller.close();
      }).catchError((error) {
        print('Error getting tasks: $error');
        controller.add([]);
        controller.close();
      });
      
      return controller.stream;
    } catch (e) {
      print('Error getting tasks: $e');
      return Stream.value([]);
    }
  }

  // Create a new task
  Future<void> createTask(Task task) async {
    try {
      await ApiService.createTask(task);
    } catch (e) {
      print('Error creating task: $e');
    }
  }

  // Update a task
  Future<void> updateTask(Task task) async {
    try {
      await ApiService.updateTask(task);
    } catch (e) {
      print('Error updating task: $e');
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await ApiService.deleteTask(taskId);
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(Task task) async {
    try {
      // Update the task with toggled completion status
      Task updatedTask = task.copyWith(
        completed: !task.completed,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await updateTask(updatedTask);
    } catch (e) {
      print('Error toggling task completion: $e');
    }
  }
}
import 'dart:async';
import '../models/task.dart';
import '../services/api_service.dart';

class TaskService {
  // Get tasks for a specific date
  Stream<List<Task>> getTasksForDate(String userId, List<String> linkedUserIds, DateTime date) {
    try {
      StreamController<List<Task>> controller = StreamController();

      Future<void> fetchTasks() async {
        try {
          List<Task> allTasks = [];
          List<String> allUserIds = [userId, ...linkedUserIds];

          for (String id in allUserIds) {
            List<Task> userTasks = await ApiService.getTasksForDate(id, date);
            allTasks.addAll(userTasks);
          }

          controller.add(allTasks);
          controller.close();
        } catch (error) {
          print('Error getting tasks: $error');
          controller.add([]);
          controller.close();
        }
      }

      fetchTasks();

      return controller.stream;
    } catch (e) {
      print('Error getting tasks: $e');
      return Stream.value([]);
    }
  }

  // Create a new task
  Future<Task?> createTask(Task task) async {
    try {
      return await ApiService.createTask(task);
    } catch (e) {
      print('Error creating task: $e');
      return null;
    }
  }

  // Update a task
  Future<Task?> updateTask(Task task) async {
    try {
      return await ApiService.updateTask(task);
    } catch (e) {
      print('Error updating task: $e');
      return null;
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
  Future<Task?> toggleTaskCompletion(Task task) async {
    try {
      // Update the task with toggled completion status
      Task updatedTask = task.copyWith(
        completed: !task.completed,
        updatedAt: DateTime.now(),
      );
      return await updateTask(updatedTask);
    } catch (e) {
      print('Error toggling task completion: $e');
      return null;
    }
  }
}
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import 'habit_hearts_auth_provider.dart'; // Assuming this is needed for userId

class TasksProvider with ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _userId; // To store the current user's ID

  DateTime get selectedDate => _selectedDate;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  // Initialize with user ID
  void setUserId(String? userId) {
    if (_userId != userId) {
      _userId = userId;
      // Optionally load tasks for the current date when user changes
      if (_userId != null) {
        loadTasksForDate(_selectedDate);
      } else {
        _tasks = []; // Clear tasks if no user
        notifyListeners();
      }
    }
  }

  Future<void> loadTasksForDate(DateTime date) async {
    if (_userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      print('Loading tasks for date: $date, user: $_userId');
      final fetchedTasks = await ApiService.getTasksForDate(_userId!, date);
      print('Loaded ${fetchedTasks.length} tasks from API');
      _tasks = fetchedTasks;
    } catch (e) {
      print('Error loading tasks: $e');
      _tasks = []; // Clear tasks on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedDate(DateTime date) {
    if (_selectedDate.year != date.year ||
        _selectedDate.month != date.month ||
        _selectedDate.day != date.day) {
      _selectedDate = date;
      loadTasksForDate(date); // Load tasks for the new date
      // notifyListeners(); // loadTasksForDate will call notifyListeners
    }
  }

  Future<Task?> addTask(Task newTask) async {
    if (_userId == null) return null;

    try {
      final createdTask = await ApiService.createTask(newTask);
      if (createdTask != null) {
        // If the task is for the currently selected date, add it to the list
        if (createdTask.dueDate != null &&
            createdTask.dueDate!.year == _selectedDate.year &&
            createdTask.dueDate!.month == _selectedDate.month &&
            createdTask.dueDate!.day == _selectedDate.day) {
          _tasks.add(createdTask);
          _tasks.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? '')); // Sort by start time
          notifyListeners();
        }
      }
      return createdTask;
    } catch (e) {
      print('Error adding task in provider: $e');
      return null;
    }
  }

  Future<Task?> updateTask(Task updatedTask) async {
    if (_userId == null) return null;

    final originalTaskIndex = _tasks.indexWhere((t) => t.id == updatedTask.id);
    Task? originalTask;

    if (originalTaskIndex != -1) {
      originalTask = _tasks[originalTaskIndex];
      // Optimistically update the UI
      _tasks[originalTaskIndex] = updatedTask;
      _tasks.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? '')); // Sort by start time
      notifyListeners();
    }

    try {
      final result = await ApiService.updateTask(updatedTask);
      if (result == null && originalTask != null) {
        // Revert the change if the API call fails
        if (originalTaskIndex != -1) {
          _tasks[originalTaskIndex] = originalTask;
          _tasks.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? '')); // Sort by start time
          notifyListeners();
        }
        print('Error updating task: API call failed, reverted UI.');
      } else if (result != null && originalTaskIndex != -1) {
        // If API call succeeds, ensure the list is updated with the actual result (e.g., if backend modified it)
        _tasks[originalTaskIndex] = result;
        _tasks.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? '')); // Sort by start time
        notifyListeners();
      }
      return result;
    } catch (e) {
      print('Error updating task in provider: $e');
      // Revert the change on error
      if (originalTask != null && originalTaskIndex != -1) {
        _tasks[originalTaskIndex] = originalTask;
        _tasks.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? '')); // Sort by start time
        notifyListeners();
      }
      return null;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    if (_userId == null) return false;

    try {
      final success = await ApiService.deleteTask(taskId);
      if (success) {
        _tasks.removeWhere((t) => t.id == taskId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('Error deleting task in provider: $e');
      return false;
    }
  }
}

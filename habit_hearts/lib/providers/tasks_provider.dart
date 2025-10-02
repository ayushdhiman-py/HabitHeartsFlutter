import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';
import 'habit_hearts_auth_provider.dart'; // Assuming this is needed for userId

class TasksProvider with ChangeNotifier {
  DateTime _selectedDate = DateTime.now();
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _userId; // To store the current user's ID
  HabitHeartsAuthProvider? _authProvider;
  final TaskService _taskService = TaskService();

  DateTime get selectedDate => _selectedDate;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  // Initialize with user ID and auth provider
  void setUserId(String? userId) {
    _userId = userId;
  }
  
  void update(HabitHeartsAuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      loadTasksForDate(_selectedDate);
    } else {
      _tasks = [];
      notifyListeners();
    }
  }

  Future<void> loadTasksForDate(DateTime date) async {
    if (_userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      print('Loading tasks for date: $date, user: $_userId');
      
      // Load tasks for current user
      List<Task> allTasks = [];
      final myTasks = await ApiService.getTasksForDate(_userId!, date);
      allTasks.addAll(myTasks);
      
      // Load shared tasks from linked users
      if (_authProvider != null && _authProvider!.habitHeartsUser != null) {
        for (String linkedId in _authProvider!.habitHeartsUser!.linkedUsers) {
          try {
            final linkedUserTasks = await ApiService.getTasksForDate(linkedId, date);
            // Filter out tasks that are already in the current user's tasks to prevent duplicates
            final sharedTasks = linkedUserTasks.where((task) => task.isShared && 
                !allTasks.any((existingTask) => existingTask.id == task.id));
            allTasks.addAll(sharedTasks);
          } catch (e) {
            print('Error loading tasks for user $linkedId: $e');
          }
        }
      }
      
      print('Loaded ${allTasks.length} total tasks (${myTasks.length} my tasks, ${allTasks.length - myTasks.length} linked shared tasks)');
      // Remove duplicates by ID to avoid showing the same event multiple times
      _tasks = _removeDuplicateTasks(allTasks);
      _sortTasks(); // Sort by date/time with completed tasks at the end
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
          _sortTasks(); // Sort by date/time with completed tasks at the end
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

    // Check if the current user has permission to update this task
    final taskIndex = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      final isOwner = task.createdBy == _userId;
      final canEdit = isOwner || task.isShared; // Owner or shared tasks can be edited
      
      if (!canEdit) {
        print('User does not have permission to update task ${updatedTask.id}');
        return null;
      }
    }

    final originalTaskIndex = _tasks.indexWhere((t) => t.id == updatedTask.id);
    Task? originalTask;

    if (originalTaskIndex != -1) {
      originalTask = _tasks[originalTaskIndex];
      // Optimistically update the UI
      _tasks[originalTaskIndex] = updatedTask;
      _sortTasks(); // Sort by date/time with completed tasks at the end
      notifyListeners();
    }

    try {
      final result = await ApiService.updateTask(updatedTask);
      if (result == null && originalTask != null) {
        // Revert the change if the API call fails
        if (originalTaskIndex != -1) {
          _tasks[originalTaskIndex] = originalTask;
          _sortTasks(); // Sort by date/time with completed tasks at the end
          notifyListeners();
        }
        print('Error updating task: API call failed, reverted UI.');
      } else if (result != null && originalTaskIndex != -1) {
        // If API call succeeds, ensure the list is updated with the actual result (e.g., if backend modified it)
        _tasks[originalTaskIndex] = result;
        _sortTasks(); // Sort by date/time with completed tasks at the end
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

    // Check if the current user has permission to delete this task
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) {
      print('Task $taskId not found');
      return false;
    }
    
    final task = _tasks[taskIndex];
    final isOwner = task.createdBy == _userId;
    final canDelete = isOwner || task.isShared; // Owner or shared tasks can be deleted
    
    if (!canDelete) {
      print('User does not have permission to delete task $taskId');
      return false;
    }

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
  
  void _sortTasks() {
    _tasks.sort((a, b) {
      // First, sort by completion status - incomplete tasks first
      if (a.completed && !b.completed) return 1;
      if (!a.completed && b.completed) return -1;
      
      // If both have the same completion status, sort by time
      // If both have start times, compare start times
      if (a.startTime != null && b.startTime != null) {
        return a.startTime!.compareTo(b.startTime!);
      }
      
      // If only one has a start time, prioritize tasks with start times
      if (a.startTime != null && b.startTime == null) return -1;
      if (a.startTime == null && b.startTime != null) return 1;
      
      // If neither has start time, just sort by text
      return a.text.compareTo(b.text);
    });
  }
  
  List<Task> _removeDuplicateTasks(List<Task> tasks) {
    final seenIds = <String>{};
    return tasks.where((task) => seenIds.add(task.id)).toList();
  }
}

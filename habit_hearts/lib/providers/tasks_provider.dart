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
  // Map to track ongoing toggle operations to prevent duplicate requests
  final Map<String, bool> _toggleOperations = {};

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
      
      // Prepare list of users to fetch tasks for
      List<String> allUserIds = [_userId!]; // Start with current user
      if (_authProvider != null && _authProvider!.habitHeartsUser != null) {
        // Add linked users for shared tasks
        allUserIds.addAll(_authProvider!.habitHeartsUser!.linkedUsers);
      }
      
      // Make a single batch request for all users' tasks if backend supports it
      List<Task> allTasks = [];
      List<Task> myTasks = [];
      
      // First get current user's tasks
      myTasks = await ApiService.getTasksForDate(_userId!, date);
      allTasks.addAll(myTasks);
      
      // Then get tasks for linked users if any exist
      if (_authProvider != null && _authProvider!.habitHeartsUser != null && 
          _authProvider!.habitHeartsUser!.linkedUsers.isNotEmpty) {
        
        // Use parallel requests for linked users to improve performance
        final linkedUserIds = _authProvider!.habitHeartsUser!.linkedUsers;
        final linkedUserTasksFutures = linkedUserIds.map((linkedId) => 
          ApiService.getTasksForDate(linkedId, date)
        ).toList();
        
        final allLinkedTasksResults = await Future.wait(linkedUserTasksFutures, eagerError: false);
        
        for (int i = 0; i < linkedUserIds.length; i++) {
          try {
            final linkedUserTasks = allLinkedTasksResults[i];
            // Filter out tasks that are already in the current user's tasks to prevent duplicates
            final sharedTasks = linkedUserTasks.where((task) => task.isShared && 
                !allTasks.any((existingTask) => existingTask.id == task.id));
            allTasks.addAll(sharedTasks);
          } catch (e) {
            print('Error loading tasks for user ${linkedUserIds[i]}: $e');
          }
        }
      }
      
      print('Loaded ${allTasks.length} total tasks (${myTasks.length} my tasks, ${allTasks.length - myTasks.length} linked shared tasks)');
      // Remove duplicates by ID to avoid showing the same task multiple times
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

  Future<void> toggleTaskCompletion(String taskId) async {
    if (_userId == null) return;

    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) {
      print('Task not found: $taskId');
      return;
    }

    final originalTask = _tasks[taskIndex];
    final isOwner = originalTask.createdBy == _userId;
    final intendedCompletionState = !originalTask.completed;

    // Check if the current user has permission to toggle this task
    final isLinkedUser = _authProvider?.habitHeartsUser?.linkedUsers.contains(originalTask.createdBy) == true;
    final isSharedTask = originalTask.isShared;
    
    // Allow toggle if user is the owner OR if it's a shared task and the user is linked to the owner
    final canToggle = isOwner || (isSharedTask && isLinkedUser);
    
    if (!canToggle) {
      print('User $_userId does not have permission to toggle task $taskId');
      // Optionally, show a snackbar to the user here
      return;
    }

    // Optimistically update the UI immediately for responsive feel
    final optimisticTask = originalTask.copyWith(
      completed: intendedCompletionState,
      completedBy: intendedCompletionState ? _userId : null,
      completedByName: intendedCompletionState ? (_authProvider?.habitHeartsUser?.displayName ?? 'You') : null,
      isCompletedByLinkedUser: intendedCompletionState ? !isOwner : false,
    );
    _tasks[taskIndex] = optimisticTask;
    _sortTasks();
    notifyListeners();

    // Prevent duplicate API calls for the same task
    if (_toggleOperations[taskId] == true) {
      print('Toggle operation already in progress for task $taskId, UI updated but skipping duplicate API request');
      return;
    }
    
    // Mark this task as being toggled for API calls
    _toggleOperations[taskId] = true;

    try {
      // Send the update to the backend
      final result = await ApiService.toggleSharedTaskCompletion(taskId, intendedCompletionState);

      if (result == null) {
        // If the API call fails, revert the optimistic update
        _tasks[taskIndex] = originalTask;
        _sortTasks();
        notifyListeners();
        print('Failed to toggle task, reverted UI.');
      } else {
        // If the API call succeeds, update the task with the definitive data from the server
        final updatedTaskFromServer = originalTask.copyWith(
          completed: result['completed'],
          completedBy: result['completedBy'],
          completedByName: result['completedByName'],
          isCompletedByLinkedUser: result['completedBy'] != originalTask.createdBy,
        );
        final serverTaskIndex = _tasks.indexWhere((t) => t.id == updatedTaskFromServer.id);
        if (serverTaskIndex != -1) {
          _tasks[serverTaskIndex] = updatedTaskFromServer;
        }
        _sortTasks();
        notifyListeners();
      }
    } catch (e) {
      // If the API call throws an error, revert the optimistic update
      final errorTaskIndex = _tasks.indexWhere((t) => t.id == taskId);
      if (errorTaskIndex != -1) {
        _tasks[errorTaskIndex] = originalTask;
        _sortTasks();
        notifyListeners();
      }
      print('Error toggling task, reverted UI: $e');
    } finally {
      // Always clear the operation flag in the finally block
      _toggleOperations[taskId] = false;
    }
  }

  Future<Task?> updateTask(Task updatedTask) async {
    if (_userId == null) return null;

    final taskIndex = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (taskIndex == -1) {
      print('Task not found for update: ${updatedTask.id}');
      return null;
    }

    final originalTask = _tasks[taskIndex];
    final isOwner = originalTask.createdBy == _userId;

    if (!isOwner) {
      print('User does not have permission to update task ${updatedTask.id}');
      return null;
    }
    
    _tasks[taskIndex] = updatedTask;
    _sortTasks();
    notifyListeners();

    try {
      final result = await ApiService.updateTask(updatedTask);
      if (result == null) {
        _tasks[taskIndex] = originalTask;
        print('Error updating task: API call failed, reverted UI.');
      } else {
        _tasks[taskIndex] = result;
      }
      _sortTasks();
      notifyListeners();
      return result;
    } catch (e) {
      print('Error updating task in provider: $e');
      _tasks[taskIndex] = originalTask;
      _sortTasks();
      notifyListeners();
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
    
    // Only owners can delete tasks, linked members cannot delete shared tasks
    final canDelete = isOwner;
    
    if (!canDelete) {
      print('Only task owners can delete tasks. Task $taskId');
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
      // If both have time, compare times
      if (a.time != null && b.time != null) {
        return a.time!.compareTo(b.time!);
      }
      
      // If only one has a time, prioritize tasks with time
      if (a.time != null && b.time == null) return -1;
      if (a.time == null && b.time != null) return 1;
      
      // If neither has time, just sort by text
      return a.text.compareTo(b.text);
    });
  }
  
  List<Task> _removeDuplicateTasks(List<Task> tasks) {
    final seenIds = <String>{};
    return tasks.where((task) => seenIds.add(task.id)).toList();
  }
}

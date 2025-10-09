import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart' as habit_hearts_user;
import '../models/task.dart';
import '../models/goal.dart';
import '../models/calendar_event.dart';

class ApiService {
  // Using your IPv4 address for physical phone testing
  static String _baseUrl = 'http://10.168.124.41:3000'; // Your local network IP for phone testing
  
  // Allow dynamic base URL configuration
  static set baseUrl(String url) {
    _baseUrl = url;
  }
  
  static String get baseUrl => _baseUrl;
  static const String usersEndpoint = '/api/users';
  static const String tasksEndpoint = '/api/tasks';
  static const String goalsEndpoint = '/api/goals';
  static const String calendarEventsEndpoint = '/api/calendarEvents';
  static const String goalProgressEndpoint = '/api/goalProgress';

  // Helper method to get the current Firebase token
  static Future<String?> _getIdToken() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      // Handle specific error for unlinked provider
      if (e.toString().contains('[firebase_auth/no-such-provider]')) {
        print('User is not linked to the requested provider, signing out to prevent issues');
        await FirebaseAuth.instance.signOut();
        return null;
      } else {
        print('Error getting ID token: $e');
        return null;
      }
    }
  }

  // Helper method to create headers with authorization
  static Future<Map<String, String>> _getHeaders() async {
    String? token = await _getIdToken();
    Map<String, String> headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Simple in-memory cache
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Cache timeout (5 minutes)
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Helper method to check if cache is valid
  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }

  // Helper method to get cached data
  static T? _getCachedData<T>(String key) {
    if (_isCacheValid(key)) {
      return _cache[key] as T?;
    }
    return null;
  }

  // Helper method to set cached data
  static void _setCachedData<T>(String key, T data) {
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  // Helper method to clear cache for a specific key
  static void _clearCache(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  // Helper method to clear all cache
  static void clearAllCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // User endpoints
  static Future<habit_hearts_user.User?> getUser(String uid) async {
    final cacheKey = 'user_$uid';
    final cached = _getCachedData<habit_hearts_user.User>(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$usersEndpoint/$uid'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        // Check if response body is not empty
        if (response.body.isEmpty) {
          print('Empty response body for user: $uid');
          return null;
        }
        
        final jsonData = json.decode(response.body);
        final user = habit_hearts_user.User.fromJson(jsonData);
        _setCachedData(cacheKey, user);
        return user;
      } else if (response.statusCode == 404) {
        // User not found - this is not an error, just means the user document doesn't exist yet
        return null;
      } else {
        // For all other errors (401, 403, 500, etc.), return null instead of throwing
        // This prevents creating duplicate documents when there are network/auth errors
        print('Error getting user: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting user: $e');
      throw e; // Re-throw the error so calling methods can distinguish between "not found" and "error"
    }
  }

  static Future<bool> createUser(habit_hearts_user.User user) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$usersEndpoint'),
        headers: headers,
        body: json.encode(user.toJson()),
      );
      if (response.statusCode == 201) {
        // Clear cache when creating new user
        _clearCache('user_${user.uid}');
        return true;
      } else {
        print('Error creating user: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 401 || response.statusCode == 403) {
          // Unauthorized - token might be invalid/expired
          print('Authentication error: ${response.statusCode} - ${response.body}');
        }
      }
      return false;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  static Future<bool> updateUser(habit_hearts_user.User user) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$usersEndpoint/${user.uid}'),
        headers: headers,
        body: json.encode(user.toJson()),
      );
      if (response.statusCode == 200) {
        // Clear cache when updating user
        _clearCache('user_${user.uid}');
        return true;
      } else {
        print('Error updating user: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 401 || response.statusCode == 403) {
          // Unauthorized - token might be invalid/expired
          print('Authentication error: ${response.statusCode} - ${response.body}');
        }
      }
      return false;
    } catch (e) {
      print('Error updating user: $e');
      // Don't print the full exception as it might contain sensitive info
      return false;
    }
  }

  static Future<Map<String, dynamic>?> toggleTaskCompletionForUser(String userId, String taskId, bool completed, {DateTime? date}) async {
    
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> requestBody = {
        'completed': completed,
      };
      if (date != null) {
        requestBody['date'] = date.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/user/$userId/task/$taskId/toggle'),
        headers: headers,
        body: json.encode(requestBody),
      );
      
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Clear the task cache for the current user to ensure updated user-specific completion status is fetched
        // The userId parameter refers to the user whose task completion is being updated
        _cache.removeWhere((key, value) => key.startsWith('tasks_$userId'));
        _cacheTimestamps.removeWhere((key, value) => key.startsWith('tasks_$userId'));
        
        return responseData;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error toggling task completion for user: $e');
      print('Error details: ${e.runtimeType} - ${e.toString()}');
      return null;
    }
  }
  


  // Task endpoints
  static Future<List<Task>> getTasksForDate(String userId, DateTime date) async {
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cacheKey = 'tasks_${userId}_$dateString';
    final cached = _getCachedData<List<Task>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$tasksEndpoint/$userId/$dateString'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final tasks = jsonData.map((item) => Task.fromJson(item)).toList();
        _setCachedData(cacheKey, tasks);
        return tasks;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      print('Error getting tasks: $e');
      return [];
    }
  }

  static Future<Task?> createTask(Task task) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$tasksEndpoint'),
        headers: headers,
        body: json.encode(task.toJson()),
      );
      
      if (response.statusCode == 201) {
        // Parse the response to get the actual task with the correct ID
        final Map<String, dynamic> responseData = json.decode(response.body);
        final createdTask = Task.fromJson(responseData);
        
        // Clear cache for the date when task was created
        if (task.dueDate != null) {
          final dateString = '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}';
          _clearCache('tasks_${task.createdBy}_$dateString');
        }
        
        return createdTask;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error creating task: $e');
      return null;
    }
  }

  static Future<Task?> updateTask(Task task) async {
    try {
      final headers = await _getHeaders();
      final requestBody = json.encode(task.toJson());
      
      final response = await http.put(
        Uri.parse('$baseUrl$tasksEndpoint/${task.id}'),
        headers: headers,
        body: requestBody,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final updatedTask = Task.fromJson(responseData);
        
        // Clear cache for the date when task was updated
        if (task.dueDate != null) {
          final dateString = '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}';
          _clearCache('tasks_${task.createdBy}_$dateString');
        }
        
        return updatedTask;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error updating task: $e');
      return null;
    }
  }

  static Future<bool> deleteTask(String taskId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$tasksEndpoint/$taskId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        // Clear all task caches (since we don't know which date this task was on)
        _cache.removeWhere((key, value) => key.startsWith('tasks_'));
        _cacheTimestamps.removeWhere((key, value) => key.startsWith('tasks_'));
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return false;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  // Goal endpoints
  static Future<List<Goal>> getGoals(String userId) async {
    final cacheKey = 'goals_$userId';
    final cached = _getCachedData<List<Goal>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$goalsEndpoint/$userId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final goals = jsonData.map((item) => Goal.fromJson(item)).toList();
        _setCachedData(cacheKey, goals);
        return goals;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      print('Error getting goals: $e');
      return [];
    }
  }

  static Future<Goal?> createGoal(Goal goal) async {
    try {
      final headers = await _getHeaders();
      final requestBody = json.encode(goal.toJson());
      final response = await http.post(
        Uri.parse('$baseUrl$goalsEndpoint'),
        headers: headers,
        body: requestBody,
      );
      if (response.statusCode == 201) {
        final createdGoal = Goal.fromJson(json.decode(response.body));
        
        // Clear goals cache
        _clearCache('goals_${goal.createdBy}');
        
        return createdGoal;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error creating goal: $e');
      return null;
    }
  }

  static Future<Goal?> updateGoal(Goal goal) async {
    try {
      final headers = await _getHeaders();
      final requestBody = json.encode(goal.toJson());
      final response = await http.put(
        Uri.parse('$baseUrl$goalsEndpoint/${goal.id}'),
        headers: headers,
        body: requestBody,
      );
      if (response.statusCode == 200) {
        final updatedGoal = Goal.fromJson(json.decode(response.body));
        
        // Clear goals cache
        _clearCache('goals_${goal.createdBy}');
        
        return updatedGoal;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error updating goal: $e');
      return null;
    }
  }

  static Future<bool> deleteGoal(String goalId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$goalsEndpoint/$goalId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        // Clear goals cache
        _cache.removeWhere((key, value) => key.startsWith('goals_'));
        _cacheTimestamps.removeWhere((key, value) => key.startsWith('goals_'));
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return false;
    } catch (e) {
      print('Error deleting goal: $e');
      return false;
    }
  }

  /// Removes a user's progress for a specific goal.
  /// This requires a corresponding DELETE endpoint in your backend API.
  static Future<bool> removeGoalProgressForUser(String userId, String goalId) async {
    try {
      // Example endpoint: DELETE /api/users/{userId}/goal-progress/{goalId}
      final response = await http.delete(
        Uri.parse('$baseUrl$usersEndpoint/$userId/goal-progress/$goalId'),
        headers: {'Content-Type': 'application/json'},
      );

      // A 200 OK or 204 No Content are both acceptable success statuses.
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Clear user cache
        _clearCache('user_$userId');
        return true;
      }
      return false;
    } catch (e) {
      // Return false to indicate failure, which will prevent the main goal from being deleted.
      return false;
    }
  }

  // Calendar event endpoints
  static Future<List<CalendarEvent>> getCalendarEvents(String userId, DateTime startDate, DateTime endDate) async {
    final startString = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final endString = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final cacheKey = 'calendar_${userId}_${startString}_${endString}';
    final cached = _getCachedData<List<CalendarEvent>>(cacheKey);
    if (cached != null) {
      return cached;
    }
    
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl$calendarEventsEndpoint/$userId?startDate=$startString&endDate=$endString'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        final events = jsonData.map((item) => CalendarEvent.fromJson(item)).toList();
        _setCachedData(cacheKey, events);
        return events;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      print('Error getting calendar events: $e');
      return [];
    }
  }

  static Future<CalendarEvent?> createCalendarEvent(CalendarEvent event) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$calendarEventsEndpoint'),
        headers: headers,
        body: json.encode(event.toJson()),
      );
      if (response.statusCode == 201) {
        final createdEvent = CalendarEvent.fromJson(json.decode(response.body));
        
        // Clear calendar cache
        _cache.removeWhere((key, value) => key.startsWith('calendar_${event.createdBy}'));
        _cacheTimestamps.removeWhere((key, value) => key.startsWith('calendar_${event.createdBy}'));
        
        return createdEvent;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error creating calendar event: $e');
      return null;
    }
  }

  static Future<bool> updateCalendarEvent(CalendarEvent event) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$calendarEventsEndpoint/${event.id}'),
        headers: headers,
        body: json.encode(event.toJson()),
      );
      if (response.statusCode == 200) {
        // Clear calendar cache
        _cache.removeWhere((key, value) => key.startsWith('calendar_${event.createdBy}'));
        _cacheTimestamps.removeWhere((key, value) => key.startsWith('calendar_${event.createdBy}'));
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return false;
    } catch (e) {
      print('Error updating calendar event: $e');
      return false;
    }
  }

  static Future<bool> deleteCalendarEvent(String eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$calendarEventsEndpoint/$eventId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        // Clear calendar cache
        _cache.removeWhere((key, value) => key.startsWith('calendar_'));
        _cacheTimestamps.removeWhere((key, value) => key.startsWith('calendar_'));
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return false;
    } catch (e) {
      print('Error deleting calendar event: $e');
      return false;
    }
  }

  // Removed old goalProgress endpoints - now using bit-based approach in user documents
  
  // New endpoint for toggling goal progress using bit-based approach
  static Future<Map<String, dynamic>?> toggleSharedTaskCompletion(String taskId, bool completed) async {
    
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> requestBody = {
        'completed': completed,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/toggle-shared-completion'),
        headers: headers,
        body: json.encode(requestBody),
      );
      
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Clear the task cache for all users affected by this shared task
        // We don't know who created the task, so we clear all task caches
        _cache.removeWhere((key, value) => key.startsWith('tasks_'));
        _cacheTimestamps.removeWhere((key, value) => key.startsWith('tasks_'));
        
        return responseData;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error toggling shared task completion: $e');
      print('Error details: ${e.runtimeType} - ${e.toString()}');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> toggleGoalProgressForUser(String userId, String goalId, bool completed, {DateTime? date}) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> requestBody = {
        'completed': completed,
      };
      if (date != null) {
        requestBody['date'] = date.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/user/$userId/goal/$goalId/toggle'),
        headers: headers,
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        
        // Clear user cache
        _clearCache('user_$userId');
        // Clear goals cache
        _clearCache('goals_$userId');
        
        return result;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error toggling goal progress: $e');
      return null;
    }
  }

  // New endpoint for toggling shared goal completion with shared status but individual streaks
  static Future<Map<String, dynamic>?> toggleSharedGoalCompletion(String goalId, bool completed) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> requestBody = {
        'completed': completed,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/goals/$goalId/toggle-shared-completion'),
        headers: headers,
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        
        // Clear user cache
        _clearCache('user_${result['userId']}');
        // Clear goals cache
        _clearCache('goals_${result['userId']}');
        
        return result;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error toggling shared goal completion: $e');
      return null;
    }
  }
  
  // Get user's goal progress data
  static Future<habit_hearts_user.User?> getUserGoalProgress(String userId) async {
    return getUser(userId);
  }

  // Get multiple users by their IDs
  static Future<Map<String, habit_hearts_user.User>> getBatchUsers(List<String> userIds) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$usersEndpoint/batch'),
        headers: headers,
        body: json.encode({'userIds': userIds}),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final Map<String, habit_hearts_user.User> users = {};
        
        jsonData.forEach((uid, userData) {
          users[uid] = habit_hearts_user.User.fromJson(userData);
        });
        
        return users;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return {};
    } catch (e) {
      print('Error getting batch users: $e');
      return {};
    }
  }

  // Link users
  static Future<bool> linkUsers(String userId, String partnerCode) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/link'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'partnerCode': partnerCode,
        }),
      );
      if (response.statusCode == 200) {
        _clearCache('user_$userId');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return false;
    } catch (e) {
      print('Error linking users: $e');
      return false;
    }
  }

  // Unlink users
  static Future<bool> unlinkUsers(String userId, String partnerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/unlink'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'partnerId': partnerId,
        }),
      );
      if (response.statusCode == 200) {
        _clearCache('user_$userId');
        _clearCache('user_$partnerId');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Unauthorized - token might be invalid/expired
        print('Authentication error: ${response.statusCode} - ${response.body}');
      }
      return false;
    } catch (e) {
      print('Error unlinking users: $e');
      return false;
    }
  }
}

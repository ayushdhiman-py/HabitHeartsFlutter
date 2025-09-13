import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart' as habit_hearts_user;
import '../models/task.dart';
import '../models/goal.dart';
import '../models/calendar_event.dart';

class ApiService {
  static const String baseUrl = 'http://10.58.73.41:3000';
  static const String usersEndpoint = '/api/users';
  static const String tasksEndpoint = '/api/tasks';
  static const String goalsEndpoint = '/api/goals';
  static const String calendarEventsEndpoint = '/api/calendarEvents';
  static const String goalProgressEndpoint = '/api/goalProgress';

  // User endpoints
  static Future<habit_hearts_user.User?> getUser(String uid) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$usersEndpoint/$uid'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return habit_hearts_user.User.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  static Future<bool> createUser(habit_hearts_user.User user) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$usersEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(user.toJson()),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  static Future<bool> updateUser(habit_hearts_user.User user) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$usersEndpoint/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(user.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  // Task endpoints
  static Future<List<Task>> getTasksForDate(String userId, DateTime date) async {
    try {
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      print('Fetching tasks for user: $userId, date: $dateString');
      final response = await http.get(Uri.parse('$baseUrl$tasksEndpoint/$userId/$dateString'));
      print('Tasks API response status: ${response.statusCode}');
      print('Tasks API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('Tasks JSON data: $jsonData');
        return jsonData.map((item) => Task.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting tasks: $e');
      return [];
    }
  }

  static Future<Task?> createTask(Task task) async {
    try {
      print('Creating task: ${task.text}, dueDate: ${task.dueDate}');
      final response = await http.post(
        Uri.parse('$baseUrl$tasksEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(task.toJson()),
      );
      print('Create task response status: ${response.statusCode}');
      print('Create task response body: ${response.body}');
      
      if (response.statusCode == 201) {
        // Parse the response to get the actual task with the correct ID
        final Map<String, dynamic> responseData = json.decode(response.body);
        print('Created task data: $responseData');
        return Task.fromJson(responseData);
      }
      return null;
    } catch (e) {
      print('Error creating task: $e');
      return null;
    }
  }

  static Future<Task?> updateTask(Task task) async {
    try {
      print('Updating task ID: ${task.id}, text: ${task.text}, completed: ${task.completed}');
      final requestBody = json.encode(task.toJson());
      print('Update task request body: $requestBody');
      final response = await http.put(
        Uri.parse('$baseUrl$tasksEndpoint/${task.id}'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );
      print('Update task response status: ${response.statusCode}');
      print('Update task response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return Task.fromJson(responseData);
      }
      return null;
    } catch (e) {
      print('Error updating task: $e');
      return null;
    }
  }

  static Future<bool> deleteTask(String taskId) async {
    try {
      print('Deleting task ID: $taskId');
      final response = await http.delete(Uri.parse('$baseUrl$tasksEndpoint/$taskId'));
      print('Delete task response status: ${response.statusCode}');
      print('Delete task response body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  // Goal endpoints
  static Future<List<Goal>> getGoals(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$goalsEndpoint/$userId'));
      print('Goals API response status: ${response.statusCode}');
      print('Goals API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        print('Goals JSON data: $jsonData');
        return jsonData.map((item) => Goal.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting goals: $e');
      return [];
    }
  }

  static Future<Goal?> createGoal(Goal goal) async {
    try {
      print('Creating goal: ${goal.text}');
      final requestBody = json.encode(goal.toJson());
      print('Create goal request body: $requestBody');
      final response = await http.post(
        Uri.parse('$baseUrl$goalsEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );
      print('Create goal response status: ${response.statusCode}');
      print('Create goal response body: ${response.body}');
      if (response.statusCode == 201) {
        return Goal.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error creating goal: $e');
      return null;
    }
  }

  static Future<Goal?> updateGoal(Goal goal) async {
    try {
      print('Updating goal ID: ${goal.id}, text: ${goal.text}, completed: ${goal.completed}');
      final requestBody = json.encode(goal.toJson());
      print('Update goal request body: $requestBody');
      final response = await http.put(
        Uri.parse('$baseUrl$goalsEndpoint/${goal.id}'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );
      print('Update goal response status: ${response.statusCode}');
      print('Update goal response body: ${response.body}');
      if (response.statusCode == 200) {
        return Goal.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error updating goal: $e');
      return null;
    }
  }

  static Future<bool> deleteGoal(String goalId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl$goalsEndpoint/$goalId'));
      return response.statusCode == 200;
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

      print('Remove goal progress response status: ${response.statusCode}');
      // A 200 OK or 204 No Content are both acceptable success statuses.
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error removing goal progress for user: $e');
      // Return false to indicate failure, which will prevent the main goal from being deleted.
      return false;
    }
  }

  // Calendar event endpoints
  static Future<List<CalendarEvent>> getCalendarEvents(String userId, DateTime startDate, DateTime endDate) async {
    try {
      final startString = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endString = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      
      final response = await http.get(
        Uri.parse('$baseUrl$calendarEventsEndpoint/$userId?startDate=$startString&endDate=$endString')
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((item) => CalendarEvent.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting calendar events: $e');
      return [];
    }
  }

  static Future<CalendarEvent?> createCalendarEvent(CalendarEvent event) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$calendarEventsEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(event.toJson()),
      );
      if (response.statusCode == 201) {
        return CalendarEvent.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error creating calendar event: $e');
      return null;
    }
  }

  static Future<bool> updateCalendarEvent(CalendarEvent event) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$calendarEventsEndpoint/${event.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(event.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating calendar event: $e');
      return false;
    }
  }

  static Future<bool> deleteCalendarEvent(String eventId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl$calendarEventsEndpoint/$eventId'));
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting calendar event: $e');
      return false;
    }
  }

  // Removed old goalProgress endpoints - now using bit-based approach in user documents
  
  // New endpoint for toggling goal progress using bit-based approach
  static Future<Map<String, dynamic>?> toggleGoalProgressForUser(String userId, String goalId, bool completed) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/$userId/goal/$goalId/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'completed': completed,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error toggling goal progress for user: $e');
      return null;
    }
  }
  
  // Get user's goal progress data
  static Future<habit_hearts_user.User?> getUserGoalProgress(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$usersEndpoint/$userId'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return habit_hearts_user.User.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      print('Error getting user goal progress: $e');
      return null;
    }
  }
}
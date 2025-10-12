import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/task.dart';
import '../models/goal.dart';
import '../models/calendar_event.dart';
import '../models/user.dart' as habit_hearts_user;
import 'api_service.dart';

class BatchApiService {
  
  // Batch method to fetch all required data in parallel
  static Future<Map<String, dynamic>> fetchAllUserData(String userId, List<String> linkedUserIds) async {
    try {
      // Create all the API requests in parallel
      final List<Future> futures = [];
      
      // Add the main user's tasks request
      futures.add(ApiService.getTasksForDate(userId, DateTime.now()));
      
      // Add goals request for the main user
      futures.add(ApiService.getGoals(userId));
      
      // Add calendar events request for the main user
      DateTime now = DateTime.now();
      DateTime startOfMonth = DateTime(now.year, now.month, 1);
      DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);
      futures.add(ApiService.getCalendarEvents(userId, startOfMonth, endOfMonth));
      
      // Add user data request for the main user
      futures.add(ApiService.getUser(userId));
      
      // Add requests for linked users (only shared data)
      if (linkedUserIds.isNotEmpty) {
        for (String linkedId in linkedUserIds) {
          // Add shared tasks from linked users
          futures.add(ApiService.getTasksForDate(linkedId, DateTime.now()));
          
          // Add shared goals from linked users
          futures.add(ApiService.getGoals(linkedId));
        }
      }
      
      // Execute all requests in parallel
      final results = await Future.wait(futures, eagerError: false);
      
      // Organize results
      final Map<String, dynamic> allData = {};
      
      int index = 0;
      allData['myTasks'] = results[index++]; // Main user tasks
      allData['myGoals'] = results[index++]; // Main user goals
      allData['myCalendarEvents'] = results[index++]; // Main user calendar events
      allData['myUserData'] = results[index++]; // Main user data
      
      // Process linked user data
      if (linkedUserIds.isNotEmpty) {
        List<Task> sharedTasks = [];
        List<Goal> sharedGoals = [];
        
        for (String linkedId in linkedUserIds) {
          // Process linked user tasks (filter for shared tasks)
          try {
            List<Task> linkedUserTasks = results[index++];
            List<Task> filteredTasks = linkedUserTasks.where((task) => task.isShared).toList();
            sharedTasks.addAll(filteredTasks);
          } catch (e) {
            print('Error getting tasks for linked user $linkedId: $e');
          }
          
          // Process linked user goals (filter for shared goals) 
          try {
            List<Goal> linkedUserGoals = results[index++];
            List<Goal> filteredGoals = linkedUserGoals.where((goal) => goal.isShared).toList();
            sharedGoals.addAll(filteredGoals);
          } catch (e) {
            print('Error getting goals for linked user $linkedId: $e');
          }
        }
        
        allData['sharedTasks'] = sharedTasks;
        allData['sharedGoals'] = sharedGoals;
      }
      
      return allData;
    } catch (e) {
      print('Error in fetchAllUserData: $e');
      throw e;
    }
  }
  
  // Specific batch method for home screen data
  static Future<Map<String, dynamic>> fetchHomeScreenData(String userId, { DateTime? date }) async {
    try {
      date ??= DateTime.now();
      
      // Create all the API requests in parallel
      final List<Future> futures = [];
      
      // Add the main user's tasks request
      futures.add(ApiService.getTasksForDate(userId, date));
      
      // Add goals request for the main user
      futures.add(ApiService.getGoals(userId));
      
      // Add user progress data
      futures.add(ApiService.getUserGoalProgress(userId));
      
      // Execute all requests in parallel
      final results = await Future.wait(futures, eagerError: false);
      
      // Organize results
      final Map<String, dynamic> allData = {};
      
      allData['tasks'] = results[0];
      allData['goals'] = results[1];
      allData['goalProgress'] = results[2];
      
      return allData;
    } catch (e) {
      print('Error in fetchHomeScreenData: $e');
      throw e;
    }
  }
}
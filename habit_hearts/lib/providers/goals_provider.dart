import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/habit_hearts_auth_provider.dart';
import '../models/user.dart' as habit_hearts_user;
import '../models/goal_progress_summary.dart';

// Extension to add firstWhereOrNull method to List
extension FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class GoalsProvider with ChangeNotifier {
  List<Goal> _goals = [];
  bool _isLoading = false;
  Map<String, Map<String, String>> _userGoalProgress = {}; // goalId -> {yearMonth -> bitString}
  Map<String, int> _currentStreaks = {}; // goalId -> streak count
  Map<String, int> _longestStreaks = {}; // goalId -> streak count
  // Map to track ongoing toggle operations to prevent duplicate requests
  final Map<String, bool> _toggleOperations = {};

  HabitHeartsAuthProvider? _authProvider;
  List<String>? _previousLinkedUsers;

  List<Goal> get goals => _goals;
  bool get isLoading => _isLoading;
  Map<String, Map<String, String>> get userGoalProgress => _userGoalProgress;
  Map<String, int> get currentStreaks => _currentStreaks;
  Map<String, int> get longestStreaks => _longestStreaks;

  void update(HabitHeartsAuthProvider authProvider) {
    // Remove previous listener if exists
    _removeAuthListener();
    
    _authProvider = authProvider;
    
    // Add listener to detect when linked users change
    _addAuthListener();
    
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      loadGoals();
    } else {
      _goals = [];
      notifyListeners();
    }
  }

  void _addAuthListener() {
    _authProvider?.addListener(_handleAuthChange);
    // Store the initial linked users
    _previousLinkedUsers = List.from(_authProvider?.habitHeartsUser?.linkedUsers ?? []);
  }

  void _removeAuthListener() {
    _authProvider?.removeListener(_handleAuthChange);
  }

  void _handleAuthChange() {
    // Check if linked users have changed
    final currentLinkedUsers = _authProvider?.habitHeartsUser?.linkedUsers ?? [];
    final previous = _previousLinkedUsers ?? [];
    
    bool linkedUsersChanged = false;
    
    if (currentLinkedUsers.length != previous.length) {
      linkedUsersChanged = true;
    } else {
      // Check if elements are the same
      Set<String> currentSet = currentLinkedUsers.toSet();
      Set<String> previousSet = previous.toSet();
      
      if (currentSet.difference(previousSet).isNotEmpty || previousSet.difference(currentSet).isNotEmpty) {
        linkedUsersChanged = true;
      }
    }
    
    if (linkedUsersChanged) {
      _previousLinkedUsers = List.from(currentLinkedUsers);
      // Reload goals to reflect the change in linked users
      loadGoals();
    }
  }

  @override
  void dispose() {
    _removeAuthListener();
    super.dispose();
  }

  // Load goals and progress from API
  Future<void> loadGoals() async {
    if (_isLoading) return;
    if (_authProvider == null || !_authProvider!.isAuthenticated) {
      return;
    }

    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      final user = _authProvider!.user;
      if (user == null) return;

      List<Goal> allGoals = [];

      // Get the current user's goals (all of them)
      List<Goal> myGoals = [];
      try {
        myGoals = await ApiService.getGoals(user.uid);
        allGoals.addAll(myGoals);
      } catch (e) {
        print('Error loading goals for user ${user.uid}: $e');
      }

      // Get linked users' shared goals using parallel requests to improve performance
      final habitHeartsUser = _authProvider?.habitHeartsUser;
      if (habitHeartsUser != null && habitHeartsUser.linkedUsers.isNotEmpty) {
        final linkedUserIds = habitHeartsUser.linkedUsers;
        final linkedUserGoalsFutures = linkedUserIds.map((linkedId) => 
          ApiService.getGoals(linkedId)
        ).toList();
        
        final allLinkedGoalsResults = await Future.wait(linkedUserGoalsFutures, eagerError: false);
        
        for (int i = 0; i < linkedUserIds.length; i++) {
          try {
            final linkedUserGoals = allLinkedGoalsResults[i];
            // Filter out goals that are already in the current user's goals to prevent duplicates
            final sharedGoals = linkedUserGoals.where((goal) => goal.isShared && 
                !allGoals.any((existingGoal) => existingGoal.id == goal.id));
            allGoals.addAll(sharedGoals);
          } catch (e) {
            print('Error loading goals for user ${linkedUserIds[i]}: $e');
          }
        }
      }
      _goals = allGoals;

      // Load user's goal progress data
      final userData = await ApiService.getUserGoalProgress(user.uid);
      if (userData != null && userData.goalProgress != null) {
        _userGoalProgress.clear();
        _currentStreaks.clear();
        _longestStreaks.clear();

        userData.goalProgress.forEach((goalId, progressSummary) {
          // Validate and fix bit string lengths for each month
          Map<String, String> validatedMonthlyData = {};
          progressSummary.monthlyData.forEach((yearMonth, bitString) {
            // Extract year and month from the yearMonth string (format: "YYYY-MM")
            final parts = yearMonth.split('-');
            if (parts.length == 2) {
              try {
                final year = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                
                // Calculate how many days are in this month
                final daysInMonth = DateTime(year, month + 1, 0).day;
                
                // Ensure the bit string has the correct length
                String validatedBitString = bitString;
                if (validatedBitString.length < daysInMonth) {
                  validatedBitString = validatedBitString.padRight(daysInMonth, '0');
                } else if (validatedBitString.length > daysInMonth) {
                  validatedBitString = validatedBitString.substring(0, daysInMonth);
                }
                
                validatedMonthlyData[yearMonth] = validatedBitString;
              } catch (e) {
                // If parsing fails, use the original bitString
                validatedMonthlyData[yearMonth] = bitString;
              }
            } else {
              // If yearMonth format is unexpected, use the original bitString
              validatedMonthlyData[yearMonth] = bitString;
            }
          });
          
          _userGoalProgress[goalId] = validatedMonthlyData;
          _currentStreaks[goalId] = progressSummary.currentStreak;
          _longestStreaks[goalId] = progressSummary.longestStreak;
        });
      }
    } catch (e) {
      print('Error loading goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new goal
  Future<void> addGoal(BuildContext context, Map<String, dynamic> goalData) async {
    try {
      final now = DateTime.now();
      final goal = Goal(
        id: '', // ID will be assigned by Firestore
        text: goalData['text'],
        completed: false,
        createdBy: goalData['createdBy'],
        creatorName: goalData['creatorName'],
        createdAt: now,
        updatedAt: now,
        status: 'active',
        emoji: goalData['emoji'],
        startDate: goalData['startDate'],
        endDate: goalData['endDate'],
        isHabit: goalData['isHabit'],
      );

      // This will trigger validation in the createGoal method
      final newGoal = await ApiService.createGoal(goal);
      if (newGoal != null) {
        _goals.add(newGoal);
        notifyListeners();
      }
    } catch (e) {
      print('Error adding goal: $e');
      rethrow; // Rethrow to let the UI handle it
    }
  }

  // Update a goal
  Future<void> updateGoal(BuildContext context, Goal updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index == -1) return;

    final originalGoal = _goals[index];
    _goals[index] = updatedGoal;
    notifyListeners();

    // Check if the current user has permission to update this goal (only creator can update)
    final userId = _authProvider?.user?.uid;
    if (userId != null) {
      final goal = _goals[index];
      final isOwner = goal.createdBy == userId;
      
      if (!isOwner) {
        print('User does not have permission to update goal ${updatedGoal.id}');
        // Revert the UI change
        _goals[index] = originalGoal;
        notifyListeners();
        return;
      }
    }

    try {
      final result = await ApiService.updateGoal(updatedGoal);
      if (result == null) {
        // Revert if the API call fails
        _goals[index] = originalGoal;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating goal: $e');
      // Revert on error
      _goals[index] = originalGoal;
      notifyListeners();
    }
  }

  // Delete a goal
  Future<void> deleteGoal(BuildContext context, String goalId) async {
    try {
      final userId = _authProvider?.user?.uid;

      if (userId == null) {
        throw Exception("User not logged in.");
      }

      // Find the goal to check permissions
      final goalIndex = _goals.indexWhere((g) => g.id == goalId);
      if (goalIndex == -1) {
        print('Goal $goalId not found');
        return;
      }
      
      final goal = _goals[goalIndex];

      // Check if the current user has permission to delete this goal (only creator can delete)
      final isOwner = goal.createdBy == userId;
      
      if (!isOwner) {
        print('User does not have permission to delete goal $goalId');
        return;
      }

      // Optimistically remove from UI
      _goals.removeWhere((goal) => goal.id == goalId);
      notifyListeners();

      // Call API to delete
      final goalDeletionSuccess = await ApiService.deleteGoal(goalId);
      final progressDeletionSuccess = await ApiService.removeGoalProgressForUser(userId, goalId);

      if (!goalDeletionSuccess || !progressDeletionSuccess) {
        // If either fails, reload goals to revert UI
        await loadGoals();
      }
    } catch (e) {
      print('Error deleting goal: $e');
      await loadGoals();
    }
  }

  // Toggle goal progress for a specific date (NEW: Bit-based approach)
  Future<bool> toggleGoalProgressForUser(String userId, String goalId, bool completed) async {
    try {
      final result = await ApiService.toggleGoalProgressForUser(userId, goalId, completed);

      if (result != null) {
        // Update local state with new data
        if (result['currentStreak'] != null) {
          _currentStreaks[goalId] = result['currentStreak'];
        }
        if (result['longestStreak'] != null) {
          _longestStreaks[goalId] = result['longestStreak'];
        }
        if (result['monthlyData'] != null) {
          _userGoalProgress[goalId] = Map<String, String>.from(result['monthlyData']);
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      print('Error toggling goal progress for user: $e');
      return false;
    }
  }

  // Calculate current streak locally based on the provided progress data
  int _calculateCurrentStreakLocal(String goalId, Map<String, Map<String, String>> progressData) {
    final goal = _goals.firstWhereOrNull((g) => g.id == goalId);
    if (goal == null || !goal.isHabit) return 0; // Only habits have streaks

    int streak = 0;
    DateTime currentDate = DateTime.now();

    // Iterate backwards from today to find consecutive completed days
    while (true) {
      final yearMonth = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}';
      final day = currentDate.day;

      if (progressData.containsKey(goalId) &&
          progressData[goalId]!.containsKey(yearMonth)) {
        final bitString = progressData[goalId]![yearMonth]!;
        if (day >= 1 && day <= bitString.length) {
          final index = day - 1;
          if (bitString[index] == '1') {
            streak++;
            currentDate = currentDate.subtract(const Duration(days: 1));
          } else {
            break; // Streak broken
          }
        } else {
          break; // Day out of bounds for bit string
        }
      } else {
        break; // No progress data for this month
      }
    }
    return streak;
  }

  // Optimistically toggle goal progress for a specific day (used by UI components)
  Future<void> toggleHeatmapDayCompletion(String goalId, DateTime date, bool completed) async {
    final userId = _authProvider?.user?.uid;
    if (userId == null) return;

    // Find the goal to check permissions
    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) {
      print('Goal not found: $goalId');
      return;
    }
    
    final goal = _goals[goalIndex];
    final isOwner = goal.createdBy == userId;
    final isLinkedUser = _authProvider?.habitHeartsUser?.linkedUsers.contains(goal.createdBy) == true;
    final isSharedGoal = goal.isShared;
    
    // Allow toggle if user is the owner OR if it's a shared goal and the user is linked to the owner
    final canToggle = isOwner || (isSharedGoal && isLinkedUser);
    
    if (!canToggle) {
      print('User $userId does not have permission to toggle progress for goal $goalId');
      return;
    }

    // Store original progress for rollback
    final originalProgress = Map<String, Map<String, String>>.from(_userGoalProgress);

    // Optimistically update local state and UI
    _optimisticallyUpdateHeatmapLocal(userId, goalId, date, completed);

    try {
      // Call API to update progress for the specific day
      final result = await ApiService.toggleGoalProgressForUser(userId, goalId, completed, date: date);

      if (result == null) {
        // If API call fails, revert local state
        _userGoalProgress = originalProgress;
        notifyListeners();
        print('Failed to update heatmap day, reverted UI.');
      } else {
        // Update streaks from API response
        if (result['currentStreak'] != null) {
          _currentStreaks[goalId] = result['currentStreak'];
        }
        if (result['longestStreak'] != null) {
          _longestStreaks[goalId] = result['longestStreak'];
        }
        // The monthlyData should already be updated by _optimisticallyUpdateHeatmapLocal
        // but we can re-sync if the API returns a more accurate monthlyData
        if (result['monthlyData'] != null) {
          _userGoalProgress[goalId] = Map<String, String>.from(result['monthlyData']);
        }
        notifyListeners();
      }
    } catch (e) {
      // If API call throws an error, revert local state
      _userGoalProgress = originalProgress;
      notifyListeners();
      print('Error updating heatmap day, reverted UI: $e');
    }
  }

  // Optimistically update the UI for a specific day (used by heatmap for instant feedback)
  void _optimisticallyUpdateHeatmapLocal(String userId, String goalId, DateTime date, bool completed) {
    final yearMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final day = date.day;

    // Calculate number of days in this month for proper bit string length
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;

    // Create a deep copy of the progress data to modify
    final updatedProgress = Map<String, Map<String, String>>.from(
      _userGoalProgress.map(
        (key, value) => MapEntry(key, Map<String, String>.from(value)),
      ),
    );

    // Initialize the goal entry if it doesn't exist
    if (!updatedProgress.containsKey(goalId)) {
      updatedProgress[goalId] = {};
    }

    // Initialize the month entry if it doesn't exist
    if (!updatedProgress[goalId]!.containsKey(yearMonth)) {
      // For new months, initialize with the correct number of days (all set to '0')
      updatedProgress[goalId]![yearMonth] = '0' * daysInMonth;
    }

    // Get the current bit string for the month
    String bitString = updatedProgress[goalId]![yearMonth]!;

    // Ensure the bit string has the correct length for this month
    if (bitString.length < daysInMonth) {
      bitString = bitString.padRight(daysInMonth, '0');
    } else if (bitString.length > daysInMonth) {
      // Truncate if longer than the days in the month
      bitString = bitString.substring(0, daysInMonth);
    }

    // Update the bit for the current day
    final index = day - 1;
    final newBitString = bitString.replaceRange(index, index + 1, completed ? '1' : '0');

    // Update the progress data
    updatedProgress[goalId]![yearMonth] = newBitString;

    // Update the state and notify listeners
    _userGoalProgress = updatedProgress;
    notifyListeners();
  }

  // Optimistically toggle entire goal completion status (used by goal items)
  Future<void> optimisticallyToggleGoalProgress(String userId, String goalId, bool completed, {bool updateGoalStatus = true}) async {
    // Check if goal exists first
    final goalIndex = _goals.indexWhere((g) => g.id == goalId);
    if (goalIndex == -1) {
      print('Goal $goalId not found');
      return;
    }
    
    // Optimistically update the UI immediately for responsive feel
    final goal = _goals[goalIndex];
    final originalGoal = goal;
    final optimisticGoal = goal.copyWith(completed: completed);
    _goals[goalIndex] = optimisticGoal;
    notifyListeners();

    // Create a key for tracking operations (userId-goalId) to prevent duplicate API calls
    String operationKey = "$goalId-$userId";
    
    // If API call is already in progress, just update UI and return
    // This allows rapid toggles to update UI immediately but prevents multiple API calls
    if (_toggleOperations[operationKey] == true) {
      print('Toggle operation already in progress for goal $goalId and user $userId, UI updated but skipping duplicate API request.');
      return;
    }
    
    // Mark this operation as in progress for API calls
    _toggleOperations[operationKey] = true;

    try {
      // Check if the current user has permission to toggle this goal
      final isOwner = goal.createdBy == userId;
      final isLinkedUser = _authProvider?.habitHeartsUser?.linkedUsers.contains(goal.createdBy) == true;
      final isSharedGoal = goal.isShared;
      
      print('Toggle attempt - UserId: $userId, GoalCreatedBy: ${goal.createdBy}, IsOwner: $isOwner, IsLinkedUser: $isLinkedUser, IsSharedGoal: $isSharedGoal');
      
      // Allow toggle if user is the owner OR if it's a shared goal and the user is linked to the owner
      final canToggle = isOwner || (isSharedGoal && isLinkedUser);
      
      if (!canToggle) {
        print('User $userId does not have permission to toggle goal $goalId');
        // Revert UI since user doesn't have permission
        _goals[goalIndex] = originalGoal;
        notifyListeners();
        return; // Don't perform the API operation
      }

      try {
        // If user is owner and wants to update the goal status, allow it
        // If user is linked user and goal is shared, update the shared completion status
        if (updateGoalStatus && isOwner) {
          // Owner can update the goal document
          final result = await ApiService.updateGoal(optimisticGoal);
          if (result == null) {
            // If API call fails, revert the UI
            _goals[goalIndex] = originalGoal;
            notifyListeners();
            print('Failed to update goal status, reverted UI.');
          } else {
            // If goal status update is successful, also update goal progress for heatmap
            // Use the current user's ID for progress tracking
            String progressUserId = userId; // Use current user's ID for their progress tracking
            await toggleGoalProgressForUser(progressUserId, goalId, completed);
            notifyListeners(); // Ensure UI updates after progress update
          }
        } else if (isSharedGoal && isLinkedUser) {
          // For linked users of shared goals, use the shared completion endpoint
          // This updates both the shared status and the individual streaks
          print('Linked user $userId updating shared goal $goalId with completed: $completed');
          final result = await ApiService.toggleSharedGoalCompletion(goalId, completed);
          if (result != null) {
            // Update local state with new streak data from the API
            if (result['currentStreak'] != null) {
              _currentStreaks[goalId] = result['currentStreak'];
            }
            if (result['longestStreak'] != null) {
              _longestStreaks[goalId] = result['longestStreak'];
            }
            
            // Update the goal's completion status based on the server response
            // Make sure we're updating with the result from the API call
            _goals[goalIndex] = _goals[goalIndex].copyWith(
              completed: result['completed'] ?? completed  // Use result value, fallback to intended value
            );
            
            // Refresh the user's individual goal progress from the API response
            // The result from toggleSharedGoalCompletion should contain updated progress data
            if (result['monthlyData'] != null && result['monthlyData'] is Map<String, String>) {
              if (!_userGoalProgress.containsKey(goalId)) {
                _userGoalProgress[goalId] = {};
              }
              _userGoalProgress[goalId]!.addAll(Map<String, String>.from(result['monthlyData']));
            }
            
            notifyListeners();
            print('Successfully updated shared goal for linked user $userId, completed: ${result['completed']}');
          } else {
            // If API call fails, revert the optimistic update
            _goals[goalIndex] = originalGoal;
            notifyListeners();
            print('Failed to update shared goal for linked user $userId, reverted UI.');
          }
        } else {
          // For non-shared goals or other progress-only updates, just update the progress
          // Use the current user's ID for progress tracking, not the goal owner's ID
          String progressUserId = userId; // Use the current user's ID for their own progress tracking
          print('User $userId updating progress for goal $goalId with completed: $completed');
          final success = await toggleGoalProgressForUser(progressUserId, goalId, completed);
          if (success) {
            // For non-shared and non-owner updates, we still want to optimistically keep the UI updated
            // Update the goal display to reflect the current user's status for habits
            // Update the goal's completion status based on user's individual progress for today
            // But since the main goal status might be different from individual progress,
            // we need to ensure the UI shows the correct status for habits vs goals
            
            // For habits, the UI shows completion based on isGoalCompletedForDate which checks individual progress
            // For goals, the UI shows completion based on the goal.completed field
            
            // The optimistic update already handled the main display, so we just continue
            notifyListeners();
            print('Successfully updated progress for user $userId');
          } else {
            // If progress update fails, revert the optimistic update
            _goals[goalIndex] = originalGoal;
            notifyListeners();
            print('Failed to update progress for user $userId, reverted UI.');
          }
        }
      } catch (e) {
        // If API call throws an error, revert the optimistic update
        _goals[goalIndex] = originalGoal;
        notifyListeners();
        print('Error updating goal, reverted UI: $e');
      }
    } catch (e) {
      print('Error toggling goal progress: $e');
      // In case of general error, also revert the UI
      _goals[goalIndex] = originalGoal;
      notifyListeners();
    } finally {
      // Always clear the operation flag in the finally block
      _toggleOperations[operationKey] = false;
    }
  }

  // Check if a goal is completed for a specific date
  bool isGoalCompletedForDate(String goalId, DateTime date) {
    final yearMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final day = date.day;

    if (!_userGoalProgress.containsKey(goalId)) return false;
    if (!_userGoalProgress[goalId]!.containsKey(yearMonth)) return false;

    final bitString = _userGoalProgress[goalId]![yearMonth]!;
    if (day < 1 || day > bitString.length) return false;

    final index = day - 1;
    return index < bitString.length && bitString[index] == '1';
  }

  // Get current streak for a goal
  int getCurrentStreak(String goalId) {
    if (!_userGoalProgress.containsKey(goalId)) {
      return _currentStreaks[goalId] ?? 0;
    }
    
    // Use the new method from the model which calculates in real-time
    final progressSummary = GoalProgressSummary(
      monthlyData: _userGoalProgress[goalId] ?? {},
      currentStreak: _currentStreaks[goalId] ?? 0,
      longestStreak: _longestStreaks[goalId] ?? 0,
      lastUpdated: DateTime.now(),
    );
    
    return progressSummary.getCurrentStreak();
  }

  // Get longest streak for a goal
  int getLongestStreak(String goalId) {
    if (!_userGoalProgress.containsKey(goalId)) {
      return _longestStreaks[goalId] ?? 0;
    }
    
    // Use the new method from the model which calculates in real-time
    final progressSummary = GoalProgressSummary(
      monthlyData: _userGoalProgress[goalId] ?? {},
      currentStreak: _currentStreaks[goalId] ?? 0,
      longestStreak: _longestStreaks[goalId] ?? 0,
      lastUpdated: DateTime.now(),
    );
    
    return progressSummary.getLongestStreak();
  }

  List<DateTime> getDatesInCurrentStreak(String goalId) {
    final goal = _goals.firstWhereOrNull((g) => g.id == goalId);
    if (goal == null) return [];

    final List<DateTime> streakDates = [];
    DateTime currentDate = DateTime.now();

    // Adjust for today: if today is not completed, start checking from yesterday
    if (!isGoalCompletedForDate(goalId, currentDate)) {
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    while (isGoalCompletedForDate(goalId, currentDate)) {
      streakDates.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    return streakDates;
  }

  // Calculate progress percentage for a goal based on actual completion data
  double calculateGoalProgress(String goalId) {
    // Get the goal to determine the date range
    final goal = _goals.firstWhereOrNull((g) => g.id == goalId);
    if (goal == null || goal.isHabit || goal.startDate == null || goal.endDate == null) {
      return 0.0;
    }

    final startDate = goal.startDate!;
    final endDate = goal.endDate!;
    final today = DateTime.now();

    // Calculate total days in the goal period
    int totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) return 0.0;

    // Calculate days that have passed in the goal period (up to today)
    DateTime periodEnd = today.isBefore(endDate) ? today : endDate;
    if (periodEnd.isBefore(startDate)) {
      return 0.0;
    }
    
    int daysInPeriod = periodEnd.difference(startDate).inDays + 1;

    // Count completed days in the period that has passed
    int completedDays = 0;
    for (int i = 0; i < daysInPeriod; i++) {
      final currentDate = startDate.add(Duration(days: i));
      if (isGoalCompletedForDate(goalId, currentDate)) {
        completedDays++;
      }
    }

    // Calculate percentage based on days completed vs days that have passed
    // This makes more sense as it shows actual progress vs planned progress
    return (completedDays / daysInPeriod) * 100;
  }

  // Calculate current streak for a goal
  int calculateCurrentStreak(String goalId) {
    return getCurrentStreak(goalId);
  }

  // Calculate longest streak for a goal
  int calculateLongestStreak(String goalId) {
    return getLongestStreak(goalId);
  }

  // Calculate progress and missed percentage for a goal based on date range
  Map<String, double> calculateProgressAndMissedPercentage(Goal goal) {
    if (goal.isHabit || goal.startDate == null || goal.endDate == null) {
      return {'completedPercentage': 0.0, 'missedPercentage': 0.0};
    }

    final startDate = goal.startDate!;
    final endDate = goal.endDate!;

    if (endDate.isBefore(startDate)) {
      return {'completedPercentage': 0.0, 'missedPercentage': 0.0};
    }

    int totalDays = endDate.difference(startDate).inDays + 1;
    if (totalDays <= 0) {
      return {'completedPercentage': 0.0, 'missedPercentage': 0.0};
    }

    int completedDays = 0;
    int missedDays = 0;

    for (int i = 0; i < totalDays; i++) {
      final currentDate = startDate.add(Duration(days: i));
      if (isGoalCompletedForDate(goal.id, currentDate)) {
        completedDays++;
      } else {
        // Only count as missed if the day is in the past or today
        if (currentDate.isBefore(DateTime.now()) || currentDate.isAtSameMomentAs(DateTime.now())) {
          missedDays++;
        }
      }
    }

    final completedPercentage = (completedDays / totalDays) * 100;
    final missedPercentage = (missedDays / totalDays) * 100;

    return {
      'completedPercentage': completedPercentage,
      'missedPercentage': missedPercentage,
    };
  }
}

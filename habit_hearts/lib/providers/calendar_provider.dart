import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:habit_hearts/models/calendar_event.dart';
import 'package:habit_hearts/services/api_service.dart';
import 'package:habit_hearts/providers/habit_hearts_auth_provider.dart';

enum CalendarViewMode { day, week, month }

class CalendarProvider with ChangeNotifier {
  List<CalendarEvent> _events = [];
  bool _isLoading = false;
  String? _error;

  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();

  HabitHeartsAuthProvider? _authProvider;

  // Getters
  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CalendarViewMode get viewMode => _viewMode;
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;

  void update(HabitHeartsAuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider != null && _authProvider!.isAuthenticated) {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      loadEvents(firstDay, lastDay);
    } else {
      _events = [];
      notifyListeners();
    }
  }

  // Get events for a specific date
  List<CalendarEvent> getEventsForDate(DateTime date) {
    final events = _events.where((event) {
      // Handle different date types
      if (event.date is DateTime) {
        return _isSameDay(event.date as DateTime, date);
      } else if (event.date is int) {
        // Handle timestamp
        final eventDate = DateTime.fromMillisecondsSinceEpoch(event.date as int);
        return _isSameDay(eventDate, date);
      } else if (event.date is String) {
        // Handle string date
        try {
          final eventDate = DateTime.parse(event.date as String);
          return _isSameDay(eventDate, date);
        } catch (e) {
          print('Error parsing date string: $e');
          return false;
        }
      }
      return false;
    }).toList();

    if (events.isNotEmpty) {
      print('Found ${events.length} events for ${date.toIso8601String()}');
      for (var event in events) {
        print('  - ${event.title} (${event.date})');
      }
    }

    return events;
  }

  // Helper method to check if two dates are the same day
  bool _isSameDay(dynamic date1, DateTime date2) {
    DateTime? parsedDate1;

    if (date1 is DateTime) {
      parsedDate1 = date1;
    } else if (date1 is int) {
      parsedDate1 = DateTime.fromMillisecondsSinceEpoch(date1);
    } else if (date1 is String) {
      try {
        parsedDate1 = DateTime.parse(date1);
      } catch (e) {
        print('Error parsing date string: $e');
        return false;
      }
    }

    if (parsedDate1 == null) {
      return false;
    }

    return parsedDate1.year == date2.year &&
        parsedDate1.month == date2.month &&
        parsedDate1.day == date2.day;
  }

  // Set view mode
  void setViewMode(CalendarViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  // Set selected date
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // Set focused date
  void setFocusedDate(DateTime date) {
    _focusedDate = date;
    notifyListeners();
  }

  // Load events for a date range
  Future<void> loadEvents(DateTime startDate, DateTime endDate) async {
    if (_isLoading) return;
    if (_authProvider == null || !_authProvider!.isAuthenticated) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _authProvider!.user;
      if (user == null) return;

      final allUserIds = [user.uid];
      final habitHeartsUser = _authProvider?.habitHeartsUser;
      if (habitHeartsUser != null) {
        allUserIds.addAll(habitHeartsUser.linkedUsers);
      }
      List<CalendarEvent> allEvents = [];

      // Load events for current user (all events for self)
      final myUserId = user!.uid;
      final myEvents = await ApiService.getCalendarEvents(myUserId, startDate, endDate);
      allEvents.addAll(myEvents);
      
      // Load only shared events from linked users using parallel requests
      if (habitHeartsUser != null && habitHeartsUser.linkedUsers.isNotEmpty) {
        final linkedUserIds = habitHeartsUser.linkedUsers;
        final linkedUserEventsFutures = linkedUserIds.map((linkedId) => 
          ApiService.getCalendarEvents(linkedId, startDate, endDate)
        ).toList();
        
        final allLinkedEventsResults = await Future.wait(linkedUserEventsFutures, eagerError: false);
        
        for (int i = 0; i < linkedUserIds.length; i++) {
          try {
            final linkedUserEvents = allLinkedEventsResults[i];
            // Filter out events that are already in the current user's events to prevent duplicates
            final sharedEvents = linkedUserEvents.where((event) => event.isShared && 
                !allEvents.any((existingEvent) => existingEvent.id == event.id));
            allEvents.addAll(sharedEvents);
          } catch (e) {
            print('Error loading events for user ${linkedUserIds[i]}: $e');
          }
        }
      }
      _events = _removeDuplicateEvents(allEvents);
      print('Total events loaded: ${_events.length}');
    } catch (e) {
      _error = e.toString();
      print('Error loading events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create a new event
  Future<CalendarEvent?> createEvent(BuildContext context, CalendarEvent event) async {
    try {
      final newEvent = await ApiService.createCalendarEvent(event);
      if (newEvent != null) {
        _events.add(newEvent);
        notifyListeners();
        return newEvent;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      print('Error creating event: $e');
      notifyListeners();
      return null;
    }
  }

  // Update an event
  Future<CalendarEvent?> updateEvent(BuildContext context, CalendarEvent event) async {
    final userId = _authProvider?.user?.uid;
    if (userId != null) {
      // Check if the current user has permission to update this event
      final existingEvent = _events.firstWhere((e) => e.id == event.id, orElse: () => throw Exception('Event not found'));
      final isOwner = existingEvent.createdBy == userId;
      final canEdit = isOwner || existingEvent.isShared; // Owner or shared events can be edited
      
      if (!canEdit) {
        print('User does not have permission to update event ${event.id}');
        return null;
      }
    }

    try {
      final success = await ApiService.updateCalendarEvent(event);
      if (success) {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          _events[index] = event;
          notifyListeners();
        }
        return event;
      }
      return null;
    } catch (e) {
      _error = e.toString();
      print('Error updating event: $e');
      notifyListeners();
      return null;
    }
  }

  // Delete an event
  Future<bool> deleteEvent(BuildContext context, String eventId) async {
    final userId = _authProvider?.user?.uid;
    if (userId != null) {
      // Check if the current user has permission to delete this event
      final eventIndex = _events.indexWhere((e) => e.id == eventId);
      if (eventIndex == -1) {
        print('Event $eventId not found');
        return false;
      }
      
      final event = _events[eventIndex];
      final isOwner = event.createdBy == userId;
      final canDelete = isOwner || event.isShared; // Owner or shared events can be deleted
      
      if (!canDelete) {
        print('User does not have permission to delete event $eventId');
        return false;
      }
    }

    try {
      final success = await ApiService.deleteCalendarEvent(eventId);
      if (success) {
        _events.removeWhere((event) => event.id == eventId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      print('Error deleting event: $e');
      notifyListeners();
      return false;
    }
  }
  
  List<CalendarEvent> _removeDuplicateEvents(List<CalendarEvent> events) {
    final seenIds = <String>{};
    return events.where((event) => seenIds.add(event.id)).toList();
  }
}

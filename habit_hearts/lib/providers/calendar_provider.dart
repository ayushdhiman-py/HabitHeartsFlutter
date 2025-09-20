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
      final userId = _authProvider!.user!.uid;
      
      // Load events from API (now includes events from linked users)
      print('Fetching events for user $userId from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      final events = await ApiService.getCalendarEvents(userId, startDate, endDate);
      print('Fetched ${events.length} events for user $userId');
      _events = events;
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
}

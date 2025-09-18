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
  
  // Getters
  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CalendarViewMode get viewMode => _viewMode;
  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  
  // Get events for a specific date
  List<CalendarEvent> getEventsForDate(DateTime date) {
    return _events.where((event) {
      if (event.date is DateTime) {
        return _isSameDay(event.date, date);
      }
      return false;
    }).toList();
  }
  
  // Helper method to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
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
  Future<void> loadEvents(String userId, DateTime startDate, DateTime endDate) async {
    // Check if we already have events for this date range to avoid unnecessary API calls
    final hasEventsForRange = _events.any((event) {
      final eventDate = event.date is DateTime ? event.date as DateTime : null;
      if (eventDate == null) return false;
      return (eventDate.isAfter(startDate) || _isSameDay(eventDate, startDate)) && 
             (eventDate.isBefore(endDate) || _isSameDay(eventDate, endDate));
    });
    
    // If we already have events for this range, don't reload unless forced
    if (hasEventsForRange && !_isLoading) {
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _events = await ApiService.getCalendarEvents(userId, startDate, endDate);
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
        // Add the event returned from the API (with the correct ID) to our local list
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
        // Update the event in our local list
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
        // Remove the event from our local list
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
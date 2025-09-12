import 'dart:async';
import '../models/calendar_event.dart';
import '../services/api_service.dart';

class CalendarService {
  // Get events for a specific date range
  Stream<List<CalendarEvent>> getEvents(String userId, List<String> linkedUserIds, DateTime startDate, DateTime endDate) {
    try {
      // For now, we'll create a simple stream that fetches events once
      // In a real implementation, you might want to implement polling or WebSockets
      StreamController<List<CalendarEvent>> controller = StreamController();
      
      // Fetch events - this would need to be implemented in the backend
      // For now, we'll return an empty list
      controller.add([]);
      controller.close();
      
      return controller.stream;
    } catch (e) {
      print('Error getting events: $e');
      return Stream.value([]);
    }
  }

  // Create a new event
  Future<void> createEvent(CalendarEvent event) async {
    try {
      await ApiService.createCalendarEvent(event);
    } catch (e) {
      print('Error creating event: $e');
    }
  }

  // Update an event
  Future<void> updateEvent(CalendarEvent event) async {
    try {
      await ApiService.updateCalendarEvent(event);
    } catch (e) {
      print('Error updating event: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      await ApiService.deleteCalendarEvent(eventId);
    } catch (e) {
      print('Error deleting event: $e');
    }
  }
}
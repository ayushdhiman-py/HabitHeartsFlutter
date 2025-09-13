import 'dart:async';
import '../models/calendar_event.dart';
import '../services/api_service.dart';

class CalendarService {
  // Get events for a specific date range
  Future<List<CalendarEvent>> getEventsForDateRange(
    String userId, 
    List<String> linkedUserIds, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      // Fetch events for the current user
      List<CalendarEvent> userEvents = await ApiService.getCalendarEvents(
        userId, 
        startDate, 
        endDate
      );
      
      // Fetch events for linked users
      List<CalendarEvent> linkedUserEvents = [];
      for (String linkedUserId in linkedUserIds) {
        List<CalendarEvent> events = await ApiService.getCalendarEvents(
          linkedUserId, 
          startDate, 
          endDate
        );
        linkedUserEvents.addAll(events);
      }
      
      // Combine all events
      List<CalendarEvent> allEvents = [...userEvents, ...linkedUserEvents];
      
      // Remove duplicates (in case a user is linked to themselves or there are overlapping links)
      Set<String> eventIds = {};
      List<CalendarEvent> uniqueEvents = [];
      
      for (CalendarEvent event in allEvents) {
        if (!eventIds.contains(event.id)) {
          eventIds.add(event.id);
          uniqueEvents.add(event);
        }
      }
      
      return uniqueEvents;
    } catch (e) {
      print('Error getting events: $e');
      return [];
    }
  }

  // Create a new event
  Future<bool> createEvent(CalendarEvent event) async {
    try {
      return await ApiService.createCalendarEvent(event);
    } catch (e) {
      print('Error creating event: $e');
      return false;
    }
  }

  // Update an event
  Future<bool> updateEvent(CalendarEvent event) async {
    try {
      return await ApiService.updateCalendarEvent(event);
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }

  // Delete an event
  Future<bool> deleteEvent(String eventId) async {
    try {
      return await ApiService.deleteCalendarEvent(eventId);
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }
}
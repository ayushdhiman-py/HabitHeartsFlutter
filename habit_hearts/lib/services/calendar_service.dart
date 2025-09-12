import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_event.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get events for a specific date range
  Stream<List<CalendarEvent>> getEvents(String userId, List<String> linkedUserIds, DateTime startDate, DateTime endDate) {
    try {
      // Get events for user and linked users
      List<String> userIds = [userId, ...linkedUserIds];

      return _firestore
          .collection('calendarEvents')
          .where('createdBy', whereIn: userIds)
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => CalendarEvent.fromJson(doc.data()))
              .toList());
    } catch (e) {
      print('Error getting events: $e');
      return Stream.value([]);
    }
  }

  // Create a new event
  Future<void> createEvent(CalendarEvent event) async {
    try {
      await _firestore.collection('calendarEvents').doc(event.id).set(event.toJson());
    } catch (e) {
      print('Error creating event: $e');
    }
  }

  // Update an event
  Future<void> updateEvent(CalendarEvent event) async {
    try {
      await _firestore.collection('calendarEvents').doc(event.id).update(event.toJson());
    } catch (e) {
      print('Error updating event: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('calendarEvents').doc(eventId).delete();
    } catch (e) {
      print('Error deleting event: $e');
    }
  }
}
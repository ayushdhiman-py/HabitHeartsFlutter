import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get tasks for a specific date
  Stream<List<Task>> getTasksForDate(String userId, List<String> linkedUserIds, DateTime date) {
    try {
      // Create start and end of day timestamps
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      // Get tasks for user and linked users
      List<String> userIds = [userId, ...linkedUserIds];

      return _firestore
          .collection('tasks')
          .where('createdBy', whereIn: userIds)
          .where('dueDate', isGreaterThanOrEqualTo: startOfDay)
          .where('dueDate', isLessThanOrEqualTo: endOfDay)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromJson(doc.data()))
              .toList());
    } catch (e) {
      print('Error getting tasks: $e');
      return Stream.value([]);
    }
  }

  // Create a new task
  Future<void> createTask(Task task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).set(task.toJson());
    } catch (e) {
      print('Error creating task: $e');
    }
  }

  // Update a task
  Future<void> updateTask(Task task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).update(task.toJson());
    } catch (e) {
      print('Error updating task: $e');
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
    } catch (e) {
      print('Error deleting task: $e');
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(Task task) async {
    try {
      await _firestore.collection('tasks').doc(task.id).update({
        'completed': !task.completed,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error toggling task completion: $e');
    }
  }
}
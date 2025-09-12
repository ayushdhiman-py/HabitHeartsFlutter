import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal.dart';

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get goals for user and linked users
  Stream<List<Goal>> getGoals(String userId, List<String> linkedUserIds) {
    try {
      // Get goals for user and linked users
      List<String> userIds = [userId, ...linkedUserIds];

      return _firestore
          .collection('goals')
          .where('createdBy', whereIn: userIds)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Goal.fromJson(doc.data()))
              .toList());
    } catch (e) {
      print('Error getting goals: $e');
      return Stream.value([]);
    }
  }

  // Create a new goal
  Future<void> createGoal(Goal goal) async {
    try {
      await _firestore.collection('goals').doc(goal.id).set(goal.toJson());
    } catch (e) {
      print('Error creating goal: $e');
    }
  }

  // Update a goal
  Future<void> updateGoal(Goal goal) async {
    try {
      await _firestore.collection('goals').doc(goal.id).update(goal.toJson());
    } catch (e) {
      print('Error updating goal: $e');
    }
  }

  // Delete a goal
  Future<void> deleteGoal(String goalId) async {
    try {
      await _firestore.collection('goals').doc(goalId).delete();
    } catch (e) {
      print('Error deleting goal: $e');
    }
  }

  // Toggle goal completion
  Future<void> toggleGoalCompletion(Goal goal) async {
    try {
      await _firestore.collection('goals').doc(goal.id).update({
        'completed': !goal.completed,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error toggling goal completion: $e');
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/goal_progress.dart';

class GoalProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get progress for a specific goal
  Stream<List<GoalProgress>> getGoalProgress(String goalId) {
    try {
      return _firestore
          .collection('goalProgress')
          .where('goalId', isEqualTo: goalId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => GoalProgress.fromJson(doc.data()))
              .toList());
    } catch (e) {
      print('Error getting goal progress: $e');
      return Stream.value([]);
    }
  }

  // Get progress for multiple goals
  Stream<List<GoalProgress>> getGoalsProgress(List<String> goalIds, String userId) {
    try {
      return _firestore
          .collection('goalProgress')
          .where('goalId', whereIn: goalIds)
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => GoalProgress.fromJson(doc.data()))
              .toList());
    } catch (e) {
      print('Error getting goals progress: $e');
      return Stream.value([]);
    }
  }

  // Update goal progress for a specific date
  Future<void> updateGoalProgress(GoalProgress progress) async {
    try {
      await _firestore.collection('goalProgress').doc(progress.id).set(progress.toJson());
    } catch (e) {
      print('Error updating goal progress: $e');
    }
  }

  // Toggle goal progress for a specific date
  Future<void> toggleGoalProgress(String goalId, String date, String userId) async {
    try {
      // Check if progress already exists for this date
      QuerySnapshot snapshot = await _firestore
          .collection('goalProgress')
          .where('goalId', isEqualTo: goalId)
          .where('date', isEqualTo: date)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Update existing progress
        DocumentSnapshot doc = snapshot.docs.first;
        GoalProgress progress = GoalProgress.fromJson(doc.data() as Map<String, dynamic>);
        await _firestore.collection('goalProgress').doc(doc.id).update({
          'completed': !progress.completed,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Create new progress
        String id = _firestore.collection('goalProgress').doc().id;
        GoalProgress progress = GoalProgress(
          id: id,
          goalId: goalId,
          date: date,
          completed: true,
          userId: userId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestore.collection('goalProgress').doc(id).set(progress.toJson());
      }
    } catch (e) {
      print('Error toggling goal progress: $e');
    }
  }
}
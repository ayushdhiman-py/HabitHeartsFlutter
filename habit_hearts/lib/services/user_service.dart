import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as habit_hearts_user;

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user document
  Future<habit_hearts_user.User?> getUser(String uid) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(uid).get();
      if (snapshot.exists) {
        return habit_hearts_user.User.fromJson(snapshot.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Create or update user document
  Future<void> setUser(habit_hearts_user.User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toJson());
    } catch (e) {
      print('Error setting user: $e');
    }
  }

  // Generate unique code for user linking
  String generateUniqueCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Link users
  Future<void> linkUsers(String currentUserUid, String partnerCode) async {
    try {
      // Find user with the partner code
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('uniqueCode', isEqualTo: partnerCode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentSnapshot partnerDoc = snapshot.docs.first;
        String partnerUid = partnerDoc.id;

        // Update current user's linkedUsers array
        await _firestore.collection('users').doc(currentUserUid).update({
          'linkedUsers': FieldValue.arrayUnion([partnerUid])
        });

        // Update partner's linkedUsers array
        await _firestore.collection('users').doc(partnerUid).update({
          'linkedUsers': FieldValue.arrayUnion([currentUserUid])
        });
      }
    } catch (e) {
      print('Error linking users: $e');
    }
  }

  // Unlink users
  Future<void> unlinkUsers(String currentUserUid, String partnerUid) async {
    try {
      // Update current user's linkedUsers array
      await _firestore.collection('users').doc(currentUserUid).update({
        'linkedUsers': FieldValue.arrayRemove([partnerUid])
      });

      // Update partner's linkedUsers array
      await _firestore.collection('users').doc(partnerUid).update({
        'linkedUsers': FieldValue.arrayRemove([currentUserUid])
      });
    } catch (e) {
      print('Error unlinking users: $e');
    }
  }
}
import 'dart:math';
import '../services/api_service.dart';
import '../models/user.dart' as habit_hearts_user;

class UserService {
  // Get user document
  Future<habit_hearts_user.User?> getUser(String uid) async {
    try {
      return await ApiService.getUser(uid);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Create or update user document
  Future<bool> setUser(habit_hearts_user.User user) async {
    try {
      // Check if user exists
      final existingUser = await getUser(user.uid);
      if (existingUser != null) {
        // Update existing user
        return await ApiService.updateUser(user);
      } else {
        // Create new user
        return await ApiService.createUser(user);
      }
    } catch (e) {
      print('Error setting user: $e');
      return false;
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
      await ApiService.linkUsers(currentUserUid, partnerCode);
    } catch (e) {
      print('Error linking users: $e');
    }
  }

  // Unlink users
  Future<void> unlinkUsers(String currentUserUid, String partnerUid) async {
    try {
      await ApiService.unlinkUsers(currentUserUid, partnerUid);
    } catch (e) {
      print('Error unlinking users: $e');
    }
  }
}
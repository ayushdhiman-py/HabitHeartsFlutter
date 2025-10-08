import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart' as habit_hearts_user;
import '../services/auth_service.dart';
import '../services/user_service.dart';

class HabitHeartsAuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  
  User? _user;
  habit_hearts_user.User? _habitHeartsUser;
  
  User? get user => _user;
  habit_hearts_user.User? get habitHeartsUser => _habitHeartsUser;
  
  bool get isAuthenticated => _user != null;
  
  HabitHeartsAuthProvider() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
      
      if (user != null) {
        // Load user document
        _loadUserDocument(user.uid);
      }
    });
  }
  
  // Load user document from Firestore
  Future<void> _loadUserDocument(String uid) async {
    if (_user == null) return;

    try {
      habit_hearts_user.User? user = await _userService.getUser(uid);
      if (user != null) {
        // User document exists, use it
        _habitHeartsUser = user;
        print(
            'HabitHeartsAuthProvider - Loaded user document for $uid with unique code: ${user.uniqueCode}');
      } else {
        // User document doesn't exist, create it
        print(
            'HabitHeartsAuthProvider - No user document found for $uid, creating new one');
        String newUniqueCode = _userService.generateUniqueCode();
        habit_hearts_user.User newUser = habit_hearts_user.User(
          uid: _user!.uid,
          email: _user!.email,
          displayName: _user!.displayName,
          photoURL: _user!.photoURL,
          uniqueCode: newUniqueCode,
          linkedUsers: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'active',
          subscription: 'free',
          zodiacSign: null,
        );
        await _userService.setUser(newUser);
        _habitHeartsUser = newUser;
        print(
            'HabitHeartsAuthProvider - Created new user document for $uid with unique code: $newUniqueCode');
      }
      notifyListeners();
    } catch (e) {
      print('Error loading or creating user document: $e');
    }
  }
  
  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      UserCredential? credential = await _authService.signInWithGoogle();
      return credential != null;
    } catch (e) {
      print('Error signing in with Google: $e');
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _habitHeartsUser = null;
    notifyListeners();
  }
  
  // Link with partner
  Future<void> linkWithPartner(String partnerCode) async {
    if (_user == null || _habitHeartsUser == null) return;
    
    try {
      await _userService.linkUsers(_user!.uid, partnerCode);
      // Refresh user document
      await _loadUserDocument(_user!.uid);
    } catch (e) {
      print('Error linking with partner: $e');
    }
  }
  
  // Unlink from partner
  Future<void> unlinkFromPartner(String partnerUid) async {
    if (_user == null) return;
    
    try {
      await _userService.unlinkUsers(_user!.uid, partnerUid);
      // Refresh user document
      await _loadUserDocument(_user!.uid);
    } catch (e) {
      print('Error unlinking from partner: $e');
      rethrow;
    }
  }
  
  // Update user's zodiac sign
  Future<void> updateUserZodiacSign(String zodiacSign) async {
    if (_user == null || _habitHeartsUser == null) return;
    
    try {
      print('HabitHeartsAuthProvider - Updating zodiac sign to: $zodiacSign for user: ${_habitHeartsUser!.uid}');
      
      // Create updated user object with new zodiac sign
      habit_hearts_user.User updatedUser = habit_hearts_user.User(
        uid: _habitHeartsUser!.uid,
        email: _habitHeartsUser!.email,
        displayName: _habitHeartsUser!.displayName,
        photoURL: _habitHeartsUser!.photoURL,
        uniqueCode: _habitHeartsUser!.uniqueCode,
        linkedUsers: _habitHeartsUser!.linkedUsers,
        createdAt: _habitHeartsUser!.createdAt,
        updatedAt: DateTime.now(),
        status: _habitHeartsUser!.status,
        subscription: _habitHeartsUser!.subscription,
        goalProgress: _habitHeartsUser!.goalProgress,
        zodiacSign: zodiacSign,
      );
      
      print('HabitHeartsAuthProvider - Created updated user with zodiac sign: ${updatedUser.zodiacSign}');
      
      // Update the user in the database
      bool success = await _userService.setUser(updatedUser);
      if (success) {
        print('HabitHeartsAuthProvider - Successfully saved user with zodiac sign to database');
        // Update the local user object only if the save was successful
        _habitHeartsUser = updatedUser;
        notifyListeners();
      } else {
        print('HabitHeartsAuthProvider - Failed to save zodiac sign to database, but keeping it locally');
        // Still update the local object for immediate UI update, even if remote save failed
        _habitHeartsUser = updatedUser;
        notifyListeners();
        // Try to save again later by reloading the user
        _loadUserDocument(_user!.uid);
      }
    } catch (e) {
      print('Error updating user zodiac sign: $e');
      // Still update the local object for immediate UI update, even if there was an error
      habit_hearts_user.User updatedUser = habit_hearts_user.User(
        uid: _habitHeartsUser!.uid,
        email: _habitHeartsUser!.email,
        displayName: _habitHeartsUser!.displayName,
        photoURL: _habitHeartsUser!.photoURL,
        uniqueCode: _habitHeartsUser!.uniqueCode,
        linkedUsers: _habitHeartsUser!.linkedUsers,
        createdAt: _habitHeartsUser!.createdAt,
        updatedAt: DateTime.now(),
        status: _habitHeartsUser!.status,
        subscription: _habitHeartsUser!.subscription,
        goalProgress: _habitHeartsUser!.goalProgress,
        zodiacSign: zodiacSign,
      );
      _habitHeartsUser = updatedUser;
      notifyListeners();
      // The error is caught and logged but we maintain the local change
    }
  }
}
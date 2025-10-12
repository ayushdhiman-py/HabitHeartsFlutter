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
      // First, try to get existing user document
      habit_hearts_user.User? user = await _userService.getUser(uid);
      
      if (user != null) {
        // User document exists, use it
        _habitHeartsUser = user;
        print(
            'HabitHeartsAuthProvider - Loaded user document for $uid with unique code: ${user.uniqueCode}');
      } else {
        // User document doesn't exist, create it with a new unique code
        print(
            'HabitHeartsAuthProvider - No user document found for $uid, creating new one');
        
        // Verify that the user document doesn't exist by trying to get it again
        // This is to handle potential race conditions or caching issues
        final freshCheck = await _userService.getUser(uid);
        if (freshCheck != null) {
          // User document already exists, use the existing one with its unique code
          _habitHeartsUser = freshCheck;
          print(
              'HabitHeartsAuthProvider - User document already exists (race condition), using existing unique code: ${freshCheck.uniqueCode}');
        } else {
          // Generate and attempt to create user with unique code
          // Try up to 3 times in case of unique code conflicts
          bool creationSuccess = false;
          int attempts = 0;
          habit_hearts_user.User? createdUser;
          
          while (!creationSuccess && attempts < 3) {
            attempts++;
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
            
            bool success = await _userService.setUser(newUser);
            if (success) {
              creationSuccess = true;
              createdUser = newUser;
              print(
                  'HabitHeartsAuthProvider - Created new user document for $uid with unique code: $newUniqueCode (attempt $attempts)');
            } else {
              print(
                  'HabitHeartsAuthProvider - Failed to create user document (attempt $attempts), possibly due to unique code conflict');
            }
          }
          
          if (creationSuccess && createdUser != null) {
            _habitHeartsUser = createdUser;
          } else {
            // If all attempts failed, try to fetch the user again to see if it was created despite errors
            final fallbackUser = await _userService.getUser(uid);
            if (fallbackUser != null) {
              _habitHeartsUser = fallbackUser;
              print(
                  'HabitHeartsAuthProvider - Fallback: Found existing user document for $uid with unique code: ${fallbackUser.uniqueCode}');
            } else {
              print('HabitHeartsAuthProvider - Failed to create user document for $uid after $attempts attempts');
              return;
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error loading or creating user document: $e');
      
      // As a fallback, try to get the user one more time
      try {
        final fallbackUser = await _userService.getUser(uid);
        if (fallbackUser != null) {
          _habitHeartsUser = fallbackUser;
          notifyListeners();
          print('HabitHeartsAuthProvider - Successfully fetched user after error: $uid');
        }
      } catch (fallbackError) {
        print('HabitHeartsAuthProvider - Fallback also failed: $fallbackError');
      }
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
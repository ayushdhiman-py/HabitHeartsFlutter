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
    try {
      habit_hearts_user.User? user = await _userService.getUser(uid);
      if (user != null) {
        _habitHeartsUser = user;
      } else {
        // Create new user document if it doesn't exist
        await _createUserDocument();
      }
      notifyListeners();
    } catch (e) {
      print('Error loading user document: $e');
    }
  }
  
  // Create user document
  Future<void> _createUserDocument() async {
    if (_user == null) return;
    
    try {
      // Generate unique code
      String uniqueCode = _userService.generateUniqueCode();
      
      habit_hearts_user.User newUser = habit_hearts_user.User(
        uid: _user!.uid,
        email: _user!.email,
        displayName: _user!.displayName,
        photoURL: _user!.photoURL,
        uniqueCode: uniqueCode,
        linkedUsers: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
      );
      
      await _userService.setUser(newUser);
      _habitHeartsUser = newUser;
      notifyListeners();
    } catch (e) {
      print('Error creating user document: $e');
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
}
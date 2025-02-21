import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:grocerry/models/user.dart' as models;
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'dart:async';

class AuthProvider with ChangeNotifier {
  auth.User? _user;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '492372104602-vv5b5kf132har2bcn527tvt9i8hon6iu.apps.googleusercontent.com',
  );

  final UserProvider? userProvider;
  final ProductProvider? productProvider;
  final Completer<void> _initializationCompleter = Completer<void>();
  bool? _isInitializing = true;

  AuthProvider(this.userProvider, this.productProvider) {
    _auth.authStateChanges().listen((auth.User? user) async {
      await _initializationCompleter.future;
      if (user != null && (_user == null || _user?.uid != user.uid)) {
        try {
          await _updateUserState(user.uid);
        } catch (e) {
          _handleAuthError(e);
        }
      } else if (user == null) {
        _user = null;
        userProvider!.updateUser(user! as models.User);
      }
      notifyListeners();
    });
  }

  auth.User? get user => _user;

bool get isLoggedIn {
  if (_isInitializing! || _auth.currentUser == null || _user == null) {
    return false;
  }
  return !(_auth.currentUser?.isAnonymous ?? true);
}

  Future<void> _initializeUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _updateUserState(currentUser.uid);
    }
  }

  Future<void> _updateUserState(String uid) async {
    try {
      final userData = await _fetchUserDataFromFirestore(uid);
      _user = _auth.currentUser;
      userProvider!.updateUser(userData);

      final token = await _fetchNotificationToken();
      if (token != null && token != userData.token) {
        await _firestore.collection('users').doc(uid).update({'token': token});
      }
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final auth.UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      await _updateUserState(userCredential.user?.uid ?? '');
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> register(
      String email, String password, String name, String contact,
      [String? referralCode]) async {
    try {
      final auth.UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final auth.User? newUser = userCredential.user;

      if (newUser != null) {
        await _firestore.collection('users').doc(newUser.uid).set({
          'email': email,
          'name': name.isNotEmpty ? name : 'Unnamed User',
          'contact': contact.isNotEmpty ? contact : 'No Contact',
          'createdAt': FieldValue.serverTimestamp(),
          'referralCode': referralCode ?? '',
          'isAdmin': false,
          'isRider': false,
          'isAttendant': false,
          'favoriteProductIds': [],
          'recentlyBoughtProductIds': [],
        });
        await _updateUserState(newUser.uid);
      } else {
        throw AuthException('Failed to register. User is null.');
      }
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> signInWithGoogle(String? referralCode) async {
    try {
      await _googleSignIn
          .signOut(); // Sign out before signing in again, if needed
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Handle case where user cancels sign-in
        throw AuthException('Google Sign-In was cancelled by the user.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final auth.AuthCredential credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth.UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final auth.User? user = userCredential.user;

      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email ?? 'No Email',
            'name': user.displayName ?? 'Unnamed User',
            'createdAt': FieldValue.serverTimestamp(),
            'referralCode': referralCode ?? '',
            'isAdmin': false,
            'isRider': false,
            'isAttendant': false,
            'favoriteProductIds': [],
            'recentlyBoughtProductIds': [],
          });
        }
        await _updateUserState(user.uid);
      } else {
        throw AuthException('Google Sign-In failed. User is null.');
      }
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _user = null;
      userProvider!
          .updateUser(user! as models.User); // Clear user data on logout
      notifyListeners();
    } catch (e) {
      _handleAuthError(e);
    }
  }

  Future<models.User> _fetchUserDataFromFirestore(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() ?? {};
      return models.User(
        uid: uid,
        email: data['email'] ?? 'No Email',
        name: data['name'] ?? 'Unnamed User',
        address: data['address'] ?? 'No Address',
        profilePictureUrl: data['profilePictureUrl'] ?? '',
        favoriteProductIds: List<String>.from(data['favoriteProductIds'] ?? []),
        recentlyBoughtProductIds:
            List<String>.from(data['recentlyBoughtProductIds'] ?? []),
        lastLoginDate: (data['lastLoginDate'] as Timestamp?)?.toDate(),
        id: data['id'] ?? '',
        contact: data['contact'] ?? 'No Contact',
        token: data['token'] ?? '',
        pinLocation: null,
      );
    } else {
      throw AuthException('User data not found in Firestore.');
    }
  }

  Future<String?> _fetchNotificationToken() async {
    // Implement actual token fetching logic here
    return null; // Return null if token fetching fails or isn't implemented
  }

  void _handleAuthError(Object error) {
    String errorMessage = 'Unexpected Error: ${error.toString()}';
    if (error is auth.FirebaseAuthException) {
      errorMessage = 'Firebase Auth Error: ${error.code} - ${error.message}';
    } else if (error is AuthException) {
      errorMessage = 'Authentication Error: ${error.message}';
    }
    debugPrint(errorMessage);
    // Here you might want to reset any states or flags that could lead to redundant operations
  }

  void _handleInitializationError(Object error) {
    _isInitializing = false;
    _initializationCompleter.complete();
    _handleAuthError(error);
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:grocerry/models/user.dart' as models;
import 'package:grocerry/providers/product_provider.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthProvider with ChangeNotifier {
  auth.User? _user;
  models.User? user;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '492372104602-vv5b5kf132har2bcn527tvt9i8hon6iu.apps.googleusercontent.com', // Verify this matches Firebase
  );

  final UserProvider? userProvider;
  final ProductProvider? productProvider;
  final Completer<void> _initializationCompleter = Completer<void>();
  bool _isInitializing = true;

  AuthProvider(this.userProvider, this.productProvider) {
    _initializeUser();
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
        userProvider!.updateUser(null);
        notifyListeners();
      }
      notifyListeners();
    });
  }

  bool get isLoggedIn {
    if (_isInitializing || _auth.currentUser == null || _user == null) {
      return false;
    }
    return !(_auth.currentUser?.isAnonymous ?? true);
  }

  Future<void> _initializeUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _updateUserState(currentUser.uid);
      }
    } catch (e) {
      _handleAuthError(e);
    } finally {
      _isInitializing = false;
      _initializationCompleter.complete();
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
      if (e is AuthException && e.message == 'User data not found in Firestore.') {
        await logout();
      }
      _handleAuthError(e);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final auth.UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _updateUserState(userCredential.user?.uid ?? '');
    } catch (e) {
      _handleAuthError(e);
      rethrow; // Propagate error to UI
    }
  }

  Future<void> register(
      String email, String password, String name, String contact, [String? referralCode]) async {
    try {
      final auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
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
      rethrow;
    }
  }

  Future<void> signInWithGoogle(String? referralCode) async {
    try {
      // Sign out from Google to ensure a fresh sign-in
      await _googleSignIn.signOut();
      print('Google Sign-In: Starting sign-in process...');

      // Prompt user to sign in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In: User cancelled the sign-in process.');
        throw AuthException('Google Sign-In was cancelled by the user.');
      }
      print('Google Sign-In: User signed in: ${googleUser.email}');

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Google Sign-In: Access Token: ${googleAuth.accessToken}');
      print('Google Sign-In: ID Token: ${googleAuth.idToken}');

      // Create Firebase credential
      final auth.AuthCredential credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final auth.UserCredential userCredential = await _auth.signInWithCredential(credential);
      final auth.User? user = userCredential.user;

      if (user != null) {
        print('Google Sign-In: Firebase user signed in: ${user.uid}');
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          print('Google Sign-In: Creating new user document in Firestore...');
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
      print('Google Sign-In error: $e');
      _handleAuthError(e);
      rethrow; // Propagate error to UI
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _user = null;
      userProvider!.updateUser(null);
      notifyListeners();
    } catch (e) {
      _handleAuthError(e);
      rethrow;
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
        recentlyBoughtProductIds: List<String>.from(data['recentlyBoughtProductIds'] ?? []),
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
    try {
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        String? token = await messaging.getToken();
        if (token != null) {
          debugPrint('FCM Token fetched successfully: $token');
          return token;
        } else {
          debugPrint('Failed to fetch FCM token: Token is null');
          return null;
        }
      } else {
        debugPrint('Notification permission denied by user');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching FCM token: $e');
      return null;
    }
  }

  void _handleAuthError(Object error) {
    String errorMessage = 'Unexpected Error: ${error.toString()}';
    if (error is auth.FirebaseAuthException) {
      errorMessage = 'Firebase Auth Error: ${error.code} - ${error.message}';
    } else if (error is AuthException) {
      errorMessage = 'Authentication Error: ${error.message}';
    }
    debugPrint(errorMessage);
    // Errors are now rethrown to be handled by callers
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}
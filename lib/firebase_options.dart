// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB2dnWnePtbejHQcvS8xKw4GKkPdr2Eaj0',
    appId: '1:492372104602:web:fa0b5a298ae3968c831623',
    messagingSenderId: '492372104602',
    projectId: 'sokoni-s-grocery',
    authDomain: 'sokoni-s-grocery.firebaseapp.com',
    databaseURL: 'https://sokoni-s-grocery-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'sokoni-s-grocery.appspot.com',
    measurementId: 'G-P3VRML5K6G',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBGmhtaiwTfZga_WOceocEYKsYrRtS11l0',
    appId: '1:492372104602:android:992b8ed44f5c8ab6831623',
    messagingSenderId: '492372104602',
    projectId: 'sokoni-s-grocery',
    databaseURL: 'https://sokoni-s-grocery-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'sokoni-s-grocery.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBZRoToJm0W9ebYlZGkmY0TzhajP0tJr64',
    appId: '1:492372104602:ios:91ef8a27758766a6831623',
    messagingSenderId: '492372104602',
    projectId: 'sokoni-s-grocery',
    databaseURL: 'https://sokoni-s-grocery-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'sokoni-s-grocery.appspot.com',
    iosClientId: '492372104602-2e2kn3i7n2aagnp1kk4sngtrpr44dhhu.apps.googleusercontent.com',
    iosBundleId: 'com.example.grocerry',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB2dnWnePtbejHQcvS8xKw4GKkPdr2Eaj0',
    appId: '1:492372104602:web:8a6c052463829f29831623',
    messagingSenderId: '492372104602',
    projectId: 'sokoni-s-grocery',
    authDomain: 'sokoni-s-grocery.firebaseapp.com',
    databaseURL: 'https://sokoni-s-grocery-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'sokoni-s-grocery.appspot.com',
    measurementId: 'G-8NPQ3V2DBG',
  );
}

// firebase_options.example.dart
//
// Copy this file to firebase_options.dart and fill in your real values.
// Run `flutterfire configure --project=YOUR_PROJECT_ID` to generate automatically.
// NEVER commit firebase_options.dart — it is in .gitignore.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    if (defaultTargetPlatform == TargetPlatform.iOS)     return ios;
    throw UnsupportedError('Unsupported platform');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'YOUR_ANDROID_API_KEY',
    appId:             'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'YOUR_IOS_API_KEY',
    appId:             'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId:         'YOUR_PROJECT_ID',
    storageBucket:     'YOUR_PROJECT_ID.appspot.com',
    iosBundleId:       'com.your.bundleid',
  );
}

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAof9wyKPDlazP3tYM_2WopQj1DuJ_IY2M',
    appId: '1:545998989450:android:64f966d0f60843e2796573',
    messagingSenderId: '545998989450',
    projectId: 'habithearts',
    storageBucket: 'habithearts.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAof9wyKPDlazP3tYM_2WopQj1DuJ_IY2M',
    appId: '1:545998989450:ios:TODO',
    messagingSenderId: '545998989450',
    projectId: 'habithearts',
    storageBucket: 'habithearts.firebasestorage.app',
    iosBundleId: 'com.habithearts',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAof9wyKPDlazP3tYM_2WopQj1DuJ_IY2M',
    appId: '1:545998989450:web:TODO',
    messagingSenderId: '545998989450',
    projectId: 'habithearts',
    authDomain: 'habithearts.firebaseapp.com',
    storageBucket: 'habithearts.firebasestorage.app',
    measurementId: 'G-43D98M8KMX',
  );
}
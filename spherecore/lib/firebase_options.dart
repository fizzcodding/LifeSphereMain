import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAYjewzbRjz9szLLhdvh-ld3IN-jxAy0D0',
    appId: '1:215935023640:web:47efbfbfe8e21b74a1616d',
    messagingSenderId: '215935023640',
    projectId: 'hollow-core',
    authDomain: 'hollow-core.firebaseapp.com',
    storageBucket: 'hollow-core.firebasestorage.app',
    measurementId: 'G-X59NR2FHNV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBI_aA-Z_lMp81CgUlo2XDaSxOHtiOga0Y',
    appId: '1:215935023640:android:2d339fc87d824655a1616d',
    messagingSenderId: '215935023640',
    projectId: 'hollow-core',
    storageBucket: 'hollow-core.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDYbaUux6zN1NxGt9hotu2RX_6MTfzHiNc',
    appId: '1:215935023640:ios:49a3b0f270e626cca1616d',
    messagingSenderId: '215935023640',
    projectId: 'hollow-core',
    storageBucket: 'hollow-core.firebasestorage.app',
    iosBundleId: 'com.example.untitled',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDYbaUux6zN1NxGt9hotu2RX_6MTfzHiNc',
    appId: '1:215935023640:ios:49a3b0f270e626cca1616d',
    messagingSenderId: '215935023640',
    projectId: 'hollow-core',
    storageBucket: 'hollow-core.firebasestorage.app',
    iosBundleId: 'com.example.untitled',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAYjewzbRjz9szLLhdvh-ld3IN-jxAy0D0',
    appId: '1:215935023640:web:915879db09aaa13ba1616d',
    messagingSenderId: '215935023640',
    projectId: 'hollow-core',
    authDomain: 'hollow-core.firebaseapp.com',
    storageBucket: 'hollow-core.firebasestorage.app',
    measurementId: 'G-NJ7HWCH3E9',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyAYjewzbRjz9szLLhdvh-ld3IN-jxAy0D0',
    appId: '1:215935023640:web:915879db09aaa13ba1616d',
    messagingSenderId: '215935023640',
    projectId: 'hollow-core',
    authDomain: 'hollow-core.firebaseapp.com',
    storageBucket: 'hollow-core.firebasestorage.app',
    measurementId: 'G-NJ7HWCH3E9',
  );
}

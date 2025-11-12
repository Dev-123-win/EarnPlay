import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
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
    apiKey: 'AIzaSyBQRbos-m9BLMQFaK-nAafAi_BGPGIDvNg',
    appId: '1:1006454812188:android:3e5d7908b377359194f9d9',
    messagingSenderId: '1006454812188',
    projectId: 'rewardly-new',
    storageBucket: 'rewardly-new.firebasestorage.app',
    databaseURL: 'https://rewardly-new-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBXT-6Teaw4_wyPuPz-j5nEYA8AcLP3jbo',
    appId: '1:1006454812188:ios:1c142a39730a328394f9d9',
    messagingSenderId: '1006454812188',
    projectId: 'rewardly-new',
    storageBucket: 'rewardly-new.firebasestorage.app',
    databaseURL: 'https://rewardly-new-default-rtdb.firebaseio.com',
    iosBundleId: 'com.supreet.rewardly',
  );
}

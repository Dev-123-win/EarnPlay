import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'providers/user_provider.dart';
import 'providers/game_provider.dart';
import 'services/local_storage_service.dart';
import 'services/event_queue_service.dart';
import 'admob_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Initialize Hive for persistent event queue
  try {
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('Hive initialization warning (may already be initialized): $e');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await initializeAdMob();
  } catch (e) {
    debugPrint('AdMob initialization error: $e');
    debugPrint('App will continue without ads');
  }

  await LocalStorageService.initialize();

  // Initialize EventQueueService before creating UserProvider
  final eventQueueService = EventQueueService();
  await eventQueueService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

import 'package:anon_cast/l10n/app_localizations.dart';
import 'package:anon_cast/l10n/app_localizations_delegate.dart';
import 'package:anon_cast/models/chat_session.dart';
import 'package:anon_cast/provider/admin_messages_provider.dart';
import 'package:anon_cast/provider/chat_session_provider.dart';
import 'package:anon_cast/provider/firestore_provider.dart';
import 'package:anon_cast/screens/admin_dashboard_screen.dart';
import 'package:anon_cast/screens/auth/anonymous_home_screen.dart';
import 'package:anon_cast/screens/auth/login_screen.dart';
import 'package:anon_cast/services/auth_service.dart';
import 'package:anon_cast/services/chat_service.dart';
import 'package:anon_cast/database/app_database.dart';
import 'package:anon_cast/provider/offline_provider.dart';
import 'package:anon_cast/services/message_cache.dart';
import 'package:anon_cast/services/rotation_scheduler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'firebase_options.dart';
import 'models/chat_message.dart';
import 'models/user.dart';
import 'models/user_role.dart';
import 'provider/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // final dir = await getApplicationDocumentsDirectory();
  // Hive.defaultDirectory = dir.path;

  // Initialize Firebase
  await Firebase.initializeApp(
    // Replace with actual values
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize hive
  await Hive.initFlutter();
  //await Hive.deleteFromDisk();
  // Registering the adapter
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(UserRoleAdapter());
  Hive.registerAdapter(ChatSessionAdapter());

  await Hive.openBox<User>('users');
  await Hive.openBox<ChatSession>('chat_sessions');
  await MessageCache.instance.init();
  if (!kIsWeb) await AppDatabase.instance.init();

  // Workmanager uses native APIs (e.g. getCallbackHandle) not available on web.
  if (!kIsWeb) {
    Workmanager().initialize(RotationScheduler.callbackDispatcher);
    await RotationScheduler.registerPeriodicTask();
  }

  WidgetsFlutterBinding.ensureInitialized();

  //Providers
  final firestoreProvider = FirestoreProvider();
  await firestoreProvider.initialize();
  final userProvider = UserProvider();
  final chatSessionProvider = ChatSessionProvider();
  final chatService = ChatService('');
  OfflineProvider? offlineProvider;
  if (!kIsWeb) {
    offlineProvider = OfflineProvider(firestore: firestoreProvider.firestore);
    await offlineProvider.init();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<FirestoreProvider>.value(
          value: firestoreProvider,
        ),
        Provider<OfflineProvider?>.value(value: offlineProvider),
        ChangeNotifierProvider<AdminMessagesProvider>(
          create: (ctx) => AdminMessagesProvider(
            firestore: ctx.read<FirestoreProvider>().firestore,
          ),
        ),
        ChangeNotifierProvider<UserProvider>(create: (_) => userProvider),
        ChangeNotifierProvider<ChatSessionProvider>(create: (_) => chatSessionProvider),
        Provider<ChatService>(create: (_) => chatService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder(
        stream: context.read<AuthService>().authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          if (user.isAnonymous) {
            return const AnonymousHomeScreen();
          }
          return const AdministratorDashboardScreen();
        },
      ),
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

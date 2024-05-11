import 'package:anon_cast/models/chat_session.dart';
import 'package:anon_cast/provider/firestore_provider.dart';
import 'package:anon_cast/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/chat_message.dart';
import 'models/user.dart';
import 'models/user_role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // final dir = await getApplicationDocumentsDirectory();
  // Hive.defaultDirectory = dir.path;

  // Initialize hive
  await Hive.initFlutter();
  // Registering the adapter
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(UserRoleAdapter());

  await Hive.openBox<User>('users');
  await Hive.openBox<ChatSession>('chats');

  WidgetsFlutterBinding.ensureInitialized();
  final firestoreProvider = FirestoreProvider();
  await firestoreProvider.initialize();

  // Initialize Firebase
  await Firebase.initializeApp(
    // Replace with actual values
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // Wrap your app with Provider
    Provider<FirestoreProvider>.value(
      value: firestoreProvider,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:leagueit/app_settings.dart';
import 'package:leagueit/auth/auth_controller.dart';
import 'package:leagueit/firebase_options.dart';
import 'home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await authController.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appSettings, authController]),
      builder: (context, _) {
        final ThemeData light = ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ThemeData.light().colorScheme.copyWith(
            primary: Colors.green,
            secondary: Colors.greenAccent,
            surface: Colors.white,
          ),
          textTheme: ThemeData.light().textTheme,
        );
        final ThemeData dark = ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0D0D0D),
          cardColor: const Color(0xFF1E1E1E),
          colorScheme: ThemeData.dark().colorScheme.copyWith(
            primary: Colors.greenAccent,
            secondary: Colors.lightGreenAccent,
            surface: const Color(0xFF121212),
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: appSettings.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: light,
          darkTheme: dark,
          home: LeagueItHomePage(key: homeKey),
        );
      },
    );
  }
}

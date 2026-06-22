import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:leagueit/app_settings.dart';
import 'package:leagueit/auth/auth_controller.dart';
import 'package:leagueit/firebase_options.dart';
import 'home/home_page.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await appSettings.init();
  await authController.init();
  runApp(const MyApp());
  unawaited(pushNotificationService.init());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appSettings, authController]),
      builder: (context, _) {
        final baseLight = ThemeData.light();
        final ThemeData light = ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.white,
          cardColor: Colors.white,
          colorScheme: baseLight.colorScheme.copyWith(
            primary: Colors.green,
            secondary: Colors.greenAccent,
            surface: Colors.white,
          ),
          textTheme: baseLight.textTheme,
        );
        final baseDark = ThemeData.dark();
        final ThemeData dark = ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0D0D0D),
          cardColor: const Color(0xFF1E1E1E),
          colorScheme: baseDark.colorScheme.copyWith(
            primary: const Color(0xFF54B37B),
            secondary: const Color(0xFF8FE7AF),
            surface: const Color(0xFF121212),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D0D0D),
            foregroundColor: Color(0xFFF5F7F2),
            surfaceTintColor: Colors.transparent,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF171B19),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF2A322D)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF2A322D)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF54B37B),
                width: 1.5,
              ),
            ),
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: appSettings.themeMode,
          theme: light,
          darkTheme: dark,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final textScale = appSettings.largeTextMode ? 1.08 : 1.0;
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          navigatorObservers: [appRouteObserver],
          home: ShowCaseWidget(
            enableAutoScroll: true,
            disableMovingAnimation: true,
            builder: (context) => LeagueItHomePage(key: homeKey),
          ),
        );
      },
    );
  }
}

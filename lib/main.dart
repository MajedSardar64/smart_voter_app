import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/theme_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.initTheme();
  runApp(const SmartVoterApp());
}

class SmartVoterApp extends StatelessWidget {
  const SmartVoterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF00382E),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );

        return MaterialApp(
          title: 'স্মার্ট ভোটার ইনফো',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF004D40),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF004D40),
              primary: const Color(0xFF004D40),
              secondary: const Color(0xFF00695C),
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.notoSansBengaliTextTheme(
              ThemeData.light().textTheme,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0.5,
              centerTitle: true,
              titleTextStyle: GoogleFonts.notoSansBengali(
                color: const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF00695C),
            scaffoldBackgroundColor: const Color(0xFF0B131E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00695C),
              primary: const Color(0xFF00897B),
              secondary: const Color(0xFF26A69A),
              surface: const Color(0xFF152232),
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.notoSansBengaliTextTheme(
              ThemeData.dark().textTheme,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF152232),
              foregroundColor: Colors.white,
              elevation: 0.5,
              centerTitle: true,
              titleTextStyle: GoogleFonts.notoSansBengali(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
// import 'screens/profile_screen.dart';
// import 'screens/start_screen.dart';
import 'screens/signup_screen.dart';
// import 'screens/rating_screen.dart';


void main() => runApp(const MovieLogApp());

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      //home: const ProfileScreen(),
      // home: const StartScreen(),
      home: const SignUpScreen(),
      // home: const RatingScreen(),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    navigate();
  }

  void navigate() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    String? levelId = prefs.getString('level_id');

    String route;

    if (userId == null || levelId == null) {
      route = '/login';
    } else if (levelId == '4') {
      route = '/HrDashboard';
    } else if (levelId == '7') {
      route = '/VisitorsFooter';
    } else {
      route = '/home';
    }

    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/hrms_logo.png', // your image
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'visitor_form_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  String? userId = prefs.getString('user_id');
  String? levelId = prefs.getString('level_id');

  String initialRoute;
  if (userId == null || levelId == null) {
    initialRoute = '/login';
  } else if (levelId == '7') {
    initialRoute = '/visitorForm';
  } else {
    initialRoute = '/home';
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sidebar App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: initialRoute,
      routes: {
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        '/visitorForm': (context) => const VisitorFormPage(),
      },
    );
  }
}

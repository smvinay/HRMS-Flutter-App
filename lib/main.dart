import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures async execution before runApp()
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  
  // Check stored values
  String? userId = prefs.getString('user_id');
  // String? levelId = prefs.getString('level_id');
  // String? employeeCode = prefs.getString('employee_code');

  // runApp(MyApp(initialRoute: (userId != null && levelId != null && employeeCode != null) ? '/home' : '/login'));
  runApp(MyApp(initialRoute: (userId != null ) ? '/home' : '/login'));
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
      initialRoute: initialRoute, // Set the route dynamically
      routes: {
        '/home': (context) => HomePage(),
        '/profile': (context) => Scaffold(
              appBar: AppBar(title: const Text("Profile")),
              body: const Center(child: Text("Profile Page")),
            ),
        '/settings': (context) => Scaffold(
              appBar: AppBar(title: const Text("Settings")),
              body: const Center(child: Text("Settings Page")),
            ),
               '/login': (context) => LoginPage(),

      },
    );
  }
}

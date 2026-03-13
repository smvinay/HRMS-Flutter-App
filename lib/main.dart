import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ComingSoonPage.dart';
import 'employeePages/AttendanceCal.dart';
import 'employeePages/leaveCal.dart';
import 'employeePages/profile_page.dart';
import 'hrPages/MyTeamPage.dart';
import 'hrPages/hr_dashboard.dart';
import 'visitorPages/VisitorDashboardPage.dart';
import 'employeePages/home_page.dart';
import 'login_page.dart';
import 'visitorPages/VisitorsFooter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  String? userId = prefs.getString('user_id');
  String? levelId = prefs.getString('level_id');

  String initialRoute;
  if (userId == null || levelId == null) {
    initialRoute = '/login';
  } else if (levelId == '4') {
    initialRoute = '/HrDashboard';
  } else if (levelId == '7') {
    initialRoute = '/VisitorsFooter';
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

      theme: ThemeData(
        primarySwatch: Colors.blue,

        /// Default page background
        scaffoldBackgroundColor: Colors.white,

        /// Default AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
        ),

        /// Drawer background
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
        ),

        /// Card color
        cardColor: Colors.white,
      ),

      // theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: initialRoute,
      routes: {
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),

        '/emp_attendance_cal': (context) => AttendanceCal(),
        '/emp_leave_cal': (context) => LeaveCal(),

        '/VisitorsFooter': (context) => const VisitorsFooter(initialIndex: 2),

        '/HrDashboard': (context) => const HrDashboard(),
        '/myTeam': (context) => MyTeamPage(),
        '/visitors': (context) => ComingSoonPage(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:hrms_attendify_app/hrPages/TeamLeaves.dart';
import 'package:hrms_attendify_app/splash_screen.dart';
import 'employeePages/ApplyLeavePage.dart';
import 'employeePages/AttendanceCal.dart';
import 'employeePages/profile_page.dart';
import 'hrPages/HrVisitorsPage.dart';
import 'hrPages/MyTeamPage.dart';
import 'hrPages/hrEmpAttList.dart';
import 'hrPages/hr_dashboard.dart';
import 'employeePages/home_page.dart';
import 'login_page.dart';
import 'visitorPages/VisitorsFooter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('attendanceBox');
  runApp(MyApp(initialRoute: '/splash'));
}
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sidebar App',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

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
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        // employee login
        '/emp_attendance_cal': (context) => AttendanceCal(),
        '/emp_leave': (context) => ApplyLeavePage(),
        '/profile': (context) => const ProfilePage(),
        // visitor login
        '/VisitorsFooter': (context) => const VisitorsFooter(initialIndex: 2),
        // hr login
        '/HrDashboard': (context) => const HrDashboard(),
        '/myTeam': (context) => MyTeamPage(),
        '/hr_visitors': (context) => HrVisitorsPage(),
        '/hr_empatt': (context) => HrEmployeeAtt(),
        '/hr_empLeave': (context) => TeamLeaves(),

      },
    );
  }
}
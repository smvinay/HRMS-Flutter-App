import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_flutter_app/visitorPages/visitor_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'EmployeeAttendancePage.dart';
import 'Service/employee_attendance_service.dart';
import 'VisitorDrawerPage.dart';
import 'VisitorsFooter.dart';

class VisitorDashboardPage extends StatefulWidget {
  const VisitorDashboardPage({super.key});

  @override
  State<VisitorDashboardPage> createState() => _VisitorDashboardPageState();
}

class _VisitorDashboardPageState extends State<VisitorDashboardPage>
    with SingleTickerProviderStateMixin {

  late EmployeeAttendanceService _empService;
  int visitorsCount = 0;
  int employeesCount = 0;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    loadDashboardCounts();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _empService = EmployeeAttendanceService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _empService.start(context);
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> loadDashboardCounts() async {

    final prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');

    final response = await http.get(
      Uri.parse(
          "https://hrms.attendify.ai/index.php/Dashboard/getDashboardCountsapi"),
      headers: {
        'apiKey': apiKey ?? '',
        'companyDb': companyDb ?? '',
      },
    );

    if (response.statusCode == 200) {

      final data = json.decode(response.body);

      if (data['status'] == true) {

        setState(() {
          visitorsCount = data['data']['visitors_today'];
          employeesCount = data['data']['employees_today'];
        });

      }
    }
  }

  Widget dashboardCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.9),
                color.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            children: [

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 14),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      // appBar: const VisitorHeader(),
      drawer: const VisitorDrawerPage(currentPage: "home"),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Overview",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd-MM-yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            dashboardCard(
              title: "Today's Visitors",
              count: visitorsCount,
              icon: Icons.groups,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VisitorsFooter(initialIndex: 0),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            dashboardCard(
              title: "Employees",
              count: employeesCount,
              icon: Icons.badge,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeAttendancePage(),
                  ),
                );
              },
            ),


          ],
        ),
      ),
    );
  }
}
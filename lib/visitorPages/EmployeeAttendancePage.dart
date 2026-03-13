import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart';
import 'package:my_flutter_app/visitorPages/visitor_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'VisitorDrawerPage.dart';
import 'VisitorsFooter2.dart';

class EmployeeAttendancePage extends StatefulWidget {
  const EmployeeAttendancePage({super.key});

  @override
  State<EmployeeAttendancePage> createState() => _EmployeeAttendancePageState();
}

class _EmployeeAttendancePageState extends State<EmployeeAttendancePage> {

  List employees = [];
  bool loading = true;

  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadAttendance();
  }

  Future<void> loadAttendance() async {

    setState(() => loading = true);

    String date =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2,'0')}-${selectedDate.day.toString().padLeft(2,'0')}";

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final cid = prefs.getString('cid');
    final companyDb = prefs.getString('companyDb');

    if (apiKey == null || companyDb == null) {
      _showflashbar("Authentication error", Colors.red.shade300);
      return;
    }

    final url = Uri.parse(
        "https://hrms.attendify.ai/index.php/Dashboard/ajax_attendance_listapi?date=$date&cid=$cid");

    try {

      final response = await http.get(
        url,
        headers: {
          'apiKey': apiKey,
          'companyDb': companyDb,
        },
      );

      if (response.statusCode == 200) {

        final data = json.decode(response.body);

        setState(() {
          employees = data["data"] ?? [];
          loading = false;
        });

      } else {
        _showflashbar("Failed to load attendance", Colors.red.shade300);
        setState(() => loading = false);
      }

    } catch (e) {
      _showflashbar("Network error", Colors.red.shade300);
      setState(() => loading = false);
    }
  }

  double _calcScaleFromWidth(double w) {
    const base = 500.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.1);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  @override
  Widget build(BuildContext context) {

    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    return Scaffold(
      appBar: const VisitorHeader(),
      drawer: const VisitorDrawerPage(currentPage: "employees"),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : employees.isEmpty
                ? const Center(child: Text("No attendance records"))
                : RefreshIndicator(
              onRefresh: loadAttendance,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(_s(6, scale)),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final e = employees[index];
                  return _buildEmployeeCard(e, scale);
                },
              ),
            ),
          ),
          const VisitorsFooter2(),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(dynamic e, double scale) {

    final status = e["status_text"] ?? "";
    String name =
    "${e["firstName"] ?? ""}".trim();

    String department = e["departmentname"] ?? '';

    bool isActive = e["trash"] == "0";
    String profile =
        "${e["thumb"] ?? ""}";


    Color statusColor;

    if (status == "IN" || status == "Present") {
      statusColor = Colors.green;
    } else if (status == "OUT") {
      statusColor = Colors.orange;
    } else if (status == "Absent") {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(


        /// PROFILE
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(profile),
        ),

        /// NAME + DEPT
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if(department != '')
            Text(department),

            const SizedBox(height: 4),

            Row(
              children: [

                Text(
                  e["status_time"] ?? " - ",
                  style: TextStyle(
                    fontSize: _s(12, scale),
                  ),
                ),
              ],
            )
          ],
        ),


        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: _s(10, scale),
                vertical: _s(4, scale),
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(_s(20, scale)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: _s(12, scale),
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showflashbar(String message, Color color) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 2),
      backgroundColor: color,
      borderRadius: BorderRadius.circular(8),
      margin: const EdgeInsets.all(12),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }
}
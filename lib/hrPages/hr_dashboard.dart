import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hr_header.dart';
import 'hr_drawer.dart';
import 'hr_footer.dart';


class HrDashboard extends StatefulWidget {
  const HrDashboard({super.key});

  @override
  State<HrDashboard> createState() => _HrDashboardState();
}
class _HrDashboardState extends State<HrDashboard> {

  int present = 0;
  int absent = 0;
  int total = 0;

  int entry = 0;
  int lobby = 0;
  int checkin = 0;
  int checkout = 0;

  @override
  void initState() {
    super.initState();
    fetchDashboardCounts();
  }


  Future<void> fetchDashboardCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('apiKey');
      final companyDb = prefs.getString('companyDb');

      if (apiKey == null || companyDb == null) return;
      // final response = await http.get(
      //   Uri.parse("https://hrms.attendify.ai/index.php/mobileApi/getHrDashboardCounts"),
      // );

      final url = Uri.parse(
          "https://hrms.attendify.ai/index.php/mobileApi/getHrDashboardCounts");

        final response = await http.post(
          url,
          headers: {
            'apiKey': apiKey,
            'companyDb': companyDb,
          },
        );

      final data = json.decode(response.body);

      if (data["status"] == true) {

        setState(() {
          present = data["data"]["employees"]["present"];
          absent = data["data"]["employees"]["absent"];
          total = data["data"]["employees"]["total"];

          entry = data["data"]["visitors"]["entry"];
          lobby = data["data"]["visitors"]["lobby"];
          checkin = data["data"]["visitors"]["checkin"];
          checkout = data["data"]["visitors"]["checkout"];
        });

      }

    } catch (e) {
      print("Dashboard API Error: $e");
    }
  }

  double _calcScaleFromWidth(double w) {
    const base = 475.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = _calcScaleFromWidth(screenWidth);

    return Scaffold(
      appBar: const HrHeader(),
      drawer: HrDrawer(),
      bottomNavigationBar: const HrFooter(selectedIndex: 1),

      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(_s(15, scale)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const Text(
                "Today's Attendance",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              /// Attendance Cards
              _attendanceGrid(scale),

              const SizedBox(height: 10),

              const Text(
                "Visitor Management",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              _layoutVisitorGrid(scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greetingCard(double scale) {
    final hour = DateTime.now().hour;

    String greeting = "Good Morning";
    if (hour >= 12 && hour < 17) greeting = "Good Afternoon";
    if (hour >= 17) greeting = "Good Evening";

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: _s(15, scale)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E88E5),
            Color(0xFF42A5F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [

          /// Floating bubbles
          Positioned(
            top: -10,
            right: 20,
            child: _bubble(40),
          ),
          Positioned(
            bottom: -15,
            left: 30,
            child: _bubble(45),
          ),
          Positioned(
            top: -5,
            left: 5,
            child: _bubble(25),
          ),
          Positioned(
            top: 20,
            right: 80,
            child: _bubble(20),
          ),

          /// Content
          Padding(
            padding: EdgeInsets.all(_s(18, scale)),
            child: Row(
              children: [
                Icon(
                  Icons.waving_hand,
                  color: Colors.white,
                  size: _s(28, scale),
                ),

                const SizedBox(width: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _s(18, scale),
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      DateFormat('dd-MM-yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size) {
    return AnimatedContainer(
      duration: const Duration(seconds: 4),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
      ),
    );
  }

  Widget _attendanceCard(
      String title,
      String count,
      Color color,
      IconData icon,
      double scale,
      ) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: _s(16, scale),
        horizontal: _s(14, scale),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(14, scale)),
        border: Border(
          top: BorderSide(color: color, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: _s(8, scale),
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          /// ICON + TITLE
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(_s(6, scale)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: _s(16, scale),
                  color: color,
                ),
              ),

              SizedBox(width: _s(6, scale)),

              Text(
                title,
                style: TextStyle(
                  fontSize: _s(14, scale),
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          SizedBox(height: _s(12, scale)),

          /// CENTER COUNT
          Center(
            child: Text(
              count,
              style: TextStyle(
                fontSize: _s(28, scale),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _attendanceGrid(double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 640 ? 3 : 3;
        double crossAxisRation = constraints.maxWidth > 640 ? 1.5 : 1.5;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: _s(12, scale),
          crossAxisSpacing: _s(12, scale),
          childAspectRatio: crossAxisRation,
          children: [
            _attendanceCard("Total", total.toString(), Colors.blue, Icons.people, scale),
            _attendanceCard("Present", present.toString(), Colors.green, Icons.check_circle, scale),
            _attendanceCard("Absent", absent.toString(), Colors.red, Icons.cancel, scale),
            // _attendanceCard("Leave", "2", Colors.orange, Icons.time_to_leave_sharp,scale,),
          ],
        );
      },
    );
  }

  Widget _layoutVisitorGrid(double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {

        int crossAxisCount = 4;
        double ratio = 1.2;

         crossAxisCount = constraints.maxWidth > 640 ? 4 : 2;
        double crossAxisRation = constraints.maxWidth > 640 ? 1 : 1.7;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: _s(12, scale),
          mainAxisSpacing: _s(12, scale),
          childAspectRatio: crossAxisRation,
          children: [
            _visitorCard("Entry", entry.toString(), Icons.login, Colors.blue, scale),
            _visitorCard("Lobby", lobby.toString(), Icons.meeting_room, Colors.orange, scale),
            _visitorCard("Checked In", checkin.toString(), Icons.person, Colors.green, scale),
            _visitorCard("Checked Out", checkout.toString(), Icons.logout, Colors.red, scale),
          ],
        );
      },
    );
  }

  /// Visitor Cards
  Widget _visitorCard(String title, String count, IconData icon, Color color , double scale,) {
    return Container(
      padding: EdgeInsets.all(_s(15, scale)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_s(12, scale)),
        color: color.withOpacity(0.1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: _s(30, scale), color: color),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(
              fontSize: _s(22, scale),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(title),
        ],
      ),
    );
  }
}
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hr_emp_att.dart';
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
  List attendanceList = [];
  bool attendanceLoading = true;
  bool isExpanded = false;

  String selectedFilter = "all"; // all | present | absent
  @override
  void initState() {
    super.initState();
    fetchDashboardCounts();
    fetchAttendanceList();
  }


  Future<void> fetchDashboardCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('apiKey');
      final companyDb = prefs.getString('companyDb');
      final cid = prefs.getString('cid');

      if (apiKey == null || companyDb == null) return;
      final url = Uri.parse(
          "https://hrms.attendify.ai/index.php/mobileApi/getHrDashboardCounts");

        final response = await http.post(
          url,
          headers: {
            'apiKey': apiKey,
            'companyDb': companyDb,
          },
          body: {
            'cid' : cid
          }
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

  Future<void> fetchAttendanceList() async {

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final cid = prefs.getString('cid');
    final companyDb = prefs.getString('companyDb');

    if (apiKey == null || companyDb == null) return;

    String date = DateFormat("yyyy-MM-dd").format(DateTime.now());

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
          attendanceList = data["data"] ?? [];
          attendanceLoading = false;
        });

      }

    } catch (e) {
      print("Attendance API error: $e");
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

        body: RefreshIndicator(
          onRefresh: () async {
           await fetchDashboardCounts();
           await fetchAttendanceList();
          },
          child: SingleChildScrollView(
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

              _attendanceListCard(scale),

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
      ),
    );
  }

  Widget _attendanceCard(
      String title,
      String count,
      Color color,
      IconData icon,
      double scale,
      String filterType,
      ) {
    bool isActive = selectedFilter == filterType;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = filterType;
          isExpanded = false;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,

        padding: EdgeInsets.symmetric(
          vertical: _s(10, scale),
          horizontal: _s(10, scale),
        ),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_s(12, scale)),

          /// ✅ ALWAYS TOP BORDER (thicker now)
          border: Border(
            top: BorderSide(
              color: color,
              width: isActive ? 5 : 4, // 🔥 thicker + slight active boost
            ),
          ),


          /// ✅ SHADOW
          boxShadow: isActive
              ? [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            /// ICON
            Container(
              padding: EdgeInsets.all(_s(4, scale)),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: _s(20, scale),
                color: color,
              ),
            ),

            SizedBox(height: _s(5, scale)),

            /// TITLE
            Text(
              title,
              style: TextStyle(
                fontSize: _s(12, scale),
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            SizedBox(height: _s(5, scale)),

            /// COUNT
            Text(
              count,
              style: TextStyle(
                fontSize: _s(20, scale),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List getFilteredList() {
    if (selectedFilter == "present") {
      return attendanceList.where((e) {
        String status = (e['status_text'] ?? "")
            .toString()
            .trim()
            .toUpperCase();

        return status == "IN" ||
            status == "OUT" ||
            status == "PRESENT" ||
            status == "HALF DAY" ||
            status == "HALF_DAY";
      }).toList();

    } else if (selectedFilter == "absent") {
      return attendanceList.where((e) {
        String status = (e['status_text'] ?? "")
            .toString()
            .trim()
            .toUpperCase();

        return status.isEmpty || status == "ABSENT";
      }).toList();
    }

    return attendanceList;
  }

  Widget _attendanceGrid(double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 640 ? 3 : 3;
        double crossAxisRation = constraints.maxWidth > 640 ? 1.4 : 1.2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: _s(12, scale),
          crossAxisSpacing: _s(12, scale),
          childAspectRatio: crossAxisRation,
          children: [
            _attendanceCard("Total", total.toString(), Colors.blue, Icons.people, scale, "all"),
            _attendanceCard("Present", present.toString(), Colors.green, Icons.check_circle, scale, "present"),
            _attendanceCard("Absent", absent.toString(), Colors.red, Icons.cancel, scale, "absent"),
          ],
        );
      },
    );
  }


  Widget _attendanceListCard(double scale) {

    final filteredList = getFilteredList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(_s(14, scale)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Row(
                    children: const [
                      Icon(Icons.access_time, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        "Attendance List",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Text(
                        isExpanded ? "Show Less" : "View All",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.blue,
                      )
                    ],
                  )
                ],
              ),

              const SizedBox(height: 10),

              /// 🔥 SMOOTH EXPAND LIST
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Column(
                  children: [

                    if (attendanceLoading)
                      const Center(child: CircularProgressIndicator())

                    else if (filteredList.isEmpty)
                      const Text("No attendance data")

                    else
                      ...filteredList
                          .take(isExpanded ? filteredList.length : 5)
                          .map((item) => _attendanceRow(item, scale))
                          .toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "- - -";

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;

      return '$hour12:$minute $period';
    } catch (e) {
      print("Time parsing error: $e");
      return "- - -";
    }
  }


  Widget _attendanceRow(Map item, double scale) {

    String status = (item['status_text'] ?? "").toString().toUpperCase();

    Color statusColor;

    switch (status) {
      case "IN":
        statusColor = Colors.blue;
        break;
      case "OUT":
        statusColor = Colors.red;
        break;
      case "PRESENT":
        statusColor = Colors.green;
        break;
      case "HALF DAY":
      case "HALF_DAY":
        statusColor = Colors.orange;
        break;
      case "ABSENT":
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    final status_time = (item['status_time'] != null && item['status_time'].toString().isNotEmpty)
        ? item['status_time']
        : "";

    String statusText = item['status_text'] ?? "";
    String statusTime = item['status_time'] ?? "";

    String badgeText = statusText;

    if (statusText == "IN" || statusText == "OUT") {
      badgeText = "$statusText $statusTime";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [

          /// 🔥 LEFT SIDE (CLICK → NAVIGATION)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HrAttendanceCal(
                    employeeCode: item['emp_code'], // must come from API
                  ),
                ),
              );
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(item['thumb']),
                ),

                const SizedBox(width: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      item['firstName'] ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Text(
                      item['designationName'] ?? "",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          /// 🔥 RIGHT SIDE (CLICK → EXPAND)
          GestureDetector(
            onTap: () {
              setState(() {
                isExpanded = !isExpanded;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [

                if (item['first_check_in'] != null)
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: "Login ",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        TextSpan(
                          text: _formatTime(item['first_check_in']),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 2),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _layoutVisitorGrid(double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {

        int crossAxisCount = 4;
        double ratio = 1.2;

         crossAxisCount = constraints.maxWidth > 640 ? 4 : 2;
        double crossAxisRation = constraints.maxWidth > 640 ? 1 : 1.5;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: _s(12, scale),
          mainAxisSpacing: _s(12, scale),
          childAspectRatio: crossAxisRation,
          children: [
            _visitorCard("Captured", entry.toString(), Icons.login, Colors.blue, scale),
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
          const SizedBox(height: 8),
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
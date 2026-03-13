import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {

  Map employee = {};
  List referencePhotos = [];
  bool isLoading = true;

  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    fetchEmployeeDetails();
  }

  Future<void> fetchEmployeeDetails() async {
    try {

      final prefs = await SharedPreferences.getInstance();

      String? apiKey = prefs.getString('apiKey');
      String? companyDb = prefs.getString('companyDb');
      String? cid = prefs.getString('cid');
      String? levelId = prefs.getString('level_id');
      String? employeeCode = prefs.getString('employe_code');
      final response = await http.get(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/mobileApi/employee_details?cid=$cid&level_id=$levelId&employeeCode=$employeeCode"),
        headers: {
          'apiKey': apiKey ?? '',
          'companyDb': companyDb ?? '',
        },
      );

      print(response.body); // DEBUG

      final jsonData = json.decode(response.body);

      if (jsonData["status"] == true) {
        employee = jsonData["data"];
        referencePhotos = jsonData["reference_photos"];
      }

      setState(() {
        isLoading = false;
      });

      _controller.forward();

    } catch (e) {

      print("ERROR: $e");

      setState(() {
        isLoading = false;
      });

    }
  }

  double scaleWidth(double width, double size) {
    return (width / 400) * size;
  }

  Widget buildTile(String title, String value, IconData icon, double width) {
    return Container(
      margin: EdgeInsets.only(bottom: scaleWidth(width, 12)),
      padding: EdgeInsets.all(scaleWidth(width, 14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          SizedBox(width: scaleWidth(width, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: scaleWidth(width, 12),
                        color: Colors.grey)),
                Text(value,
                    style: TextStyle(
                        fontSize: scaleWidth(width, 15),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (employee.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Failed to load profile")),
      );
    }

    final profileImage =
        "https://hrms.attendify.ai/photos/${employee['user_profile']}";

    return Scaffold(
      backgroundColor: const Color(0xfff2f4f7),
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF0557a2),
        foregroundColor: Colors.white,
      ),
      body: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [

              /// PROFILE CARD
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 40, end: 0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    children: [

                      /// PROFILE IMAGE
                      CircleAvatar(
                        radius: 45,
                        backgroundImage: NetworkImage(profileImage),
                      ),

                      const SizedBox(width: 12),

                      /// DETAILS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text(
                              employee['first_name'] ?? '',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),

                            // const SizedBox(height: 4),
                            //
                            // Text(
                            //   employee['designationName'] ?? '',
                            //   style: const TextStyle(
                            //       fontSize: 13,
                            //       color: Colors.grey),
                            // ),

                            const SizedBox(height: 6),

                            Row(
                              children: [
                                const Icon(Icons.phone, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  employee['contact_number'] ?? '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                const Icon(Icons.email, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    employee['email'] ?? '',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                const Icon(Icons.apartment, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  employee['departmentname'] ?? '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// REPORTING CARD
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 50, end: 0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    children: [

                      const Icon(Icons.supervisor_account, color: Colors.blue),

                      const SizedBox(width: 10),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          const Text(
                            "Reporting Manager",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            employee['reporting_to_name'] ?? '',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// EXTRA INFO CARD
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  children: [

                    _infoRow("Employee Code", employee['employe_code']),
                    _infoRow("Shift", employee['shiftName']),
                    _infoRow("Date of Joining", employee['doj']),
                    _infoRow("Address", employee['address']),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value ?? "-",
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
      ),
    );
  }

}
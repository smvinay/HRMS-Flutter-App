import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../global_state.dart';
import '../login_page.dart';
import 'home_page.dart';

class CustomDrawer extends StatefulWidget {
  final String currentRoute;
  final int pendingCount;

  const CustomDrawer({
    Key? key,
    required this.currentRoute,
    this.pendingCount = 0,
  }) : super(key: key);

  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}


class _CustomDrawerState extends State<CustomDrawer> {
  String _username = "Loading...";
  String _email = "Loading...";
  String _userProfile = "";


  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load username and email from SharedPreferences
  Future<void> _loadUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "- - -";
      _email = prefs.getString('email') ?? "- - -";
      _userProfile = prefs.getString('user_profile') ?? "";

    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [

          ///  FULL TOP HEADER
          UserAccountsDrawerHeader(
            margin: EdgeInsets.zero,
            accountName: Text(
              _username,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              _email,
              style: const TextStyle(fontSize: 13),
            ),
            currentAccountPicture: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: _userProfile.isNotEmpty
                    ? Image.network(
                  "https://hrms.attendify.ai/photos/$_userProfile",
                  width: 66,
                  height: 66,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      "assets/profile.jpg",
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    );
                  },
                )
                    : Image.asset(
                  "assets/profile.jpg",
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0557a2),
            ),
          ),

          ///  SCROLLABLE MENU
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [

                _buildDrawerItem(Icons.home, "Home", '/home', () {
                  Navigator.pushReplacementNamed(context, '/home');
                }),

                _buildDrawerItem(Icons.calendar_month, "Attendance", '/emp_attendance_cal', () {
                  Navigator.pushNamed(context, '/emp_attendance_cal');
                }),
                _buildDrawerItem(Icons.calendar_today , "Leave", '/emp_leave', () {
                  Navigator.pushNamed(context, '/emp_leave');
                }),
                _buildDrawerItem(Icons.person, "Profile", '/profile', () {
                  Navigator.pushNamed(context, '/profile');
                }),

                // _buildDrawerItem(Icons.calendar_month_sharp, "Team Leave", '/hr_empLeave', () {
                //   Navigator.pushNamed(context, '/hr_empLeave');
                // }),
                // _buildDrawerItemWithBadge(
                //   Icons.calendar_month_sharp,
                //   "Team Leave",
                //   '/hr_empLeave',
                //   widget.pendingCount,
                //       () {
                //     Navigator.pushNamed(context, '/hr_empLeave');
                //   },
                // ),

              ],
            ),
          ),

          ///  FIXED LOGOUT + SAFE BOTTOM
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),

                _buildDrawerItem(Icons.logout, "Logout", 'Logout', () {
                  _showLogoutDialog(context);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Drawer Item Widget
  Widget _buildDrawerItem(
      IconData icon,
      String title,
      String routeName,
      VoidCallback onTap,
      ) {
    bool isActive = widget.currentRoute == routeName;

    return Container(
      color: isActive ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFF0557a2) : Colors.black87,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF0557a2) : Colors.black,
          ),
        ),
        onTap: () {
          if (!isActive) {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onTap();
            });
          } else {
            Navigator.pop(context); // just close drawer if same page
          }
        },
      ),
    );
  }

  Widget _buildDrawerItemWithBadge(
      IconData icon,
      String title,
      String routeName,
      int count,
      VoidCallback onTap,
      ) {
    bool isActive = widget.currentRoute == routeName;

    return Container(
      color: isActive ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFF0557a2) : Colors.black87,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                  isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? const Color(0xFF0557a2)
                      : Colors.black,
                ),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: pendingLeaveNotifier,
              builder: (context, count, _) {
                if (count <= 0) return const SizedBox();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0557A2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF0557A2).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    "${count > 99 ? '99+' : count}",
                    style: const TextStyle(
                      color: Color(0xFF0557A2),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            )
          ],
        ),
        onTap: () {
          if (!isActive) {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onTap();
            });
          } else {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [

            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),

            TextButton(
              child: const Text("Logout"),
              onPressed: () async {

                final prefs = await SharedPreferences.getInstance();
                await updateLogoutPushId();
                ///  Save companyCode
                String? companyCode = prefs.getString('companyCode');
                String? pushSubscriptionId = prefs.getString('pushSubscriptionId');

                ///  CLEAR SHARED PREFS
                await prefs.clear();

                ///  RESTORE companyCode
                if (companyCode != null) {
                  await prefs.setString('companyCode', companyCode);
                }

                if (pushSubscriptionId != null) {
                  await prefs.setString('pushSubscriptionId', pushSubscriptionId);
                }

                ///  CLEAR HIVE CACHE
                final box = Hive.box('attendanceBox');
                await box.clear();

                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> updateLogoutPushId() async {
    final prefs = await SharedPreferences.getInstance();
    String? playerId = prefs.getString('pushSubscriptionId');
    String? userId = prefs.getString('user_id');
    String apiKey = prefs.getString('apiKey') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";

    if (playerId == null) return;

    await http.post(
      Uri.parse("https://hrms.attendify.ai/index.php/MobileApi/update_push_id"),
      headers: {
        "apiKey": apiKey,
        "companyDb": companyDb,
      },
      body: {
        "user_id": userId,
        "pushSubscriptionId": playerId,
        "status": "0", // LOGOUT
      },
    );
  }

}

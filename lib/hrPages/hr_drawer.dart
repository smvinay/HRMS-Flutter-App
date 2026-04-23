import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HrDrawer extends StatefulWidget {
  @override
  _HrDrawerState createState() => _HrDrawerState();
}

class _HrDrawerState extends State<HrDrawer> {
  String _username = "Hr";
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

          /// ✅ FULL TOP HEADER (NO PADDING)
          SizedBox(
            height: 110,
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0557a2),
              ),
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/alogo.png',
                        width: 33,
                        height: 33,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                   Text(
                    _username,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// ✅ SCROLLABLE MENU
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _item(context, Icons.dashboard, "Home", route: "/HrDashboard"),
                _item(context, Icons.groups, "Employees", route: "/myTeam"),
                _item(context, Icons.access_time, "Attendance", route: "/hr_empatt"),
                _item(context, Icons.person, "Visitors", route: "/hr_visitors"),
              ],
            ),
          ),

          /// ✅ ONLY BOTTOM SAFE
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),
                _item(
                  context,
                  Icons.logout,
                  "Logout",
                  onTap: () {
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Logout Dialog
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

                /// Save companyCode
                String? companyCode = prefs.getString('companyCode');
                String? pushSubscriptionId = prefs.getString('pushSubscriptionId');
                await updateLogoutPushId();
                /// Clear all data
                await prefs.clear();

                /// Restore companyCode
                if (companyCode != null) {
                  await prefs.setString('companyCode', companyCode);
                }
                if (pushSubscriptionId != null) {
                  await prefs.setString('pushSubscriptionId', pushSubscriptionId);
                }

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

  /// Drawer Item
  Widget _item(
    BuildContext context,
    IconData icon,
    String title, {
    String? route,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, route);
          });
          // Navigator.pushNamed(context, route);
        }
      },
    );
  }
}

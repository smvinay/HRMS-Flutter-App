import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HrDrawer extends StatefulWidget {
  @override
  _HrDrawerState createState() => _HrDrawerState();
}

class _HrDrawerState extends State<HrDrawer> {
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
                  const Text(
                    'HR',
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

          _item(context, Icons.dashboard, "Home", route: "/HrDashboard"),

          _item(context, Icons.groups, "My Team", route: "/myTeam"),

          _item(context, Icons.access_time, "Attendance", route: "/attendance"),

          // _item(context, Icons.event_note, "Leaves Track", route: "/leaves"),

          // _item(context, Icons.payment, "Pay Slips", route: "/payslips"),

          // _item(context, Icons.apartment, "Department", route: "/department"),

          _item(context, Icons.person, "Visitors", route: "/visitors"),

          const Spacer(),
          const Divider(),

          /// Logout Button
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

                /// Clear all data
                await prefs.clear();

                /// Restore companyCode
                if (companyCode != null) {
                  await prefs.setString('companyCode', companyCode);
                }

                Navigator.pop(context);

                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        );
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
          Navigator.pushNamed(context, route);
        }
      },
    );
  }
}

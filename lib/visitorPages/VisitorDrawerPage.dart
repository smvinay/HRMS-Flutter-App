import 'package:flutter/material.dart';
import 'package:my_flutter_app/visitorPages/visitor_form_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'VisitorDashboardPage.dart';
import 'VisitorsFooter.dart';
import 'ArchivePage.dart';
import 'EmployeeAttendancePage.dart';

class VisitorDrawerPage extends StatelessWidget {

  final String currentPage;

  const VisitorDrawerPage({super.key, required this.currentPage});

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
                    'Receptionist',
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

          /// HOME
          _buildDrawerItem(
            context,
            Icons.home,
            "Home",
            "home",
             () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VisitorsFooter(initialIndex: 2),
                ),
              );
            },
          ),

          /// HOME
          _buildDrawerItem(
            context,
            Icons.directions_walk,
            "Visitors",
            "visitors",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VisitorsFooter(initialIndex: 0)),
              );
            },
          ),

          /// ARCHIVE
          _buildDrawerItem(
            context,
            Icons.archive,
            "Archives",
            "archive",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivePage()),
              );
            },
          ),

          _buildDrawerItem(
            context,
            Icons.person_2,
            "Employees",
            "employees",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeeAttendancePage()),
              );
            },
          ),

          const Spacer(),
          const Divider(),

          /// LOGOUT
          _buildDrawerItem(
            context,
            Icons.logout,
            "Logout",
            "logout",
                () {
              _showLogoutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  /// Drawer Item
  Widget _buildDrawerItem(
      BuildContext context,
      IconData icon,
      String title,
      String pageKey,
      VoidCallback onTap,
      ) {

    bool isActive = currentPage == pageKey;

    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFF0557a2) : Colors.black87,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? const Color(0xFF0557a2) : Colors.black87,
        ),
      ),
      tileColor: isActive ? Colors.blue.shade50 : null,

      onTap: () {

        Navigator.pop(context);

        /// Prevent opening same page
        if (isActive) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          onTap();
        });

      },
    );
  }

  /// Logout Dialog
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

                /// Save companyCode before clearing
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
}
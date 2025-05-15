import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorDrawerPage extends StatelessWidget {
  const VisitorDrawerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          SizedBox(
            height: 110, // Set the desired smaller height
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0557a2),
              ),
              margin: EdgeInsets.zero,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/profile.jpg', // ✅ Default image
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

          _buildDrawerItem(
            icon: Icons.home,
            title: 'Home',
            onTap: () {
              Navigator.pop(context);
              // Navigate to Home if needed
            },
          ),
          _buildDrawerItem(
            icon: Icons.edit_note,
            title: 'Entry Forms',
            onTap: () {
              Navigator.pop(context);
              // Example: Navigator.pushNamed(context, '/visitorForm');
            },
          ),
          _buildDrawerItem(
            icon: Icons.archive,
            title: 'Archives',
            onTap: () {
              Navigator.pop(context);
              // Navigate to archives
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () {
              _showLogoutDialog(context);
              // Navigate to archives
            },
          ),
        ],
      ),
    );
  }

  // Reusable drawer item widget
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}


// Logout Confirmation Dialog
void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Logout"),
            onPressed: () async {
              final SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Clear stored data
              Navigator.of(context).pop(); // Close the dialog
              Navigator.pushReplacementNamed(context, '/login'); // Navigate to login
            },
          ),
        ],
      );
    },
  );
}

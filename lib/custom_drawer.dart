import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'home_page.dart';

class CustomDrawer extends StatefulWidget {
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
          UserAccountsDrawerHeader(
            accountName: Text(
              _username ,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              _email,
              style: const TextStyle(fontSize: 13), 
            ),
             currentAccountPicture: CircleAvatar(
              radius: 18, // Make the image smaller
              backgroundColor: Colors.white,
              child: ClipOval(
                child: _userProfile.isNotEmpty
                    ? Image.network(
                        "https://app.attendify.ai/template/public/photos/$_userProfile",
                        width: 60, // Set size of image
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset("assets/profile.jpg", width: 60, height: 60, fit: BoxFit.cover);
                        },
                      )
                    : Image.asset("assets/profile.jpg", width: 60, height: 60, fit: BoxFit.cover),
              ),
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0557a2), // Custom header color
            ),
          ),
          _buildDrawerItem(Icons.home, "Home", () {
            Navigator.pushReplacementNamed(context, '/home');
          }),
          _buildDrawerItem(Icons.person, "Profile", () {
            Navigator.pushNamed(context, '/profile');
          }),
          _buildDrawerItem(Icons.settings, "Settings", () {
            Navigator.pushNamed(context, '/settings');
          }),
          _buildDrawerItem(Icons.logout, "Logout", () {
            _showLogoutDialog(context);
          }),
        ],
      ),
    );
  }

  // Drawer Item Widget
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
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
}

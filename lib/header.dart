import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Header extends StatefulWidget implements PreferredSizeWidget {
  const Header({Key? key}) : super(key: key);

  @override
  _HeaderState createState() => _HeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HeaderState extends State<Header> {
  String _employeeCode = "Loading...";
  String _userProfile = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load Employee Code & Profile from SharedPreferences
  Future<void> _loadUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeCode = prefs.getString('employe_code') ?? "- - -";
      _userProfile = prefs.getString('user_profile') ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0557a2),
      title: Text(
        _employeeCode, // ✅ Employee Code
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      leading: IconButton(
        icon: CircleAvatar(
          radius: 18, // Smaller profile icon
          backgroundColor: Colors.white,
          child: ClipOval(
            child: _userProfile.isNotEmpty
                ? Image.network(
                    "https://app.attendify.ai/office_webApiMDB/public/photos/$_userProfile",
                    width: 30, height: 30, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset("assets/profile.jpg", width: 30, height: 30, fit: BoxFit.cover);
                    },
                  )
                : Image.asset("assets/profile.jpg", width: 30, height: 30, fit: BoxFit.cover),
          ),
        ),
        onPressed: () {
          Scaffold.of(context).openDrawer(); // ✅ Open drawer
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white), // ✅ Bell icon
          onPressed: () {
            // TODO: Add notification functionality
          },
        ),
      ],
    );
  }
}

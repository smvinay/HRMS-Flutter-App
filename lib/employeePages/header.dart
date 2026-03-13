import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'EmpNotificationPage.dart';

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
      leadingWidth: 50,        // Reduce space for menu area
      titleSpacing: 5,         // Remove extra space before title


      title: Text(
        _employeeCode,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
      ),

      /// Menu Icon instead of Profile
      leading: IconButton(
        icon: const Icon(
          Icons.menu,
          color: Colors.white,
          size: 26,
        ),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),

      actions: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmpNotificationPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

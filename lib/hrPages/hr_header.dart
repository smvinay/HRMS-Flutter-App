import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HrHeader extends StatefulWidget implements PreferredSizeWidget {
  const HrHeader({Key? key}) : super(key: key);

  @override
  _HrHeaderState createState() => _HrHeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HrHeaderState extends State<HrHeader> {
  String employeeCode = "";

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      employeeCode = prefs.getString('employe_code') ?? "---";
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0557A2),
      titleSpacing: 5,
      title: Text(
        'HR',
        style: const TextStyle(color: Colors.white),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: () {
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(
            //     builder: (context) => EmpNotificationPage(),
            //   ),
            // );
          },
        )
      ],
    );
  }
}
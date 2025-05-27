import 'package:flutter/material.dart';

import 'VisitorsHomePage.dart';

class VisitorHeader extends StatelessWidget implements PreferredSizeWidget {
  const VisitorHeader({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0557a2),
      title: const Text(
        'Receptionist',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      leading: Builder(
        builder: (BuildContext context) {
          return IconButton(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image.asset(
                  'assets/profile.jpg', // ✅ Default image
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // ✅ Open drawer correctly
            },
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VisitorsHomePage()),
            );
          },
        ),
      ],
    );
  }
}

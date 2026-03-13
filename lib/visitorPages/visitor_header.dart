import 'package:flutter/material.dart';

import 'VisitorsFooter.dart';

class VisitorHeader extends StatelessWidget implements PreferredSizeWidget {
  const VisitorHeader({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0557a2),
      leadingWidth: 50,        // Reduce space for menu area
      titleSpacing: 5,         // Remove extra space before title

      title: const Text(
        'Receptionist',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
    );
  }
}

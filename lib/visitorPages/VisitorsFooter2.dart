import 'package:flutter/material.dart';
import 'VisitorsFooter.dart';

class VisitorsFooter2 extends StatelessWidget {
  const VisitorsFooter2({super.key});

  void openPage(BuildContext context, int index) {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VisitorsFooter(initialIndex: index),
      ),
    );

  }

  Widget footerItem(
      BuildContext context,
      IconData icon,
      String label,
      int index,
      ) {

    return Expanded(
      child: InkWell(
        onTap: () => openPage(context, index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              icon,
              size: 22,
              color: Colors.grey[700],
            ),

            const SizedBox(height: 4),

            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Material(
      color: Colors.white,
      child: Container(
        height: 65,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Row(
          children: [

            footerItem(
              context,
              Icons.directions_walk,
              "Captured",
              0,
            ),

            footerItem(
              context,
              Icons.meeting_room,
              "Lobby",
              1,
            ),

            /// HOME BUTTON
            Expanded(
              child: InkWell(
                onTap: () => openPage(context, 2),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0557A2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.home,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            footerItem(
              context,
              Icons.login,
              "Check In",
              3,
            ),

            footerItem(
              context,
              Icons.logout,
              "Check Out",
              4,
            ),
          ],
        ),
      ),
    );
  }
}
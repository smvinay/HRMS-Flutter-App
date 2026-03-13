import 'package:flutter/material.dart';

class HrFooter extends StatelessWidget {
  final int selectedIndex;

  const HrFooter({super.key, required this.selectedIndex});

  void _onTabSelected(BuildContext context, int index) {
    String route = '';

    if (index == 0) route = '/myTeam';
    if (index == 1) route = '/HrDashboard';
    if (index == 2) route = '/visitors';

    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushNamed(context, route);
    }
  }

  Widget _footerItem(
      BuildContext context, IconData icon, String label, int index) {

    final bool isActive = selectedIndex == index;

    return InkWell(
      onTap: () => _onTabSelected(context, index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Icon(
            icon,
            color: isActive ? const Color(0xFF0557A2) : Colors.grey[600],
            size: 22,
          ),

          const SizedBox(height: 4),

          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF0557A2) : Colors.grey[700],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),

          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 2,
              width: 20,
              color: const Color(0xFF0557A2),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        color: Colors.white,
      ),
      child: Row(
        children: [

          /// TEAM
          Expanded(
            child: _footerItem(
              context,
              Icons.groups,
              "Team",
              0,
            ),
          ),

          /// CENTER HOME BUTTON
          Expanded(
            child: InkWell(
              onTap: () => _onTabSelected(context, 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                ],
              ),
            ),
          ),

          /// VISITORS
          Expanded(
            child: _footerItem(
              context,
              Icons.person,
              "Visitors",
              2,
            ),
          ),
        ],
      ),
    );
  }
}
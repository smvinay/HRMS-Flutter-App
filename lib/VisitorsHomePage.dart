import 'package:flutter/material.dart';
import 'VisitorDrawerPage.dart';
import 'visitor_header.dart';
import 'entries_page.dart';
import 'lobby_page.dart';
import 'checkin_page.dart';
import 'checkout_page.dart';

class VisitorsHomePage extends StatefulWidget {
  const VisitorsHomePage({Key? key}) : super(key: key);

  @override
  State<VisitorsHomePage> createState() => _VisitorsHomePageState();
}

class _VisitorsHomePageState extends State<VisitorsHomePage> {
  int _selectedIndex = 0;

  final List<String> labels = ['Entries', 'Lobby', 'Check In', 'Check Out'];
  final List<IconData> icons = [
    Icons.list_alt,
    Icons.meeting_room,
    Icons.login,
    Icons.logout,
  ];

  final List<Widget> pages = const [
    EntriesPage(),
    LobbyPage(),
    CheckInPage(),
    CheckOutPage(),
  ];

  void onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VisitorHeader(),
      drawer: const VisitorDrawerPage(),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFe0e0e0))),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(icons.length, (index) {
                final isActive = index == _selectedIndex;
                return GestureDetector(
                  onTap: () => onTabSelected(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[index],
                        color: isActive ? Colors.blue : Colors.grey[600],
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        labels[index],
                        style: TextStyle(
                          color: isActive ? Colors.blue : Colors.grey[700],
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          height: 2,
                          width: 20,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}

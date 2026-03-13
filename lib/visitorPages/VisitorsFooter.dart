import 'package:flutter/material.dart';
import 'package:my_flutter_app/visitorPages/visitor_form_page.dart';
import 'VisitorDashboardPage.dart';
import 'VisitorDrawerPage.dart';
import 'visitor_header.dart';
import 'lobby_page.dart';
import 'checkin_page.dart';
import 'checkout_page.dart';

class VisitorsFooter extends StatefulWidget {
  final int initialIndex;
  const VisitorsFooter({Key? key, this.initialIndex = 2}) : super(key: key);

  @override
  State<VisitorsFooter> createState() => _VisitorsFooterState();
}

class _VisitorsFooterState extends State<VisitorsFooter> {
  /// Footer index range: 0..4 (2 == Home)
  int _selectedIndex = 2;
  late PageController _pageController;

  final List<String> labels = [
    'Captured',
    'Lobby',
    'Home',
    'Check In',
    'Check Out'
  ];
  final List<IconData> icons = [
    Icons.directions_walk,
    Icons.meeting_room,
    Icons.home,
    Icons.login,
    Icons.logout,
  ];

  /// PageView contains only 4 pages (Home is NOT part of the PageView)
  final List<Widget> pages = const [
    VisitorFormPage(), // pageIndex 0 -> footer 0
    LobbyPage(),       // pageIndex 1 -> footer 1
    CheckInPage(),     // pageIndex 2 -> footer 3
    CheckOutPage(),    // pageIndex 3 -> footer 4
  ];

  @override
  void initState() {
    super.initState();

    // Use widget.initialIndex as footer index (default 2 = Home)
    _selectedIndex = widget.initialIndex;

    // Convert footer index -> initial PageView index
    // If initial footer index is Home (2) just show page 0 initially (it won't be visible until you leave Home)
    int initialPage = _selectedIndex > 2 ? _selectedIndex - 1 : (_selectedIndex == 2 ? 0 : _selectedIndex);

    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Map footer index -> page index (skipping Home)
  int _footerToPageIndex(int footerIndex) {
    return footerIndex > 2 ? footerIndex - 1 : footerIndex;
  }

  void onTabSelected(int index) {
    // If user tapped Home (center), show dashboard and do not show PageView
    if (index == 2) {
      setState(() => _selectedIndex = 2);
      return;
    }

    final pageIndex = _footerToPageIndex(index);

    // If currently on Home, PageView isn't in tree. First flip to non-home (so PageView appears),
    // then animate after the next frame so the PageView is mounted.
    if (_selectedIndex == 2) {
      setState(() => _selectedIndex = index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      return;
    }

    // Normal case: PageView already visible — animate immediately and update footer highlight.
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _selectedIndex = index);
  }

  Widget _footerItem(int index) {
    final isActive = index == _selectedIndex;

    return InkWell(
      onTap: () => onTabSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[index],
            color: isActive ? Colors.blue : Colors.grey[600],
            size: 22,
          ),
          const SizedBox(height: 4),
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
              margin: const EdgeInsets.only(top: 6),
              height: 2,
              width: 20,
              color: Colors.blue,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const VisitorHeader(),
      drawer: _selectedIndex == 2
          ? const VisitorDrawerPage(currentPage: "home")
          : const VisitorDrawerPage(currentPage: "visitors"),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            // Show dashboard when footer==Home, otherwise show PageView
            child: _selectedIndex == 2
                ? const VisitorDashboardPage()
                : PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (pageIdx) {
                // Map PageView index -> footer index
                final footerIndex = pageIdx >= 2 ? pageIdx + 1 : pageIdx;
                setState(() => _selectedIndex = footerIndex);
              },
              children: pages,
            ),
          ),

          // Footer bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(child: _footerItem(0)),
                Expanded(child: _footerItem(1)),

                // Center home button
                Expanded(
                  child: InkWell(
                    onTap: () => onTabSelected(2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0557A2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.home, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(child: _footerItem(3)),
                Expanded(child: _footerItem(4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'hr_drawer.dart';
import 'hr_footer.dart';
import 'hr_header.dart';

class HrVisitorsPage extends StatefulWidget {
  const HrVisitorsPage({super.key});

  @override
  State<HrVisitorsPage> createState() => _HrVisitorsPageState();
}

class _HrVisitorsPageState extends State<HrVisitorsPage>
    with SingleTickerProviderStateMixin {

  Map data = {};
  bool loading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    loadVisitors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadVisitors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('apiKey');
      final companyDb = prefs.getString('companyDb');
      final cid = prefs.getString('cid');
      if (apiKey == null || companyDb == null || cid == null) return;

      final response = await http.post(
        Uri.parse("https://hrms.attendify.ai/index.php/MobileApi/get_visitors_for_hr_api"),
        headers: {
          'apiKey': apiKey,
          'companyDb': companyDb,
        },
        body: {
          'cid': cid,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true) {
          setState(() {
            data = json['data'];
            loading = false;
          });
        }
      } else {
        print("API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error loading visitors: $e");
    }
  }


  Widget buildList(List list, String status, Color color) {

    if (list.isEmpty) {
      return const Center(child: Text("No Visitors"));
    }
    return RefreshIndicator(
      onRefresh: loadVisitors,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return visitorCard(list[index], status, color);
        },
      ),
    );

  }

  /// STATUS CHIP
  Widget statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "- - -";

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;

      return '$hour12:$minute $period';
    } catch (e) {
      print("Time parsing error: $e");
      return "- - -";
    }
  }

  String getVisitorTime(Map v, String status) {
    if (status == "Captured") {
      return v['check_in_time'] ?? "";
    }

    if (status == "Lobby") {
      return v['form_submit_time'] ?? v['check_in_time'] ?? "";
    }

    if (status == "Check-In") {
      return v['user_approve_time'] ??
          v['form_submit_time'] ??
          v['check_in_time'] ??
          "";
    }

    if (status == "Check-Out") {
      return v['last_check_in'] ??
          v['user_approve_time'] ??
          v['form_submit_time'] ??
          v['check_in_time'] ??
          "";
    }

    return "";
  }

  Widget visitorCard(Map v, String status, Color color) {

    final name = (v['first_name'] ?? "").toString().trim().isEmpty
        ? "Visitor ${v['index'] ?? ''}"
        : v['first_name'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white, // always white
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [

          GestureDetector(
            onTap: () {
              showImage(v['image_path_full']);
            },
            child: CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(v['image_path']),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  _formatTime(getVisitorTime(v, status)),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          statusChip(status, color)

        ],
      ),
    );
  }

  /// SECTION
  Widget section(String title, List list, String status, Color color) {

    if (list.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...list.map((v) => visitorCard(v, status, color)).toList(),
      ],
    );
  }


  void showImage(String image) {
    String url = image;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true, // ✅ click outside to close
      builder: (_) {
        final size = MediaQuery
            .of(context)
            .size;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 40,
          ), // ✅ space around dialog
          child: Stack(
            children: [

              /// Image Container
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  // child: Image.network(url, fit: BoxFit.contain),
                  child: Container(
                    width: size.width * 0.95, // 🔥 slightly reduced
                    constraints: BoxConstraints(
                      maxHeight: size.height * 0.85,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              /// Close Button (Improved UI)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white, // ✅ white background
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    int getCount(String key) {
      if (data[key] == null) return 0;
      return (data[key] as List).length;
    }

    return Scaffold(
      appBar: const HrHeader(),
      drawer: HrDrawer(),
      bottomNavigationBar: const HrFooter(selectedIndex: 2),

      body: Column(
        children: [

          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Text("Captured"),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.blue,
                      child: Text(
                        "${getCount('indexData')}",
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text("Lobby"),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.orange,
                      child: Text(
                        "${getCount('identified')}",
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text("Check-In"),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.green,
                      child: Text(
                        "${getCount('trusted')}",
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text("Check-Out"),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.redAccent,
                      child: Text(
                        "${getCount('checkout')}",
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                buildList(data['indexData'] ?? [], "Captured", Colors.blue),
                buildList(data['identified'] ?? [], "Lobby", Colors.orange),
                buildList(data['trusted'] ?? [], "Check-In", Colors.green),
                buildList(data['checkout'] ?? [], "Check-Out", Colors.red),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
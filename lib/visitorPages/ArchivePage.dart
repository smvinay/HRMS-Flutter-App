import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'VisitorDrawerPage.dart';
import 'VisitorsFooter2.dart';
import 'visitor_header.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {

  List visitors = [];
  bool loading = true;

  String selectedFilter = "all";

  @override
  void initState() {
    super.initState();
    loadVisitors();
  }

  Future<void> loadVisitors() async {

    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final cid = prefs.getString('cid');
    final companyDb = prefs.getString('companyDb');

    if (apiKey == null || companyDb == null) {
      _showflashbar("Authentication error", Colors.red.shade300);
      setState(() => loading = false);
      return;
    }

    String apiUrl =
        'https://hrms.attendify.ai/index.php/Guest/get_archiveMobile?user_id=$cid';

    if (selectedFilter == 'rejected') {
      apiUrl += '&status=rejected';
    } else if (selectedFilter == 'merged') {
      apiUrl += '&status=merged';
    } else if (selectedFilter == 'archive') {
      apiUrl += '&status=archive';
    }

    final url = Uri.parse(apiUrl);

    try {

      final response = await http.get(
        url,
        headers: {
          'apiKey': apiKey,
          'companyDb': companyDb,
        },
      );

      if (response.statusCode == 200) {

        final data = json.decode(response.body);

        setState(() {
          visitors = data["archive"] ?? [];
          loading = false;
        });

      } else {
        _showflashbar("Failed to load archive", Colors.red.shade300);
        setState(() => loading = false);
      }

    } catch (e) {
      _showflashbar("Network error", Colors.red.shade300);
      setState(() => loading = false);
    }
  }

  double _calcScaleFromWidth(double w) {
    const base = 475.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.0);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  @override
  Widget build(BuildContext context) {

    final double scale =
    _calcScaleFromWidth(MediaQuery.of(context).size.width);

    return Scaffold(
      appBar: const VisitorHeader(),
      drawer: const VisitorDrawerPage(currentPage: "archive"),
      body: Column(
        children: [

          /// FILTER DROPDOWN
          // Padding(
          //   padding: EdgeInsets.all(_s(12, scale)),
          //   child: DropdownButtonFormField<String>(
          //     value: selectedFilter,
          //     decoration: InputDecoration(
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(_s(10, scale)),
          //       ),
          //       contentPadding:
          //       EdgeInsets.symmetric(horizontal: _s(12, scale)),
          //     ),
          //     items: const [
          //
          //       DropdownMenuItem(
          //         value: "all",
          //         child: Text("All"),
          //       ),
          //
          //       DropdownMenuItem(
          //         value: "archive",
          //         child: Text("Rejected By Camera"),
          //       ),
          //
          //       DropdownMenuItem(
          //         value: "rejected",
          //         child: Text("Rejected By Host"),
          //       ),
          //
          //       DropdownMenuItem(
          //         value: "merged",
          //         child: Text("Merged"),
          //       ),
          //
          //     ],
          //     onChanged: (value) {
          //       setState(() {
          //         selectedFilter = value!;
          //       });
          //       loadVisitors();
          //     },
          //   ),
          // ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : visitors.isEmpty
                ? const Center(child: Text("No Archive Visitors"))
                : RefreshIndicator(
              onRefresh: loadVisitors,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(_s(10, scale)),
                  itemCount: visitors.length,
                  itemBuilder: (context, index) {

                    final v = visitors[index];

                    String name = "Visitor ${index + 1}";
                    if (v["first_name"] != null && v["first_name"].toString().isNotEmpty) {
                      name = v["first_name"];
                    }

                    String? mergedName;
                    if (v["merge_first_name"] != null &&
                        v["merge_first_name"] != "N/A" &&
                        v["merge_first_name"].toString().isNotEmpty) {
                      mergedName = v["merge_first_name"];
                    }

                    String? remarks;
                    if (v["remarks"] != null &&
                        v["remarks"].toString().isNotEmpty) {
                      remarks = v["remarks"];
                    }

                    String time = "";
                    if (v["check_in_time"] != null) {
                      time = v["check_in_time"].split(" ")[1];
                    }

                    return _buildVisitorListCard(
                      name,
                      mergedName,
                      remarks,
                      time,
                      v["guest_photo"],
                      v["guestid"],
                      index,
                      scale,
                    );
                  },
                )
            ),
          ),

          const VisitorsFooter2(),
        ],
      ),
    );
  }

  void _showflashbar(String message, Color color) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 2),
      backgroundColor: color,
      borderRadius: BorderRadius.circular(8),
      margin: const EdgeInsets.all(12),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  Widget _buildVisitorListCard(
      String name,
      String? mergedName,
      String? remarks,
      String time,
      String photo,
      String guestId,
      int index,
      double scale,
      ) {
    return Container(
      margin: EdgeInsets.only(bottom: _s(10, scale)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(12, scale)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: _s(12, scale),
          vertical: _s(6, scale),
        ),

        leading: ClipRRect(
          borderRadius: BorderRadius.circular(_s(8, scale)),
          child: Image.network(
            "https://hrms.attendify.ai/guest_faces/$photo",
            width: _s(75, scale),
            height: _s(75, scale),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: _s(55, scale),
                height: _s(55, scale),
                color: Colors.grey.shade200,
                child: Icon(Icons.person, size: _s(28, scale)),
              );
            },
          ),
        ),

        title: Text(
          name,
          style: TextStyle(
            fontSize: _s(18, scale),
            fontWeight: FontWeight.w600,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (mergedName != null)
              Row(
                children: [
                  Icon(Icons.merge,
                      size: _s(15, scale),
                      color: Colors.blueGrey),
                  SizedBox(width: _s(5, scale)),
                  Expanded(
                    child: Text(
                      mergedName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _s(15, scale),
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),

            if (remarks != null)
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: _s(13, scale),
                      color: Colors.orange),
                  SizedBox(width: _s(5, scale)),
                  Expanded(
                    child: Text(
                      remarks,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _s(12, scale),
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),

            Row(
              children: [
                Icon(Icons.access_time,
                    size: _s(13, scale),
                    color: Colors.grey),
                SizedBox(width: _s(5, scale)),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: _s(12, scale),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),

        trailing: IconButton(
          icon: const Icon(Icons.unarchive, color: Colors.red),
          onPressed: () {
            _removeArchive(guestId, index);
          },
        ),
      ),
    );
  }

  Future<void> _removeArchive(String guestId, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final companyDb = prefs.getString('companyDb');
    if (apiKey == null || companyDb == null) return;
    final url = Uri.parse(
        "https://hrms.attendify.ai/index.php/Guest/markArchiveVisitor");
    try {
      final response = await http.post(
        url,
        headers: {
          'apiKey': apiKey,
          'companyDb': companyDb,
        },
        body: {
          'guestid': guestId,
          'flag': "0", // remove archive
        },
      );
      final data = json.decode(response.body);
      if (data['status'] == true) {
        setState(() {
          visitors.removeAt(index);
        });
        _showflashbar("Removed from archive", Colors.green.shade300);
      } else {
        _showflashbar("Failed", Colors.red.shade300);
      }
    } catch (e) {
      _showflashbar("Network error", Colors.red.shade300);
    }
  }
}
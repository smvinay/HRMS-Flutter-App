import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {

  List visitors = [];
  bool loading = true;

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
    final loginid = prefs.getString('user_id');
    final companyDb = prefs.getString('companyDb');

    if (apiKey == null || companyDb == null) {
      _showflashbar("Authentication error", Colors.red.shade300);
      setState(() => loading = false);
      return;
    }

    final url = Uri.parse(
        'https://hrms.attendify.ai/index.php/Guest/Guest_Approval_status?user_id=$cid&loginid=$loginid');

    try {
      final response = await http.post(
        url,
        headers: {
          'apiKey': apiKey,
          'companyDb': companyDb,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          visitors = data["checkOut"] ?? [];
          loading = false;
        });
      } else {
        _showflashbar("Failed to load visitors", Colors.red.shade300);
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

  // Placeholder - implement your real approve API here
  Future<void> _approveVisitor(String guestId, int index) async {
    // Show optimistic UI
    setState(() {
      visitors.removeAt(index);
    });
    _showflashbar("Approved", Colors.green.shade300);

    // TODO: call your backend endpoint to approve visitor and handle errors
  }

  // Placeholder - implement your real reject API here
  Future<void> _rejectVisitor(String guestId, int index) async {
    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Reject visitor"),
        content: const Text("Are you sure you want to reject this visitor?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text("Reject")),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      visitors.removeAt(index);
    });
    _showflashbar("Rejected", Colors.orange.shade300);

    // TODO: call your backend endpoint to reject visitor and handle errors
  }

  @override
  Widget build(BuildContext context) {
    final double scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (visitors.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadVisitors,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text("No Check-Out Visitors")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadVisitors,
      child: ListView.separated(
        padding: EdgeInsets.all(_s(12, scale)),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visitors.length,
        separatorBuilder: (_, __) => SizedBox(height: _s(10, scale)),
        itemBuilder: (context, index) {
          final v = visitors[index];

          final String name = (v["first_name"] != null && v["first_name"].toString().isNotEmpty)
              ? v["first_name"]
              : "Visitor ${index + 1}";

          final String phone = v["contact"] ?? "-";
          String time = "-";
          String toMeet = "-";

          if (v["check_in_time"] != null) {
            time = v["check_in_time"].split(" ")[1];
          }

          if (v["user_first_name"] != null && v["user_first_name"].toString().isNotEmpty) {
            toMeet = v["user_first_name"];
          }

          final photo = (v["guest_photo"] ?? "").toString();
          final guestId = (v["guestid"] ?? "").toString();

          return _visitorListCard(
            name: name,
            phone: phone,
            time: time,
            toMeet: toMeet,
            photo: photo,
            guestId: guestId,
            index: index,
            scale: scale,
          );
        },
      ),
    );
  }

  Widget _visitorListCard({
    required String name,
    required String phone,
    required String time,
    required String toMeet,
    required String photo,
    required String guestId,
    required int index,
    required double scale,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_s(12, scale)),
        onTap: () {
          // show details bottom sheet
          _showVisitorDetailsSheet(name, phone, time, toMeet, photo);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.all(_s(10, scale)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_s(12, scale)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(_s(8, scale)),
                child: Image.network(
                  photo.isNotEmpty
                      ? "https://hrms.attendify.ai/guest_faces/$photo"
                      : 'https://via.placeholder.com/100',
                  width: _s(72, scale),
                  height: _s(72, scale),
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    width: _s(72, scale),
                    height: _s(72, scale),
                    color: Colors.grey.shade200,
                    child: Icon(Icons.person, size: _s(36, scale)),
                  ),
                ),
              ),

              SizedBox(width: _s(12, scale)),

              // details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // name + small badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _s(16, scale),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: _s(8, scale), vertical: _s(4, scale)),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Check-out",
                            style: TextStyle(
                              fontSize: _s(11, scale),
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: _s(6, scale)),

                    // phone
                    Row(
                      children: [
                        Icon(Icons.phone, size: _s(14, scale), color: Colors.grey),
                        SizedBox(width: _s(6, scale)),
                        Expanded(
                          child: Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: _s(14, scale)),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: _s(6, scale)),

                    // to meet + time
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: _s(14, scale), color: Colors.grey),
                        SizedBox(width: _s(6, scale)),
                        Expanded(
                          child: Text(
                            toMeet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: _s(14, scale)),
                          ),
                        ),

                        SizedBox(width: _s(8, scale)),

                        Icon(Icons.access_time, size: _s(14, scale), color: Colors.grey),
                        SizedBox(width: _s(6, scale)),
                        Text(
                          time,
                          style: TextStyle(fontSize: _s(13, scale), color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: _s(8, scale)),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisitorDetailsSheet(String name, String phone, String time, String toMeet, String photo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (c) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photo.isNotEmpty ? "https://hrms.attendify.ai/guest_faces/$photo" : 'https://via.placeholder.com/100',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text("To meet: $toMeet"),
                        const SizedBox(height: 4),
                        Text("Time: $time"),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(onPressed: () { Navigator.pop(c); }, child: const Text("Close")),
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
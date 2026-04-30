import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EmpNotificationPage extends StatefulWidget {
  @override
  _EmpNotificationPageState createState() => _EmpNotificationPageState();
}

class _EmpNotificationPageState extends State<EmpNotificationPage> {

  List notifications = [];
  bool isLoading = true;

  String apiDomain = "https://hrms.attendify.ai/index.php/";

  @override
  void initState() {
    super.initState();
    fetchPendingNotifications();
  }

  double scale(BuildContext context, double size){
    double baseWidth = 475;
    double screenWidth = MediaQuery.of(context).size.width;
    return size * (screenWidth / baseWidth);
  }

  Future<void> fetchPendingNotifications() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? userId = prefs.getString('user_id');

    final url = Uri.parse("${apiDomain}Guest/guest_requests?user_id=$userId");

    try {

      final response = await http.get(
        url,
        headers: {
          'apiKey': apiKey ?? '',
          'companyDb': companyDb ?? '',
        },
      );

      final result = json.decode(response.body);
      if(result['status']==true){

        setState(() {
          notifications = result['data'].map((e) {
            e['status'] = int.tryParse(e['status'].toString()) ?? 0;
            e['id'] = int.tryParse(e['id'].toString()) ?? 0;
            return e;
          }).toList();
          isLoading = false;
        });

      }

    } catch(e){
      print(e);
    }

  }

  Widget buildStatusBadge(int status) {
    Color color;
    String text;

    if (status == 1) {
      color = Colors.green;
      text = "Approved";
    } else if (status == 2) {
      color = Colors.red;
      text = "Rejected";
    } else {
      color = Colors.orange;
      text = "Pending";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> updateVisitorStatus(int id, int status, String remark) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');

    final url = Uri.parse("${apiDomain}Guest/update_status");

    try {

      final response = await http.post(
        url,
        headers: {
          "apiKey": apiKey ?? "",
          "companyDb": companyDb ?? "",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          "id": id.toString(),
          "status": status.toString(),
          "remark": remark
        },
      );

      if (response.statusCode == 200) {

        final result = json.decode(response.body);

        if (result['status'] == true) {

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message']))
          );

          fetchPendingNotifications();

        } else {

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to update visitor"))
          );

        }

      } else {

        print("Server Error: ${response.statusCode}");

      }

    } catch (e) {

      print("Error: $e");

    }

  }

  Color getCardColor(Map item) {

    int status = int.tryParse(item['status'].toString()) ?? 0;

    DateTime today = DateTime.now();
    DateTime checkIn =
        DateTime.tryParse(item['check_in_time'].toString()) ?? today;

    bool isToday =
        today.year == checkIn.year &&
            today.month == checkIn.month &&
            today.day == checkIn.day;

    if (status == 1) {
      return Colors.green.shade100; // Approved
    }
    else if (status == 2) {
      return Colors.red.shade100; // Rejected
    }
    else if (!isToday && status == 0) {
      return Colors.yellow.shade100; // Previous pending
    }

    return Colors.white; // Pending today
  }

  void showFullImage(BuildContext context, String image) {

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "- - -";

    try {
      final dateTime = DateTime.parse(dateTimeStr);

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;

      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');

      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;

      return '$day-$month-$year $hour12:$minute $period';
    } catch (e) {
      print("Time parsing error: $e");
      return "- - -";
    }
  }

  bool isPreviousPending(Map item) {

    int status = int.tryParse(item['status'].toString()) ?? 0;

    if (status != 0) return false;

    DateTime today = DateTime.now();

    DateTime checkIn =
        DateTime.tryParse(item['check_in_time'].toString()) ?? today;

    DateTime todayDate =
    DateTime(today.year, today.month, today.day);

    DateTime checkDate =
    DateTime(checkIn.year, checkIn.month, checkIn.day);

    return checkDate.isBefore(todayDate);
  }

  bool hasValue(dynamic val) {
    return val != null && val.toString().trim().isNotEmpty;
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

  String getStatusText(int status) {
    return "Lobby";
    // switch (status) {
    //   case 0:
    //     return "Captured";
    //   case 1:
    //     return "Lobby";
    //   case 2:
    //     return "Check-In";
    //   case 3:
    //     return "Check-Out";
    //   default:
    //     return "Captured";
    // }
  }

  Widget visitorCard(item) {

    int status = int.tryParse(item['status'].toString()) ?? 0;
    int id = int.tryParse(item['id'].toString()) ?? 0;

    String faceImage =
        "https://hrms.attendify.ai/guest_faces/${item['detected_face']}";
    String fullImage =
        "https://hrms.attendify.ai/guest_imgs/${item['image_path']}";

    TextEditingController remarkController = TextEditingController();
    bool showRejectBox = false;

    return StatefulBuilder(
      builder: (context, setStateCard) {

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),

          child: Column(
            children: [

              /// TOP ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// FACE IMAGE
                  GestureDetector(
                    onTap: () {
                      showFullImage(context, fullImage);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        faceImage,
                        width: 65,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// NAME + DATE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            Text(
                              item['first_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                                fontSize: 14,
                              ),
                            ),

                            Text(
                              _formatDateTime(
                                getVisitorTime(item, getStatusText(status)),
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 2),



                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [

                            /// CONTACT
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: 14,
                                  color: Colors.blueGrey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item['contact'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),

                            /// STATUS
                            buildStatusBadge(status),

                          ],
                        ),

                        if (hasValue(item['guestfrom']))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.business,
                                  size: 14,
                                  color: Colors.blueGrey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['guestfrom'],
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (hasValue(item['purpose_of_visit']))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  size: 14,
                                  color: Colors.blueGrey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['purpose_of_visit'],
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (status == 2 && hasValue(item['remarks']))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.message_outlined,
                                  size: 14,
                                  color: Colors.blueGrey.shade400,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item['remarks'],
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                ],
              ),

              const SizedBox(height: 4),

              /// ACTION BUTTONS
              if (status == 0 && !isPreviousPending(item))
                Row(
                  children: [

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () {
                          setStateCard(() {
                            showRejectBox = !showRejectBox;
                          });
                        },
                        child: const Text(
                          "Reject",
                          style: TextStyle(fontSize: 11,color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () {
                          updateVisitorStatus(id, 1, "Approved");
                        },
                        child: const Text(
                          "Accept",
                          style: TextStyle(fontSize: 11,color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )

              else if (isPreviousPending(item))
                Text(
                  "Request expired",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              /// REJECT BOX
              if (showRejectBox)
                Column(
                  children: [

                    const SizedBox(height: 6),

                    TextField(
                      controller: remarkController,
                      decoration: const InputDecoration(
                        hintText: "Remark",
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () {
                            updateVisitorStatus(
                                id,
                                2,
                                remarkController.text);
                          },
                          child: const Text("✔"),
                        ),

                        const SizedBox(width: 6),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey),
                          onPressed: () {
                            setStateCard(() {
                              showRejectBox = false;
                            });
                          },
                          child: const Text("✖"),
                        ),
                      ],
                    )
                  ],
                )
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text("Notifications"),
        backgroundColor: const Color(0xFF0557a2),
        foregroundColor: Colors.white,
      ),

      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchPendingNotifications,
        child: notifications.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 300),
            Center(child: Text("No Visitors at the Moment"))
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: notifications.length,
          itemBuilder: (context, index) {

            final item = notifications[index];

            return visitorCard(item);
          },
        ),
      ),
    );
  }
}
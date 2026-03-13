import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
// print(result);
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

        // print("API Response: $result");

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
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// FACE IMAGE
              GestureDetector(
                onTap: () {
                  showFullImage(context, fullImage);
                },
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(faceImage),
                ),
              ),

              const SizedBox(width: 10),

              /// DETAILS
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// NAME + TIME
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['first_name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),

                        Text(
                          item['check_in_time'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 3),


                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        /// CONTACT
                        if (item['contact'] != null)
                          Text(
                            item['contact'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),

                        /// STATUS BADGE
                        buildStatusBadge(status),
                      ],
                    ),

                    const SizedBox(height: 3),

                    /// COMPANY
                    if (item['guestfrom'] != null)
                      Text(
                        item['guestfrom'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),

                    /// REJECT REMARK
                    if (status == 2 && item['remarks'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          "Remark: ${item['remarks']}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    /// ACTION BUTTONS
                    if (status == 0)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                setStateCard(() {
                                  showRejectBox = !showRejectBox;
                                });
                              },
                              child: const Text(
                                "Reject",
                                style: TextStyle(fontSize: 12 ,color:Colors.white),
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () {
                                updateVisitorStatus(id, 1, "Approved");
                              },
                              child: const Text(
                                "Accept",
                                style: TextStyle(fontSize: 12 , color:Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    /// REJECT BOX
                    if (showRejectBox)
                      Column(
                        children: [

                          const SizedBox(height: 6),

                          TextField(
                            controller: remarkController,
                            decoration: const InputDecoration(
                              hintText: "Reject remark",
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 5),

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
        title: Text("Employee Notifications"),
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
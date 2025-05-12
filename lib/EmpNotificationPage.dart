import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EmpNotificationPage extends StatefulWidget {
  @override
  _EmpNotificationPageState createState() => _EmpNotificationPageState();
}

class _EmpNotificationPageState extends State<EmpNotificationPage> {
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPendingNotifications();
  }

  Future<void> fetchPendingNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? userId = prefs.getString('user_id');

    final url = Uri.parse('https://app.attendify.ai/template/public/index.php/Guest/guest_requests?user_id=$userId');

    try {
      final response = await http.get(url, headers: {
        'apiKey': apiKey ?? '',
        'companyDb': companyDb ?? '',
      });

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print("result : $result" );
        if (result['status'] == true) {
          setState(() {
            notifications = result['data'];
            isLoading = false;
          });
        }
      } else {
        print("Failed to load data");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Employee Notifications'),
         backgroundColor: const Color(0xFF0557a2),
        titleTextStyle: TextStyle(color: Colors.white ,fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white), // 👈 Make back icon white
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? Center(child: Text('No notifications available'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final item = notifications[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.20,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          // image: NetworkImage(
                          //     item['detected_face'] != null && item['detected_face'].isNotEmpty
                          //         ? 'https://vision.techkshetra.ai/faceRecognitionEngine/faces/${item['detected_face']}'
                          //         : 'https://via.placeholder.com/150'
                          // ),
                          image: NetworkImage(
                              item['image_path'] != null && item['image_path'].isNotEmpty
                                  ? 'https://vision.techkshetra.ai/faceRecognitionEngine/application/uploads/${item['image_path']}'
                                  : 'https://via.placeholder.com/150'
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item['name'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${item['check_in_time'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['description'] ?? 'No description',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

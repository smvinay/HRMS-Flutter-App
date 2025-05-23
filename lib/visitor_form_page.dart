import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'VisitorDrawerPage.dart';
import 'visitor_header.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart';

Map<int, TextEditingController> nameControllers = {};
Map<int, TextEditingController> phoneControllers = {};
Map<int, TextEditingController> emailControllers = {};
Map<int, TextEditingController> purposeControllers = {};
Map<int, TextEditingController> fromControllers = {};

class VisitorFormPage extends StatefulWidget {
  const VisitorFormPage({super.key});

  @override
  _VisitorFormPageState createState() => _VisitorFormPageState();
}

class _VisitorFormPageState extends State<VisitorFormPage> {
  late Future<List<Visitor>> _visitorsFuture;

  @override
  void initState() {
    super.initState();
    _loadVisitorData(); // Async call delegated
  }

  void _loadVisitorData() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('cid');
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');

    if (userId != null && apiKey != null && companyDb != null) {
      final visitors = await fetchVisitors(userId, apiKey, companyDb);
      setState(() {
        _visitorsFuture = Future.value(visitors);
        for (int i = 0; i < visitors.length; i++) {
          nameControllers[i] = TextEditingController(
              text:
                  '${visitors[i].firstName ?? ''} ${visitors[i].lastName ?? ''}'
                      .trim());
          phoneControllers[i] =
              TextEditingController(text: visitors[i].contact ?? '');
          emailControllers[i] =
              TextEditingController(text: visitors[i].email ?? '');
          purposeControllers[i] =
              TextEditingController(text: visitors[i].purposeOfVisit ?? '');
          fromControllers[i] =
              TextEditingController(text: visitors[i].guestFrom ?? '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: const VisitorHeader(), // <-- Use VisitorHeader here
      drawer: const VisitorDrawerPage(), // ✅ Drawer required for opening
      // appBar: AppBar(
      //   title: const Text('Visitor Forms'),
      // ),
      body: FutureBuilder<List<Visitor>>(
        future: _visitorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No visitors found.'));
          } else {
            final visitors = snapshot.data!;
            return PageView.builder(
              itemCount: visitors.length,
              itemBuilder: (context, index) {
                final visitor = visitors[index];
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  // 'https://vision.techkshetra.ai/faceRecognitionEngine/faces/${visitor.detected_face}',
                                  'https://vision.techkshetra.ai/faceRecognitionEngine/application/uploads/${visitor.imagePath}',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Visitor: ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'In: ${visitor.checkInTime ?? '- - -'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Name',
                              hintText: 'Enter Name',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0,
                                  horizontal: 12.0), // Reduced padding
                            ),
                            controller: nameControllers[index],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'Enter Phone Number',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0,
                                  horizontal: 12.0), // Reduced padding
                            ),
                            controller: phoneControllers[index],
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter Email',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0,
                                  horizontal: 12.0), // Reduced padding
                            ),
                            controller: emailControllers[index],
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Select Employee',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0,
                                  horizontal: 12.0), // Reduced padding
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Employee A',
                                  child: Text('Employee A')),
                              DropdownMenuItem(
                                  value: 'Employee B',
                                  child: Text('Employee B')),
                            ],
                            onChanged: (value) {
                              // Handle employee selection
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Purpose',
                              hintText: 'Enter Purpose',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0,
                                  horizontal: 12.0), // Reduced padding
                            ),
                            controller: purposeControllers[index],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'From',
                              hintText: 'Enter From',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 5.0,
                                  horizontal: 12.0), // Reduced padding
                            ),
                            controller: fromControllers[index],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity, // Makes the button full-width
                            child: ElevatedButton(
                              onPressed: () async {
                                await submitVisitorData(context, visitor, index);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0557a2),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          )

                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  void _showflashbar(String message, Color color) {
    Flushbar(
      message: message,
      duration: Duration(seconds: 2),
      backgroundColor: color,
      borderRadius: BorderRadius.circular(8),
      margin: EdgeInsets.all(12),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  Future<List<Visitor>> fetchVisitors(
      String userId, String apiKey, String companyDb) async {
    final url = Uri.parse(
        'https://app.attendify.ai/template/public/index.php/Guest/index?user_id=$userId');
    final response = await http.get(
      url,
      headers: {
        'apiKey': apiKey,
        'companyDb': companyDb,
      },
    );
// print("response $response");
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['data'];
      return data.map((json) => Visitor.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load visitors');
    }
  }

  Future<void> submitVisitorData(
      BuildContext context, Visitor visitor, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey');
    final companyDb = prefs.getString('companyDb');

    if (apiKey == null || companyDb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing API credentials.')),
      );
      return;
    }

    final url = Uri.parse(
        'https://app.attendify.ai/template/public/index.php/Guest/update_guest_mobile'); // Replace with actual

    final response = await http.post(
      url,
      headers: {
        'apiKey': apiKey,
        'companyDb': companyDb,
      },
      body: {
        'first_name': nameControllers[index]?.text ?? '',
        'contact': phoneControllers[index]?.text ?? '',
        'email': emailControllers[index]?.text ?? '',
        'purpose': purposeControllers[index]?.text ?? '',
        'guestfrom': fromControllers[index]?.text ?? '',
        'guestID': visitor.id,
        'guestfrom': visitor.guestFrom ?? '',
        'user_id': '17',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == true) {
        _showflashbar("Data submitted successfully", Colors.green.shade300);
        // Optional: refresh the visitor list
      } else {
        _showflashbar(
            data['message'] ?? 'Submission failed', Colors.red.shade300);
      }
    } else {
      _showflashbar('Submission failed', Colors.red.shade300);
    }
  }
}

class Visitor {
  final String id;
  final String guestId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? contact;
  final String? imagePath;
  final String? detected_face;
  final String? checkInTime;
  final String? purposeOfVisit;
  final String? guestFrom;

  Visitor({
    required this.id,
    required this.guestId,
    this.firstName,
    this.lastName,
    this.email,
    this.contact,
    this.imagePath,
    this.detected_face,
    this.checkInTime,
    this.purposeOfVisit,
    this.guestFrom,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      id: json['id'] ?? '',
      guestId: json['guestid'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      contact: json['contact'],
      imagePath: json['image_path'],
      detected_face: json['detected_face'],
      checkInTime: json['check_in_time'],
      purposeOfVisit: json['purpose_of_visit'],
      guestFrom: json['guestfrom'],
    );
  }
}

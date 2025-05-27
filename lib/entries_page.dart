import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Define Visitor model
class Visitor {
  final String id;
  final String guestId;
  final String firstName;
  final String lastName;
  final String email;
  final String contact;
  final String imagePath;
  final String detected_face;
  final String checkInTime;
  final String purposeOfVisit;
  final String guestFrom;

  Visitor({
    required this.id,
    required this.guestId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.contact,
    required this.imagePath,
    required this.detected_face,
    required this.checkInTime,
    required this.purposeOfVisit,
    required this.guestFrom,
  });

  factory Visitor.fromJson(Map<String, dynamic> json) {
    return Visitor(
      id: json['id'] ?? '',
      guestId: json['guestid'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      contact: json['contact'] ?? '',
      imagePath: json['image_path'] ?? '',
      detected_face: json['detected_face'] ?? '',
      checkInTime: json['check_in_time'] ?? '',
      purposeOfVisit: json['purpose_of_visit'] ?? '',
      guestFrom: json['guestfrom'] ?? '',
    );
  }
}

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  List<Visitor> visitors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVisitorData();
  }

  Future<void> _loadVisitorData() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('cid');
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');

    if (userId != null && apiKey != null && companyDb != null) {
      final fetchedVisitors =
      await fetchVisitors(userId, apiKey, companyDb);
      setState(() {
        visitors = fetchedVisitors;
        isLoading = false;
      });
    }
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

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['data'];
      return data.map((json) => Visitor.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load visitors');
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: visitors.length,
      itemBuilder: (context, index) {
        final visitor = visitors[index];
        final imageUrl =
            'https://vision.techkshetra.ai/faceRecognitionEngine/application/uploads/${visitor.imagePath}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, size: 60),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.checkInTime,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${visitor.firstName} ${visitor.lastName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'From: ${visitor.guestFrom}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

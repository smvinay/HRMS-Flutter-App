import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'EditEmployeePage.dart';
import 'hr_drawer.dart';
import 'hr_footer.dart';
import 'hr_header.dart';

class MyTeamPage extends StatefulWidget {
  const MyTeamPage({super.key});

  @override
  State<MyTeamPage> createState() => _MyTeamPageState();
}

class _MyTeamPageState extends State<MyTeamPage> {
  List employees = [];
  List filteredEmployees = [];
  String filterStatus = "active";
  TextEditingController searchController = TextEditingController();

  final ImagePicker picker = ImagePicker();
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? cid = prefs.getString('cid');
    String? level_id = prefs.getString('level_id');

    final response = await http.get(
      Uri.parse(
          "https://hrms.attendify.ai/index.php/mobileApi/getAllUsers?cid=$cid&level_id=$level_id"),
      headers: {
        'apiKey': apiKey ?? '',
        'companyDb': companyDb ?? '',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        employees = data["data"];
        filterEmployees(); // apply default filter
      });
    }
  }

  void filterEmployees() {
    String query = searchController.text.toLowerCase();

    setState(() {
      filteredEmployees = employees.where((emp) {
        final name = (emp["first_name"] ?? "").toLowerCase();
        final status = emp["trash"];
        bool searchMatch = name.contains(query);
        bool statusMatch = filterStatus == "all" ||
            (filterStatus == "active" && status == "0") ||
            (filterStatus == "inactive" && status == "1");

        return searchMatch && statusMatch;
      }).toList();
    });
  }

  int getReferenceCount(String? photos) {
    if (photos == null || photos.trim().isEmpty) return 0;

    return photos.split(',').where((e) => e.trim().isNotEmpty).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HrHeader(),
      drawer: HrDrawer(),
      bottomNavigationBar: const HrFooter(selectedIndex: 0),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    /// SEARCH BOX
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) {
                            filterEmployees();
                          },
                          decoration: InputDecoration(
                            hintText: "Search employee",
                            prefixIcon: const Icon(Icons.search, size: 20),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF0557a2),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    /// FILTER DROPDOWN
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: filterStatus,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.filter_list),
                        items: const [
                          DropdownMenuItem(
                            value: "active",
                            child: Text("Active"),
                          ),
                          DropdownMenuItem(
                            value: "inactive",
                            child: Text("Inactive"),
                          ),
                          DropdownMenuItem(
                            value: "all",
                            child: Text("All"),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            filterStatus = value!;
                          });
                          filterEmployees();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              /// EMPLOYEE LIST
              Expanded(
                child: ListView.builder(
                  itemCount: filteredEmployees.length,
                  itemBuilder: (context, index) {
                    final emp = filteredEmployees[index];

                    return _employeeCard(emp);
                  },
                ),
              )
            ],
          ),
          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _employeeCard(Map emp) {
    String name = "${emp["first_name"] ?? ""}".trim();
    String department = emp["departmentname"] ?? "";
    bool isActive = emp["trash"] == "0";

    String profile =
        "https://hrms.attendify.ai/photos/${emp["profile_thumbnail"] ?? ""}";

    final refCount = getReferenceCount(emp["reference_photos"]);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditEmployeePage(
                employeeCode: emp["employe_code"],
              ),
            ),
          );
        },

        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(profile),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                height: 12,
                width: 12,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),

        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(department),

        // Optional: remove or keep icon
        trailing: SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  _showImagePickerOptions(emp);
                },
                child: const Icon(Icons.add_a_photo, size: 25),
              ),

              if (refCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$refCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        enabled: true,
      ),
    );
  }

  void _showImagePickerOptions(Map emp) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Open Camera"),
                onTap: () {
                  Navigator.pop(context);
                  pickReferenceImage(ImageSource.camera, emp);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Upload from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickReferenceImage(ImageSource.gallery, emp);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> pickReferenceImage(ImageSource source, Map emp) async {
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    String path = image.path.toLowerCase();

    /// ✅ VALIDATE FILE TYPE
    if (!(path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png'))) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Only JPG and PNG images are allowed"),
        ),
      );
      return;
    }

    File file = File(image.path);

    final fileSize = await file.length();
    if (fileSize > 4 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Image must be less than 4MB"),
        ),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      await uploadReferenceImages(
        [file],
        emp["employe_code"],
        emp["faceApiFolderName"] ?? "",
        emp["reference_photos"] ?? "",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload failed")),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> uploadReferenceImages(
    List<File> images,
    String employeeCode,
    String faceApiFolderName,
    String oldReference,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? cid = prefs.getString('cid');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://hrms.attendify.ai/index.php/mobileApi/save_reference_photos',
      ),
    );

    request.headers.addAll({
      'apiKey': apiKey ?? '',
      'companyDb': companyDb ?? '',
    });

    request.fields['cid'] = cid ?? '';
    request.fields['employee_code'] = employeeCode;
    request.fields['faceApiFolderName'] = faceApiFolderName;
    request.fields['oldreference'] = oldReference;

    for (var img in images) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'reference_photos[]',
          img.path,
        ),
      );
    }

    var response = await request.send();
    var resBody = await response.stream.bytesToString();
    var jsonData = json.decode(resBody);

    if (jsonData['status'] == true) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reference image uploaded successfully"),
          duration: Duration(seconds: 2),
        ),
      );

      fetchEmployees();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(jsonData['message'] ?? "Upload failed")),
      );
    }
  }
}

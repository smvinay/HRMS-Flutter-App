import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:shimmer/shimmer.dart';

import '../widgets/toast.dart';

class EditEmployeePage extends StatefulWidget {
  final String employeeCode;

  const EditEmployeePage({super.key, required this.employeeCode});

  @override
  State<EditEmployeePage> createState() => _EditEmployeePageState();
}

class _EditEmployeePageState extends State<EditEmployeePage> {

  Map? employee;
  List referencePhotos = [];

  File? profileImage;
  List<File> refImages = [];

  final ImagePicker picker = ImagePicker();
  bool isUploadingRef = false;

  @override
  void initState() {
    super.initState();
    fetchEmployeeDetails();
  }

  /// FETCH EMPLOYEE DETAILS
  Future<void> fetchEmployeeDetails() async {

    final prefs = await SharedPreferences.getInstance();

    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? cid = prefs.getString('cid');
    String? levelId = prefs.getString('level_id');

    final response = await http.get(
      Uri.parse(
          "https://hrms.attendify.ai/index.php/mobileApi/employee_details?cid=$cid&level_id=$levelId&employeeCode=${widget.employeeCode}"),
      headers: {
        'apiKey': apiKey ?? '',
        'companyDb': companyDb ?? '',
      },
    );

    final jsonData = json.decode(response.body);

    if (jsonData["status"] == true) {
      setState(() {
        employee = jsonData["data"];
        referencePhotos = jsonData["reference_photos"];
      });
    }
  }

  Future<void> pickReferenceImage(ImageSource source) async {
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    String path = image.path.toLowerCase();

    ///  FILE TYPE VALIDATION
    if (!(path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png'))) {

      AppToast.show("Only JPG and PNG images are allowed", isError: true);

      return;
    }

    File file = File(image.path);

    final fileSize = await file.length();

    /// Convert to MB properly
    double fileSizeMB = fileSize / (1024 * 1024);

    if (fileSizeMB > 4) {

      AppToast.show( "Selected image size is ${fileSizeMB.toStringAsFixed(1)} MB. "
          "Please upload an image smaller than 4 MB.", isError: true);
      return;
    }

    setState(() {
      isUploadingRef = true;
    });

    try {
      if (employee != null) {
        await uploadReferenceImages(
          [file],
          employee!["employe_code"],
          employee!["faceApiFolderName"],
          referencePhotos.join(','),
        );
      }
    } catch (e) {
      AppToast.show("Upload failed", isError: true);

    } finally {
      setState(() {
        isUploadingRef = false;
      });
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

    /// MULTIPLE FILES
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

      AppToast.show("Reference image uploaded");

      fetchEmployeeDetails();

    } else {
      AppToast.show(jsonData['message'] ?? "Upload failed", isError: true);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text(jsonData['message'] ?? "Upload failed")),
      // );

    }
  }

  void _showImagePickerOptions() {
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
                  pickReferenceImage(ImageSource.camera);
                },
              ),

              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Upload from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickReferenceImage(ImageSource.gallery);
                },
              ),

            ],
          ),
        );
      },
    );
  }


  Future pickProfileImage(ImageSource source) async {

    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    File file = File(image.path);

    setState(() {
      profileImage = file;
    });

    uploadProfileImage(file);
  }

  Future<void> uploadProfileImage(File file) async {

    final prefs = await SharedPreferences.getInstance();

    String? apiKey = prefs.getString('apiKey');
    String? companyDb = prefs.getString('companyDb');
    String? cid = prefs.getString('cid');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'https://hrms.attendify.ai/index.php/mobileApi/update_employee_profile'),
    );

    request.headers.addAll({
      'apiKey': apiKey ?? '',
      'companyDb': companyDb ?? '',
    });

    request.fields['cid'] = cid ?? '';
    request.fields['employee_code'] = employee?["employe_code"] ?? '';
    request.fields['userId'] = employee?["user_id"] ?? '';
    request.fields['first_name'] = employee?["first_name"] ?? '';
    request.fields['last_name'] = employee?["last_name"] ?? '';

    request.files.add(
      await http.MultipartFile.fromPath(
        'user_profile',
        file.path,
      ),
    );

    var response = await request.send();

    var resBody = await response.stream.bytesToString();
    var jsonData = json.decode(resBody);

    if (jsonData["status"] == true) {

      _showflashbar("Profile updated successfully", Colors.green);

      fetchEmployeeDetails();

    } else {

      _showflashbar(jsonData["message"], Colors.red);

    }
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

  @override
  Widget build(BuildContext context) {

    if (employee == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String profile =
        "https://hrms.attendify.ai/photos/${employee!["profile_thumbnail"]}";

    return Scaffold(
      appBar: AppBar(
          title: const Text("Edit Employee"),
          backgroundColor: const Color(0xFF0557a2),
          foregroundColor: Colors.white,
      ),

      body: RefreshIndicator(
        onRefresh: fetchEmployeeDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

            /// PROFILE IMAGE
            Stack(
              children: [

                CircleAvatar(
                  radius: 60,
                  backgroundImage: profileImage != null
                      ? FileImage(profileImage!)
                      : NetworkImage(profile) as ImageProvider,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// NAME
            Text(
              employee!["first_name"],
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            /// REFERENCE IMAGES TITLE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                const Text(
                  "Reference Images",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),

                IconButton(
                  icon: const Icon(Icons.add_a_photo),
                  onPressed: () {
                    _showImagePickerOptions();
                  },
                )
              ],
            ),

            const SizedBox(height: 10),

            /// REFERENCE IMAGE GRID
            Stack(
              children: [

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: referencePhotos.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8),
                  itemBuilder: (context, index) {

                      String img =
                          "https://hrms.attendify.ai/reference_photos/${referencePhotos[index]}";

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                img,
                                fit: BoxFit.cover,
                                cacheWidth: 250,
                                cacheHeight: 300,
                                loadingBuilder: (context, child, progress) {

                                  if (progress == null) return child;

                                  return Shimmer.fromColors(
                                    baseColor: Colors.grey.shade300,
                                    highlightColor: Colors.grey.shade100,
                                    child: Container(color: Colors.white),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );

                  },
                ),

                if (isUploadingRef)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
      ),
    );
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SelfAttendanceCamera extends StatefulWidget {
    final String? attStatus; // Declare variable

 const SelfAttendanceCamera({
    super.key,
    this.attStatus, // Accept named parameter
  });

  @override
  SelfAttendanceCameraState createState() => SelfAttendanceCameraState();
}

class SelfAttendanceCameraState extends State<SelfAttendanceCamera> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  late String attendanceStatus;
  String userGeofetch = 'enable'; // From backend
  bool userInLocation = true; // Update based on actual geofence logic

  @override
  void initState() {
    super.initState();
    attendanceStatus = widget.attStatus ?? ""; // fallback if null
  }

  @override
  void didUpdateWidget(covariant SelfAttendanceCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attStatus != widget.attStatus) {
      setState(() {
        attendanceStatus = widget.attStatus ?? ""; // Update local when parent changes
      });
    }

   // print("attendanceStatus : $attendanceStatus");
  }


  double latitude = 0;
  double longitude = 0;

  Future<void> captureImage() async {
    DateTime now = DateTime.now();
    DateTime selectedDate = now; // Replace this with actual selected date

    if (now.isBefore(selectedDate)) {
      _showAlert('You cannot take self attendance for a future date.');
      return;
    } else if (now.isAfter(selectedDate)) {
      _showAlert('You cannot take self attendance for a past date.');
      return;
    }

    String? locationStatus;
    if (userGeofetch != "disable") {
      locationStatus = userInLocation ? '1' : '2';
      if (!userInLocation) {
        _showAlert('You are out of range');
        return;
      }
    }

    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.camera);
    if (pickedImage != null) {
      File imageFile = File(pickedImage.path);

      // Get current location
      Position position = await _determinePosition();
       latitude = position.latitude;
       longitude = position.longitude;

      // Add watermark
      File watermarkedImage = await _addWatermark(imageFile, latitude, longitude);

      // Upload
      await _uploadData(
        watermarkedImage,
        latitude,
        longitude,
        locationStatus ?? '1',
      );
    }
  }

//   Future<File> _addWatermark(File imageFile, double lat, double long) async {
//     final bytes = await imageFile.readAsBytes();
//     img.Image original = img.decodeImage(bytes)!;

//     final now = DateTime.now();
//     final date = DateFormat('dd/MM/yyyy').format(now);
//     final time = DateFormat('HH:mm:ss').format(now);
//    final text1 = 'Date: $date, Time: $time';
//     final text2 = 'Lat: ${lat.toStringAsFixed(6)}, Long: ${long.toStringAsFixed(6)}';

// img.fillRect(
//   original,
//   x1: 20,
//   y1: original.height - 200,
//   x2: 20 + (text1.length * 2),
//   y2: original.height - 130,
//   color: img.ColorRgb8(200, 200, 200), // Gray background
// );
// // Draw black text on top of the rectangle
// img.drawString(
//   original,
//   text1,
//   font: img.arial14,
//   x: 20,
//   y: original.height - 200,
//   color: img.ColorRgb8(0, 0, 0), // Black text
// );

// img.fillRect(
//   original,
//   x1: 20,
//   y1: original.height - 200,
//   x2: 20 + (text2.length * 2),
//   y2: original.height - 80,
//   color: img.ColorRgb8(200, 200, 200),
// );

// img.drawString(
//   original,
//   text2,
//   font: img.arial14,
//   x: 20,
//   y: original.height - 200,
//   color: img.ColorRgb8(0, 0, 0),
// );


//     final tempDir = await getTemporaryDirectory();
//     final watermarkedPath = '${tempDir.path}/watermarked_image.jpg';
//     File watermarkedImage = File(watermarkedPath)
//       ..writeAsBytesSync(img.encodeJpg(original, quality: 90));
//     return watermarkedImage;
//   }


Future<File> _addWatermark(File imageFile, double lat, double long) async {
  final bytes = await imageFile.readAsBytes();
  img.Image original = img.decodeImage(bytes)!;

  final now = DateTime.now();
  final date = DateFormat('dd/MM/yyyy').format(now);
  final time = DateFormat('HH:mm:ss').format(now);
  final text1 = 'Date: $date, Time: $time';
  final text2 = 'Lat: ${lat.toStringAsFixed(6)}, Long: ${long.toStringAsFixed(6)}';

  // Choose a font size: arial_24 or arial_48
  final font = img.arial14;

  final padding = 20;
  final lineHeight = font.lineHeight;

  // Background for text1
  img.fillRect(
    original,
    x1: padding,
    y1: original.height - (2 * lineHeight) - 30,
    x2: original.width - padding,
    y2: original.height - lineHeight - 20,
    color: img.ColorRgb8(200, 200, 200),
  );
  img.drawString(
    original,
    text1,
    font: font,
    x: padding + 5,
    y: original.height - (2 * lineHeight) - 25,
    color: img.ColorRgb8(0, 0, 0),
  );

  // Background for text2
  img.fillRect(
    original,
    x1: padding,
    y1: original.height - lineHeight - 10,
    x2: original.width - padding,
    y2: original.height - 5,
    color: img.ColorRgb8(200, 200, 200),
  );
  img.drawString(
    original,
    text2,
    font: font,
    x: padding + 5,
    y: original.height - lineHeight - 5,
    color: img.ColorRgb8(0, 0, 0),
  );

  // Save updated image
  final tempDir = await getTemporaryDirectory();
  final watermarkedPath = '${tempDir.path}/watermarked_image.jpg';
  File watermarkedImage = File(watermarkedPath)
    ..writeAsBytesSync(img.encodeJpg(original, quality: 90));

  return watermarkedImage;
}



  Future<void> _uploadData(
    File imageFile,
    double latitude,
    double longitude,
    String captureRange,
  ) async {


      _showLoading(); // show loading indicator

    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

     final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? "";
    final companyDb = prefs.getString('companyDb') ?? "";
    final collectionId = prefs.getString('unique_code') ?? "";
    final empCode = prefs.getString('employe_code') ?? "";

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://vision.techkshetra.ai/faceRecognitionEngine/index.php/Auth/authenticate_recapture_self'),
    );

    request.headers.addAll({
      'apiKey': apiKey,
      'companyDb': companyDb,
    });

    request.fields['collectionId'] = collectionId;
    request.fields['timestamp'] = timestamp;
    request.fields['attendance_status'] = attendanceStatus;
    request.fields['captureLatitude'] = latitude.toString();
    request.fields['captureLongtitude'] = longitude.toString();
    request.fields['employe_code'] = empCode;
    request.fields['capture_range'] = captureRange;

    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      debugPrint("API Response: $responseBody");

      if (response.statusCode == 200 && responseBody.isNotEmpty ) {

        
      final Map<String, dynamic> result = jsonDecode(responseBody);

      if (result['type'] == 'attendance' && result['status'] == 'success') {
        _showToast("Attendance marked successfully");
      } else if (result['type'] == 'errorface') {
        _showToast("Face mismatch. Please try again.");
      } else if (result['type'] == 'nullface') {
        _showToast("No face detected. Please try again.");
      } else {
        _showToast("Unexpected response from server.");
      }
    } else {
      // _showToast("Upload failed. Status Code: ${response.statusCode}");
      _showToast("Somthing went wrong, please try again");

    }
  } catch (e) {
    _showToast("Upload failed: $e");
  } finally {
    _hideLoading(); // always hide loading, even on error
  }
  }

  Future<Position> _determinePosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    return await Geolocator.getCurrentPosition();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Notice"),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        icon: Icon(Icons.camera_alt, size: 30, color: Colors.blue),
        onPressed: captureImage,
      ),
    );
  }


  void _showLoading() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
}

void _hideLoading() {
  Navigator.of(context, rootNavigator: true).pop();
}


}

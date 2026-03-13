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
import 'package:another_flushbar/flushbar.dart';


class SelfAttendanceCamera extends StatefulWidget {
  final String? attStatus;
  final VoidCallback? onSuccess;   // ✅ callback

  const SelfAttendanceCamera({
    super.key,
    this.attStatus,
    this.onSuccess,
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
  bool _isLoaderShowing = false;
  bool _isUploading = false;

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
    DateTime selectedDate = now;

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

    final XFile? pickedImage = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      maxWidth: 1920,
      maxHeight: 1080,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedImage != null) {
      File imageFile = File(pickedImage.path);

      Position position = await _determinePosition();
      latitude = position.latitude;
      longitude = position.longitude;


      File watermarkedImage = await _addWatermark(imageFile, latitude, longitude);
      _showLoading();
      await _uploadData(
        watermarkedImage,
        latitude,
        longitude,
        locationStatus ?? '1',
      );
    }
  }

Future<File> _addWatermark(File imageFile, double lat, double long) async {
  final bytes = await imageFile.readAsBytes();
  img.Image original = img.decodeImage(bytes)!;

  final now = DateTime.now();
  final date = DateFormat('dd/MM/yyyy').format(now);
  final time = DateFormat('HH:mm:ss').format(now);
  final text1 = 'Date: $date, Time: $time';
  final text2 = 'Lat: ${lat.toStringAsFixed(6)}, Long: ${long.toStringAsFixed(6)}';

  final font = img.arial48; // Larger font
  final padding = 20;
  final lineHeight = font.lineHeight.toInt();

  // 20% of image height
  final watermarkHeight = (original.height * 0.05).toInt();
  final watermarkTop = original.height - watermarkHeight;

  // Draw background over bottom 20% of image
  img.fillRect(
    original,
    x1: 0,
    y1: watermarkTop,
    x2: original.width,
    y2: original.height,
    color: img.ColorRgb8(226, 226, 226),
  );

  // Draw text1
  img.drawString(
    original,
    text1,
    font: font,
    x: padding,
    y: watermarkTop + padding,
    color: img.ColorRgb8(0, 0, 0),
  );

  // Draw text2 below text1
  img.drawString(
    original,
    text2,
    font: font,
    x: padding,
    y: watermarkTop + padding + lineHeight + 10,
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



    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? "";
    final companyDb = prefs.getString('companyDb') ?? "";
    final collectionId = prefs.getString('unique_code') ?? "";
    final empCode = prefs.getString('employe_code') ?? "";

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'https://vision.techkshetra.ai/faceRecognitionEngine/index.php/Auth/authenticate_recapture_self'),
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

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    try {
      var response = await request.send();

      final responseBody = await response.stream.bytesToString();
      debugPrint("API RESPONSE: $responseBody");

      if (response.statusCode == 200 && responseBody.isNotEmpty) {

        dynamic result = jsonDecode(responseBody);

        /// If API returns string JSON
        if (result is String) {
          result = jsonDecode(result);
        }

        final type = result['type'];
        final status = result['status'];

        if (type == "attendance" && status == "success") {

          WidgetsBinding.instance.addPostFrameCallback((_) {

            if (mounted) {
              _hideLoading();

              _showflashbar(
                "Attendance marked successfully",
                Colors.green.shade300,
              );

              widget.onSuccess?.call();
            }

          });

        } else if (type == "nullface") {

          _hideLoading();

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showflashbar(
                "Employee face not recognized, please retry again.",
                Colors.red.shade300,
              );
            }
          });

        } else if (type == "errorface") {

          _hideLoading();

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showflashbar(
                "Employee face not matched, please retry again.",
                Colors.red.shade300,
              );
            }
          });

        } else {

          _hideLoading();

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _showflashbar(
                "Face not matching, please retry again.",
                Colors.red.shade300,
              );
            }
          });
        }

        /// Refresh Home API (same as JS refreshHome())
        // _loadUserData();

      } else {
        _hideLoading();
        _showflashbar(
          "Upload failed. Status: ${response.statusCode}",
          Colors.red.shade300,
        );
      }

    } catch (e) {

      debugPrint("UPLOAD ERROR: $e");
      _hideLoading();
      _showflashbar(
        "Upload failed. Please try again.",
        Colors.red.shade300,
      );

    } finally {

      /// ALWAYS HIDE LOADER
      _hideLoading();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Notice"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            )
          ],
        ),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        icon: Icon(Icons.camera_alt, size: 45, color: Colors.white),
        onPressed: captureImage,
      ),
    );
  }

  void _showLoading() {
    if (_isLoaderShowing) return;

    _isLoaderShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _hideLoading() {
    if (!_isLoaderShowing) return;

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    _isLoaderShowing = false;
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



}

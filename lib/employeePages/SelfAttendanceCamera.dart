import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:geocoding/geocoding.dart';
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

    if (_isUploading) return;
    _isUploading = true;

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
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedImage != null) {
      _showLoading(); // ✅ SHOW IMMEDIATELY (FIRST LINE)

      File imageFile = File(pickedImage.path);

      try {
        Position position = await _determinePosition();
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        latitude = 0;
        longitude = 0;
      }

      String address = "Fetching location...";

      try {
        address = await getAddressFromGeoapify(latitude, longitude);
      } catch (e) {
        address = "Location unavailable";
      }

      File watermarkedImage = await _addWatermark(
        imageFile,
        latitude,
        longitude,
        address,
      );

      await _uploadData(
        watermarkedImage,
        latitude,
        longitude,
        locationStatus ?? '1',
      );
    }
  }

  Future<File> _addWatermark(File imageFile, double lat, double long ,String address,) async {
    final bytes = await imageFile.readAsBytes();
    img.Image original = img.decodeImage(bytes)!;

    // =========================
    // ✅ STEP 1: CROP FIRST (9:11)
    // =========================
    double targetRatio = 9 / 11;

    int newWidth = original.width;
    int newHeight = (newWidth / targetRatio).toInt();

    if (newHeight > original.height) {
      newHeight = original.height;
      newWidth = (newHeight * targetRatio).toInt();
    }

    int xOffset = (original.width - newWidth) ~/ 2;
    int yOffset = (original.height - newHeight) ~/ 2;

    original = img.copyCrop(
      original,
      x: xOffset,
      y: yOffset,
      width: newWidth,
      height: newHeight,
    );

    final now = DateTime.now();
    final date = DateFormat('dd/MM/yyyy').format(now);
    final time = DateFormat('HH:mm:ss').format(now);


// ✅ Approximate width (since measureText doesn't exist)
    final font = img.arial48;
    final padding = 20;
    final lineSpacing = 10;

    List<String> parts = address.split(',');

// Clean trim
    parts = parts.map((e) => e.trim()).toList();

    String line1 = '';
    String line2 = '';

    if (parts.length >= 3) {
      // 🔥 Last 3 parts → line2
      line2 = parts.sublist(parts.length - 3).join(', ');

      // 🔥 Remaining → line1
      line1 = parts.sublist(0, parts.length - 3).join(', ');
    } else {
      // fallback
      line1 = address;
    }

// Text
    final text1 = 'Date $date   Time $time';
    final text2 = 'Lat ${lat.toStringAsFixed(5)}  Lon ${long.toStringAsFixed(5)}';
    final text3 = line1;
    final text4 = line2;

// ✅ Smart width (based on image, not text)
    int boxWidth = (original.width * 0.95).toInt(); // almost full width
    int boxHeight =
        (font.lineHeight * 4) + (lineSpacing * 3) + padding * 2;

// Position (bottom-left)
    int x = 20;
    int y = original.height - boxHeight - 20;

// Background (only needed area)
    img.fillRect(
      original,
      x1: x,
      y1: y,
      x2: x + boxWidth,
      y2: y + boxHeight,
      color: img.ColorRgba8(0, 0, 0, 160),
    );

// Draw text
    img.drawString(
      original,
      text1,
      font: font,
      x: x + padding,
      y: y + padding,
      color: img.ColorRgb8(255, 255, 255),
    );

    img.drawString(
      original,
      text2,
      font: font,
      x: x + padding,
      y: y + padding + font.lineHeight + lineSpacing,
      color: img.ColorRgb8(255, 255, 255),
    );

    img.drawString(
      original,
      text3,
      font: font,
      x: x + padding,
      y: y + padding + (font.lineHeight * 2) + (lineSpacing * 2),
      color: img.ColorRgb8(255, 255, 255),
    );

    img.drawString(
      original,
      text4,
      font: font,
      x: x + padding,
      y: y + padding + (font.lineHeight * 3) + (lineSpacing * 3),
      color: img.ColorRgb8(255, 255, 255),
    );
    // =========================
    // ✅ STEP 3: SAVE
    // =========================
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.jpg';

    File finalImage = File(path)
      ..writeAsBytesSync(img.encodeJpg(original, quality: 90));

    return finalImage;
  }


  Future<String> getAddressFromGeoapify(double lat, double lng) async {
    const String apiKey = "d48f66b9edc44c9c8ceb585d304c7360";

    final url =
        "https://api.geoapify.com/v1/geocode/reverse?lat=$lat&lon=$lng&apiKey=$apiKey";

    try {
      final response =
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['features'] != null &&
            data['features'].isNotEmpty &&
            data['features'][0]['properties'] != null) {
          final p = data['features'][0]['properties'];

          String district = p['state_district'] ?? '';
          String addressLine1 = p['address_line1'] ?? '';
          String addressLine2 = p['address_line2'] ?? '';

          String address = "";

          if (addressLine1.isNotEmpty && addressLine2.isNotEmpty) {
            address = "$addressLine1, $district, $addressLine2";
          } else {
            address = p['formatted'] ?? "Location not available";
          }

          // 🔥 Replace highway naming (same as your PHP)
          if (address.contains('NH')) {
            address = address.replaceAll('NH', 'National Highway ');
          }

          return address;
        }
      }
    } catch (e) {
      debugPrint("Geoapify Error: $e");
    }

    return "Location not available";
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
      _isUploading = false;
      if (_isLoaderShowing) _hideLoading();

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
        onPressed: () {
          _showAttendanceConfirmDialog();
        },
      ),
    );
  }

  void _showAttendanceConfirmDialog() {
    final isCheckIn = attendanceStatus == "checkin";

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// ICON
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                  isCheckIn ? Colors.green.shade100 : Colors.red.shade100,
                  child: Icon(
                    isCheckIn ? Icons.login : Icons.logout,
                    color: isCheckIn ? Colors.green : Colors.red,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 12),

                /// TITLE
                Text(
                  isCheckIn ? "Confirm Check-In" : "Confirm Check-Out",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                /// MESSAGE
                Text(
                  isCheckIn
                      ? "You are about to mark your Check-In."
                      : "You are about to mark your Check-Out.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 20),

                /// BUTTONS
                Row(
                  children: [
                    /// CANCEL
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),

                    const SizedBox(width: 10),

                    /// CONFIRM
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          isCheckIn ? Colors.green : Colors.red,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          captureImage(); //  call camera after confirm
                        },
                        child: const Text("Confirm",
                          style: TextStyle(
                            color: Colors.white
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLoading() {
    if (_isLoaderShowing) return;

    _isLoaderShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        children: [
          /// 🔥 BACKGROUND BLUR
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.2), // dim effect
            ),
          ),

          /// 🔥 CENTER GLASS CARD
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),

                /// 🔥 GLASS EFFECT
                color: Colors.white.withOpacity(0.08),

              border: Border.all(
              color: Colors.greenAccent.withOpacity(0.3),
              ),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// 🔥 ANIMATED ICON
                  TweenAnimationBuilder(
                    tween: Tween(begin: 0.8, end: 1.2),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.face,
                      size: 55,
                      color: Colors.greenAccent,
                    ),
                  ),

                  SizedBox(height: 15),

                  /// 🔥 TEXT
                  _typingText(),

                  SizedBox(height: 15),

                  /// 🔥 PROGRESS BAR
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor:
                      AlwaysStoppedAnimation(Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingText() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 20),
      duration: Duration(seconds: 2),
      builder: (context, value, child) {
        String text = "Detecting face...";
        return Text(
          text.substring(0, value.clamp(0, text.length)),
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        );
      },
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

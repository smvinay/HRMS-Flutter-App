import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
import 'package:http_parser/http_parser.dart';


class SelfAttendanceCamera extends StatefulWidget {
  final String? attStatus;
  final VoidCallback? onSuccess;   //  callback

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
  String ackKey = "selfie_acknowledged";
  String policyMessage = "";
  String policyTitle = "";
  int policyId = 0;
  String ackStatusKey = "selfie_ack_status";
  String ackVersionKey = "selfie_ack_version";

  @override
  void initState() {
    super.initState();
    attendanceStatus = widget.attStatus ?? ""; // fallback if null
  }

  Future<void> loadPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? "";
    final companyDb = prefs.getString('companyDb') ?? "";

    final res = await http.get(
      Uri.parse("https://hrms.attendify.ai/index.php/MobileApi/get_selfie_policy"),
      headers: {
        "apiKey": apiKey,
        "companyDb": companyDb,
      },
    );

    final data = jsonDecode(res.body);

    print('data $data');

    if (data['status'] == true && data['data'] != null ) {
      setState(() {
        policyTitle = data['data']['title'] ?? "";
        policyMessage = data['data']['message'] ?? "";
        policyId = int.parse(data['data']['id'].toString());
      });
    }
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
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedImage != null) {
      _showLoading(); //  SHOW IMMEDIATELY (FIRST LINE)

      File imageFile = File(pickedImage.path);

      try {
        Position position = await getStoredOrFetchLocation();
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        latitude = 0;
        longitude = 0;
      }

      String address;

      try {
        address = await getStoredAddress();
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

  Future<File> convertToJpg(File file) async {
    final targetPath = file.path.replaceAll(RegExp(r'\.\w+$'), '.jpg');

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 95,
    );

    return File(result!.path);
  }

  Future<File> _addWatermark(File imageFile, double lat, double long ,String address,) async {
    final bytes = await imageFile.readAsBytes();
    img.Image original = img.decodeImage(bytes)!;

    double targetRatio = 9 / 11;

    int newWidth = original.width;
    int newHeight = original.height;

    // if (newHeight > original.height) {
    //   newHeight = original.height;
    //   newWidth = (newHeight * targetRatio).toInt();
    // }

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


//  Approximate width (since measureText doesn't exist)
    final font = img.arial48;
    final padding = 20;
    final lineSpacing = 10;

    List<String> parts = address.split(',');

// Clean trim
    parts = parts.map((e) => e.trim()).toList();

    String line1 = '';
    String line2 = '';

    if (parts.length >= 4) {
      //  Last 3 parts → line2
      line2 = parts.sublist(parts.length - 4).join(', ');

      //  Remaining → line1
      line1 = parts.sublist(0, parts.length - 4).join(', ');
    } else {
      // fallback
      line1 = address;
    }

// Text
    final text1 = '$date  $time';
    final text2 = 'Lat ${lat.toStringAsFixed(5)}  Lon ${long.toStringAsFixed(5)}';
    final text3 = line1;
    final text4 = line2;

//  Smart width (based on image, not text)
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
    //  STEP 3: SAVE
    // =========================
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.jpg';

    File finalImage = File(path)
      ..writeAsBytesSync(img.encodeJpg(original, quality: 95));

    return finalImage;
  }


  Future<String> getAddressFromGeoapify(double lat, double lng) async {
    const String apiKey = "d48f66b9edc44c9c8ceb585d304c7360";

    final url =
        "https://api.geoapify.com/v1/geocode/reverse?lat=$lat&lon=$lng&apiKey=$apiKey";

    try {
      final response =
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

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

          //  Replace highway naming (same as your PHP)
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
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    try {
      var response = await request.send();

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 && responseBody.isNotEmpty) {

        dynamic result;

        try {
          result = jsonDecode(responseBody);
        } catch (e) {
          debugPrint("JSON PARSE ERROR: $e");
          result = {};
        }

// handle [] case
        if (result is List) {
          debugPrint("API returned LIST instead of MAP");
          result = {};
        }

// handle string JSON
        if (result is String) {
          try {
            result = jsonDecode(result);
          } catch (_) {
            result = {};
          }
        }

// final safety
        if (result is! Map) {
          result = {};
        }

        /// If API returns string JSON
        // if (result is String) {
        //   result = jsonDecode(result);
        // }

        final type = result['type']?.toString() ?? '';
        final status = result['status']?.toString() ?? '';

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

  Future<String> getStoredAddress() async {
    final prefs = await SharedPreferences.getInstance();

    String? address = prefs.getString('address');

    //  If address missing OR placeholder
    if (address == null || address.trim().isEmpty || address == "...") {

      //  Try fetching fresh immediately
      double? lat = prefs.getDouble('latitude');
      double? lng = prefs.getDouble('longitude');

      if (lat != null && lng != null) {
        try {
          String newAddress = await getAddressFromGeoapify(lat, lng);

          await prefs.setString('address', newAddress);

          return newAddress;
        } catch (_) {}
      }

      return "Location not available";
    }

    return address;
  }

  Future<Position> getStoredOrFetchLocation() async {
    final prefs = await SharedPreferences.getInstance();

    double? lat = prefs.getDouble('latitude');
    double? lng = prefs.getDouble('longitude');
    int? lastTime = prefs.getInt('location_time');

    bool shouldRefresh = true;

    if (lastTime != null) {
      final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
      shouldRefresh = diff > (10 * 60 * 1000); // 10 minutes
    }

    //  Background refresh (only if needed)
    if (shouldRefresh) {
      await updateLocationAndAddressInBackground(); // don't await
    }

    //  Return cached instantly
    if (lat != null && lng != null) {
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    //  First time → fetch + update
    Position position = await _determinePosition();

    await updateLocationAndAddressInBackground(); // async store

    return position;
  }

  Future<void> updateLocationAndAddressInBackground() async {
    try {
      Position position = await _determinePosition();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble('latitude', position.latitude);
      await prefs.setDouble('longitude', position.longitude);

      //  IMPORTANT: store temporary value first
      await prefs.setString('address', "...");

      String address = await getAddressFromGeoapify(
        position.latitude,
        position.longitude,
      );

      await prefs.setString('address', address);

      await prefs.setInt(
        'location_time',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // silent
    }
  }

  Future<Position> _determinePosition() async {
    LocationPermission permission;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
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

        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();

          await loadPolicy();

          String savedVersion = prefs.getString(ackVersionKey) ?? "";
          bool accepted = prefs.getBool(ackStatusKey) ?? false;

          ///  compare version
          if (savedVersion == policyId.toString() && accepted) {
            _showAttendanceConfirmDialog();
          } else {
            _showAcknowledgementDialog();
          }
        },
      ),
    );
  }

  void _showAcknowledgementDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String companyName = prefs.getString('comp_name') ?? "Company";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ackDialogUI(companyName);
      },
    );
  }

  bool isChecked = false;

  Widget _ackDialogUI(String companyName) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.08),
                  ),
                  child: Icon(
                    Icons.verified_user,
                    size: 28,
                    color: Colors.blue.shade600,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  policyTitle.isNotEmpty
                      ? policyTitle
                      : "Selfie Attendance Policy",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                if (companyName.isNotEmpty)
                  Text(
                    companyName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),

                const SizedBox(height: 14),

                Text(
                  policyMessage.isNotEmpty
                      ? policyMessage
                      : "This app captures your selfie for attendance marking. The image will be securely stored and used only for verification purposes.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                ),

                const SizedBox(height: 16),

                /// CHECKBOX
                Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          isChecked = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        "I agree to the above acknowledgement and consent to selfie-based attendance.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ).copyWith(
                          overlayColor:
                          MaterialStateProperty.all(Colors.transparent),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _handleAck(false);
                        },
                        child: const Text("Reject"),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                          isChecked ? Colors.blue : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ).copyWith(
                          overlayColor:
                          MaterialStateProperty.all(Colors.transparent),
                        ),
                        onPressed: isChecked
                            ? () async {
                          Navigator.pop(context);
                          await _handleAck(true);
                        }
                            : null,
                        child: const Text(
                          "Accept",
                          style: TextStyle(color: Colors.white),
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

  Future<void> _handleAck(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();

    //  store version + status
    await prefs.setBool(ackStatusKey, accepted);
    await prefs.setString(ackVersionKey, policyId.toString());

    //  send to backend
    await _sendAckToServer(accepted);

    if (accepted) {
      _showAttendanceConfirmDialog();
    }
  }

  Future<void> _sendAckToServer(bool accepted) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final apiKey = prefs.getString('apiKey') ?? "";
      final companyDb = prefs.getString('companyDb') ?? "";
      final userId = prefs.getString('user_id') ?? "";
      var response = await http.post(
        Uri.parse("https://hrms.attendify.ai/index.php/MobileApi/update_selfie_acknowledged"),
        headers: {
          "apiKey": apiKey,
          "companyDb": companyDb,
        },
          body: {
            "user_id": userId,
            "status": accepted ? "1" : "0",
            "policy_id": policyId.toString(),
          },
      );
      if (response.statusCode == 200) {
        debugPrint("Ack updated");
      } else {
        debugPrint("Ack failed");
      }
    } catch (e) {
      debugPrint("Ack error: $e");
    }
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
          ///  BACKGROUND BLUR
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.2), // dim effect
            ),
          ),

          ///  CENTER GLASS CARD
          Center(
            child: Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),

                ///  GLASS EFFECT
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
                  ///  ANIMATED ICON
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

                  ///  TEXT
                  _typingText(),

                  SizedBox(height: 15),

                  ///  PROGRESS BAR
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
      messageText: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: color.withOpacity(0.9),
      borderRadius: BorderRadius.circular(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      flushbarPosition: FlushbarPosition.TOP,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOut,
      reverseAnimationCurve: Curves.easeIn,
    ).show(context);
  }



}

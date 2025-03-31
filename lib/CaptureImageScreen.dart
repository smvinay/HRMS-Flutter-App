import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class CaptureImageWidget extends StatefulWidget {
  @override
  _CaptureImageWidgetState createState() => _CaptureImageWidgetState();
}

class _CaptureImageWidgetState extends State<CaptureImageWidget> {
  String _username = "John Doe";  // Replace with actual username
  String _department = "IT Department"; // Replace with actual department
  File? _image;

  Future<void> _captureImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.camera);

    if (pickedImage != null) {
      setState(() {
        _image = File(pickedImage.path);
      });

      // Get Location
      Position position = await _determinePosition();
      double latitude = position.latitude;
      double longitude = position.longitude;

      // Upload Image & Location
      _uploadData(_image!, latitude, longitude);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error("Location services are disabled.");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error("Location permissions are permanently denied.");
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _uploadData(File image, double latitude, double longitude) async {
    var request = http.MultipartRequest('POST', Uri.parse('https://your-api-url.com/upload'));
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    var response = await request.send();

    if (response.statusCode == 200) {
      print('Upload Successful');
    } else {
      print('Upload Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hi, $_username",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _department,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.camera_alt, size: 30, color: Colors.blue),
          onPressed: _captureImage,
        ),
      ],
    );
  }
}

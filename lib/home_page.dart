import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'custom_drawer.dart';
import 'header.dart';
import 'timeSheetCal.dart';
import 'leaveCal.dart';
import 'attendanceCal.dart';
import 'package:intl/intl.dart';

import 'SelfAttendanceCamera.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();

}


class _HomePageState extends State<HomePage> {

    final GlobalKey<SelfAttendanceCameraState> _cameraKey = GlobalKey();
    

  String attendanceStatus = "checkin";
  String _username = "";
  String _department = "";
  String _userId = "";
  File? _image;
  final ImagePicker _picker = ImagePicker();

  String _presentCount = "0";
  String _absentCount = "0";
  String _holidayCount = "0";
  String _checkInTime = "";
  String _checkOutTime = "";
  String _latestCheckInTime = '';
  String _currentDay = '';

  @override
  void initState() {
      _currentDay = DateFormat('yyyy-MM-dd').format(DateTime.now());

    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String selectedYear = DateTime.now().year.toString();
    String selectedMonth = DateTime.now().month.toString();

    setState(() {
      _userId = prefs.getString('user_id') ?? "";
      _username =
          "${prefs.getString('username') ?? ''} ${prefs.getString('last_name') ?? ''}"
              .trim();
      _department = prefs.getString('department_name') ?? "Department";
    });

    // Call API to fetch attendance data
    _loadAttendanceData(_userId, selectedYear, selectedMonth);
  }

  Future<void> _loadAttendanceData(
      String userId, String year, String month) async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('apiKey') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";
    String cid = prefs.getString('cid') ?? "";
    String deptID = prefs.getString('department') ?? "";
    String url =
        "https://app.attendify.ai/template/public/index.php/MobileApi/home?company_db=$companyDb&userid=$userId&cid=$cid&deptID=$deptID";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        final data = res['data'];

        // print("data: ${data}");

        setState(() {
          _presentCount = data['presentCount']?.toString() ?? "0";
          _absentCount = data['absentCount']?.toString() ?? "0";
          _holidayCount = data['holidayCount']?.toString() ?? "0";

          _currentDay = data['currentday']?.toString() ?? _currentDay;

          // _checkInTime = _formatTime(data['checkinTime']?.toString());
          // _checkOutTime = _formatTime(data['checkoutTime']?.toString());
          // _latestCheckInTime = _formatTime(data['latestCheckin']?.toString());

           _checkInTime = data['checkinTime']  ?? '';
          _checkOutTime = data['checkoutTime'] ?? '';
          _latestCheckInTime = data['latestCheckin'] ?? '';
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching attendance data: $e");
    }
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return "- - -";

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;

      return '$hour12:$minute $period';
    } catch (e) {
      print("Time parsing error: $e");
      return "- - -";
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

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _uploadData(
      File image, double latitude, double longitude) async {
    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('https://your-api-url.com/upload'));
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      var response = await request.send();

      if (response.statusCode == 200) {
        print('Upload Successful');
      } else {
        print('Upload Failed');
      }
    } catch (e) {
      print("Error uploading data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {

 
              final statusCard = _buildLatestStatusCard();
 

    return Scaffold(
      drawer: CustomDrawer(),
      appBar: const Header(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hi, $_username",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_department,
                        style:
                            const TextStyle(fontSize: 15, color: Colors.grey)),
                  ],
                ),
                // ✅ Call the SelfAttendanceCamera with key
                  SelfAttendanceCamera(
                    key: _cameraKey,
                    attStatus: attendanceStatus, // Pass using named parameter
                  ),
                // IconButton(
                //   icon: Icon(Icons.camera_alt, size: 30, color: Colors.blue),
                //   onPressed: () {
                //     _cameraKey.currentState?.captureImage(); // ✅ Call from state
                //   },
                // ),
              ],
            ),
            const SizedBox(height: 20),

            // IN & OUT Time Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Padding(padding: EdgeInsets.all(3)),
                Flexible(child: _buildTimeCard("IN", _formatTime(_checkInTime))),
                Padding(padding: EdgeInsets.all(3)),
                Flexible(child: _buildTimeCard("OUT", _formatTime(_checkOutTime))),
              ],
            ),
            // const SizedBox(height: 1),
            
            

              if (statusCard != null) ...[
                Padding(padding: EdgeInsets.all(3)),
                statusCard,
              ],
                const SizedBox(height: 15),

            // Summary Section (Using GridView)
            const Text(
              "Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 400
                  ? 3
                  : 3, // Keep 3 columns
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9, // Decrease this value to increase height
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSummaryCard(
                    "$_presentCount", "Present", Icons.check_circle),
                _buildSummaryCard("$_absentCount", "Absent", Icons.cancel),
                _buildSummaryCard(
                    "$_holidayCount", "Holidays", Icons.beach_access),
              ],
            ),

            const SizedBox(height: 25),

            // Modules Section (Using GridView)
            const Text(
              "Modules",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 400
                  ? 3
                  : 2, // Responsive grid
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildModuleCard("Time Sheet", Icons.access_time, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            TimesheetCal()), // Navigate to TimesheetCal
                  );
                }),
                _buildModuleCard("Leaves", Icons.event_available, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            LeaveCal()), // Navigate to TimesheetCal
                  );
                }),
                _buildModuleCard("Attendance", Icons.how_to_reg, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AttendanceCal()), // Navigate to TimesheetCal
                  );
                }),
                _buildModuleCard("Documents", Icons.description, () {}),
                _buildModuleCard(
                    "Payroll", Icons.account_balance_wallet, () {}),
                _buildModuleCard("Holidays", Icons.card_travel, () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Time Cards
  Widget _buildSummaryCard(String count, String label, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              tween: Tween<double>(begin: 0.8, end: 1.0), // Small zoom effect
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value, // Smooth zoom in effect
                  child: Icon(icon,
                      color: const Color.fromARGB(255, 0, 102, 150), size: 28),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(count,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Summary Cards
  Widget _buildTimeCard(String label, String time) {
    IconData icon =
        label == "IN" ? Icons.login : Icons.logout; // Dynamic icon selection

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      tween: Tween<double>(begin: 0.8, end: 1.0), // Smooth pop-in effect
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12, blurRadius: 4, spreadRadius: 1)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon,
                          color: label == "IN" ? Colors.green : Colors.red,
                          size: 20), // IN: Green, OUT: Red
                      const SizedBox(width: 5),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(time, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModuleCard(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap, // Navigate when tapped
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600), // Smooth transition
              curve: Curves.easeInOut,
              tween:
                  Tween<double>(begin: 0.8, end: 1.0), // Small to normal size
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value, // Scaling effect
                  child: Icon(icon,
                      color: const Color.fromARGB(255, 0, 102, 150), size: 32),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget? _buildLatestStatusCard() {
  // Parse the time strings
  final checkInDT = _checkInTime.isNotEmpty ? DateTime.tryParse(_checkInTime) : null;
  final checkOutDT = _checkOutTime.isNotEmpty ? DateTime.tryParse(_checkOutTime) : null;
  final latestDT = _latestCheckInTime.isNotEmpty ? DateTime.tryParse(_latestCheckInTime) : null;
  // print("_checkInTime: $_checkInTime");
  // print("_checkOutTime: $_checkOutTime");
  // print("_latestCheckInTime: $_latestCheckInTime");

  // Determine attendance status based on values
  if (checkInDT == null && checkOutDT == null && latestDT == null) {
    attendanceStatus = "checkin";
    return null;
  } else if (checkInDT != null && checkOutDT == null) {
    attendanceStatus = "checkout";
  } else if (checkInDT != null && checkOutDT != null) {
    attendanceStatus = "Present";
  }

 // Only show card if checkIn and latestCheckIn are available
  bool showLatestStatusCard = checkInDT != null && latestDT != null;
  if (!showLatestStatusCard) return null;

  // Determine IN/OUT status
  String statusLabel;
  IconData statusIcon;
  Color statusColor;
  final sttime;


  if(checkOutDT != null ){

  if (latestDT.isBefore(checkOutDT) ) {
    statusLabel = "OUT";
    statusIcon = Icons.logout;
    statusColor = Colors.red.shade100;
    sttime = _checkOutTime;

  } else {
    statusLabel = "IN";
    statusIcon = Icons.login;
    statusColor = Colors.green.shade100;
    sttime = _latestCheckInTime;

  }
  }else {
    statusLabel = "IN";
    statusIcon = Icons.login;
    statusColor = Colors.green.shade100;
    sttime = _latestCheckInTime;
  }


  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: statusColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        
        Row(
          
          children: [
            Text(
          "Latest Update : ",
          // DateFormat('HH:mm a').format(latestDT), // show only time part
          style: const TextStyle(fontSize: 13 , color:Color(0xFF5D6C5D)),
        ),
            Icon(
              statusIcon,
              color: statusLabel == "IN" ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 5),
            Text(
              statusLabel,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Text(
          _formatTime(sttime),
          // DateFormat('HH:mm a').format(latestDT), // show only time part
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
}


}

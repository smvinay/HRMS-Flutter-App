import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'emp_drawer.dart';
import 'header.dart';
import 'timeSheetCal.dart';
import 'leaveCal.dart';
import 'AttendanceCal.dart';
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

  String _employeeCode = "Loading...";
  String _userProfile = "";

  String _presentCount = "0";
  String _absentCount = "0";
  String _holidayCount = "0";
  String _checkInTime = "";
  String _checkOutTime = "";
  String _checkInImage = "";
  String _checkOutImage = "";
  String _latestImage = "";
  String _latestCheckInTime = '';
  String _currentDay = '';

  Map<String, dynamic> attendanceMap = {};
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();
  bool showAttendanceCard = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentDay = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadUserData();
    loadAttendanceForMonth(
      DateTime.now().year,
      DateTime.now().month,
    );
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String selectedYear = DateTime.now().year.toString();
    String selectedMonth = DateTime.now().month.toString();

    setState(() {
      _userId = prefs.getString('user_id') ?? "";
      _username = "${prefs.getString('username') ?? ''}".trim();
      _department = prefs.getString('department_name') ?? "Department";
      _employeeCode = prefs.getString('employe_code') ?? "- - -";
      _userProfile = prefs.getString('user_profile') ?? "";
    });

    // Call API to fetch attendance data
    _loadAttendanceData(_userId, selectedYear, selectedMonth);
  }

  double _calcScaleFromWidth(double w) {
    const base = 475.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  Future<void> _loadAttendanceData(
      String userId, String year, String month) async {
    final prefs = await SharedPreferences.getInstance();
    String apiKey = prefs.getString('apiKey') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";
    String cid = prefs.getString('cid') ?? "";
    String deptID = prefs.getString('department') ?? "";
    String url =
        "https://hrms.attendify.ai/index.php/MobileApi/home?company_db=$companyDb&userid=$userId&cid=$cid&deptID=$deptID";

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

          _checkInTime = data['checkinTime'] ?? '';
          _checkOutTime = data['checkoutTime'] ?? '';
          _checkInImage = data['checkInImage'] ?? '';
          _checkOutImage = data['checkOutImage'] ?? '';
          _latestImage = data['latestImage'] ?? '';
          _latestCheckInTime = data['latestCheckin'] ?? '';
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching attendance data: $e");
    }
  }

  Future<void> loadAttendanceForMonth(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();

    String userId = prefs.getString('employe_code') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";
    String deptId = prefs.getString('department') ?? "0";
    String cid = prefs.getString('cid') ?? "0";

    setState(() {
      isLoading = true;
    });

    String url =
        "https://hrms.attendify.ai/index.php/MobileApi/get_empattendacedata?company_db=$companyDb&userid=$userId&year=$year&month=$month";

    String holidayUrl =
        "https://hrms.attendify.ai/index.php/MobileApi/get_daysholiday?company_db=$companyDb&cid=$cid&year=$year&month=$month&deptID=$deptId";

    try {
      final response = await http.get(Uri.parse(url));
      final holidayResponse = await http.get(Uri.parse(holidayUrl));

      Map<String, dynamic> temp = {};

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['data'] != null) {
          for (var entry in data['data']) {
            if (entry['attendance_date'] != null) {
              String date = entry['attendance_date'].split(" ")[0];

              temp[date] = {
                "status": "Present",
                "checkin": entry['first_check_in'] ?? "",
                "checkout": entry['last_check_in'] ?? "",
                "checkinImage": entry['fullfirst_detected_face'],
                "checkoutImage": entry['fulllast_detected_face']
              };
            }
          }
        }
      }

      // Holiday API
      if (holidayResponse.statusCode == 200) {
        final holidayData = json.decode(holidayResponse.body);

        if (holidayData['data'] != null) {
          for (var holiday in holidayData['data']) {
            String date = holiday['date'];

            temp[date] = {"status": "Holiday", "holidayname": holiday['name']};
          }
        }
      }

      setState(() {
        attendanceMap = temp;
        isLoading = false;
      });
    } catch (e) {
      print("API error: $e");

      setState(() {
        isLoading = false;
      });
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

  Widget fadeInWidget(Widget child, int delay) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeIn,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);
    return Scaffold(
      drawer: CustomDrawer(),
      appBar: const Header(),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData(); // refresh API
          await loadAttendanceForMonth(
            DateTime.now().year,
            DateTime.now().month,
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Greeting Row
                _buildGreetingSection(scale),
                // const SizedBox(height: 20),
                const SizedBox(height: 10),

                // IN & OUT Time Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _buildTimeCard(
                          "Check-In",
                          _formatTime(_checkInTime),
                          _checkInImage,
                          _checkInImage != null && _checkInImage.isNotEmpty
                              ? () => _showImagePopup(context, _checkInImage)
                              : null,
                          scale),
                    ),
                    const Padding(padding: EdgeInsets.all(3)),
                    Flexible(
                      child: _buildTimeCard(
                          "Check-out",
                          _formatTime(_checkOutTime),
                          _checkOutImage,
                          _checkOutImage != null && _checkOutImage.isNotEmpty
                              ? () => _showImagePopup(context, _checkOutImage)
                              : null,
                          scale),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) {
                      return isSameDay(selectedDay, day);
                    },
                    onDaySelected: (selected, focused) {
                      setState(() {
                        selectedDay = selected;
                        focusedDay = focused;
                        showAttendanceCard = true;
                      });
                    },
                    onPageChanged: (newFocusedDay) {
                      setState(() {
                        focusedDay = newFocusedDay;
                      });

                      loadAttendanceForMonth(
                        newFocusedDay.year,
                        newFocusedDay.month,
                      );
                    },
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      leftChevronIcon: Icon(Icons.chevron_left),
                      rightChevronIcon: Icon(Icons.chevron_right),
                      titleTextStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, date, _) {
                        return _buildDayCell(date, false);
                      },
                      todayBuilder: (context, date, _) {
                        return _buildDayCell(date, false, isToday: true);
                      },
                      selectedBuilder: (context, date, _) {
                        return _buildDayCell(date, true);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (showAttendanceCard) ...[
                  const SizedBox(height: 12),
                  buildSelectedAttendance(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingSection(double scale) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E88E5),
                    Color(0xFF42A5F5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_s(14, scale)),
              ),
              child: Stack(
                children: [
                  Positioned(
                      top: -10, right: 20, child: _bubble(_s(40, scale))),
                  Positioned(
                      bottom: -15, left: 30, child: _bubble(_s(45, scale))),
                  Positioned(top: 20, right: 80, child: _bubble(_s(20, scale))),
                  Padding(
                    padding: EdgeInsets.all(_s(10, scale)),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: _s(25, scale),
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: _userProfile.isNotEmpty
                                    ? Image.network(
                                        "https://hrms.attendify.ai/photos/$_userProfile",
                                        width: _s(46, scale),
                                        height: _s(46, scale),
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        "assets/profile.jpg",
                                        width: _s(46, scale),
                                        height: _s(46, scale),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),

                            /// Status Dot
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: _s(12, scale),
                                height: _s(12, scale),
                                decoration: BoxDecoration(
                                  color: attendanceStatus == "checkout"
                                      ? Colors.green
                                      : Colors.red,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: _s(12, scale)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hi, $_username",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _s(18, scale),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: _s(3, scale)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _department,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: _s(13, scale),
                                      color: Colors.white70,
                                    ),
                                  ),
                                  SizedBox(height: _s(2, scale)),
                                  Text(
                                    _getLatestStatus().isNotEmpty
                                        ? "Latest: ${_formatTime(_getLatestStatus())}"
                                        : "",
                                    style: TextStyle(
                                      fontSize: _s(12, scale),
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        SelfAttendanceCamera(
                          key: _cameraKey,
                          attStatus: attendanceStatus,
                          onSuccess: () {
                            _loadUserData();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bubble(double size) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeCard(String label, String time, String image,
      VoidCallback? onTap, double scale) {
    IconData icon = label == "Check-In" ? Icons.login : Icons.logout;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: _s(14, scale),
          horizontal: _s(16, scale),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_s(12, scale)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: label == "Check-In" ? Colors.green : Colors.red,
                  size: _s(22, scale),
                ),
                SizedBox(width: _s(6, scale)),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _s(15, scale),
                  ),
                ),
              ],
            ),
            Text(
              time,
              style: TextStyle(fontSize: _s(14, scale)),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePopup(BuildContext context, String image) {
    final imageUrl = 'https://hrms.attendify.ai/detectedImages/$image';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Reduced border radius
        ),
        child: Container(
          height: 500, // Fixed height
          width: MediaQuery.of(context).size.width *
              0.8, // Optional: make it responsive
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (ctx, err, _) =>
                        const Center(child: Text("Failed to load image")),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close",
                      style: TextStyle(color: Colors.black)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  String _getLatestStatus() {
    final checkInDT =
        _checkInTime.isNotEmpty ? DateTime.tryParse(_checkInTime) : null;
    final checkOutDT =
        _checkOutTime.isNotEmpty ? DateTime.tryParse(_checkOutTime) : null;
    final latestDT = _latestCheckInTime.isNotEmpty
        ? DateTime.tryParse(_latestCheckInTime)
        : null;

    if (checkInDT == null && checkOutDT == null && latestDT == null) {
      attendanceStatus = "checkin";
      return "";
    }

    if (checkInDT != null && checkOutDT == null) {
      attendanceStatus = "checkout";
      return _latestCheckInTime;
    }

    if (checkInDT != null && checkOutDT != null) {
      attendanceStatus = "checkout";
      return _checkOutTime;
    }

    return "";
  }

  Widget _buildDayCell(DateTime date, bool isSelected, {bool isToday = false}) {
    String key = DateFormat('yyyy-MM-dd').format(date);

    bool hasAttendance = attendanceMap.containsKey(key);
    bool isHoliday = hasAttendance && attendanceMap[key]['status'] == "Holiday";

    bool isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isToday ? Colors.blue.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: isSelected
            ? [
                const BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isWeekend ? Colors.grey : Colors.black,
              ),
            ),
          ),

          /// Attendance dot
          if (hasAttendance)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isHoliday ? Colors.orange : Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildSelectedAttendance() {
    String key = DateFormat('yyyy-MM-dd').format(selectedDay);

    if (!attendanceMap.containsKey(key)) {
      return const SizedBox();
    }

    var data = attendanceMap[key];

    if (data['status'] == "Holiday") {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(selectedDay),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.celebration, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  data['holidayname'] ?? "Holiday",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Date
          Text(
            DateFormat('dd MMM yyyy').format(selectedDay),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 12),

          /// Checkin Checkout Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildAttendanceBox(
                  "Check-In",
                  data['checkin'] ?? "-",
                  data['checkinImage'],
                  Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAttendanceBox(
                  "Check-Out",
                  data['checkout'] ?? "-",
                  data['checkoutImage'],
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceBox(
    String title,
    String time,
    String? image,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                title == "Check-In" ? Icons.login : Icons.logout,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          if (image != null && image != "")
            GestureDetector(
              onTap: () => showImage(image),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        "https://hrms.attendify.ai/detectedImages/$image",
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void showImage(String image) {
    String url = "https://hrms.attendify.ai/detectedImages/$image";

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              /// Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                ),
              ),

              /// Close Button
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

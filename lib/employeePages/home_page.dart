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
  String currentStatus = "checkin";
  String _username = "";
  String _department = "";
  String _userId = "";

  String _userProfile = "";

  String _checkInTime = "";
  String _checkOutTime = "";
  String _checkInImage = "";
  String _checkOutImage = "";
  String _latestCheckInTime = '';
  String _currentDay = '';

  Map<String, dynamic> attendanceMap = {};
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();
  bool showAttendanceCard = false;
  bool isLoading = false;

  List<dynamic> breakTimeline = [];
  bool isBreakLoading = false;
  String totalWork = "";
  String totalBreak = "";

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
      _username = (prefs.getString('username') ?? '').trim();
      _department = prefs.getString('department_name') ?? "Department";
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

        setState(() {

          _currentDay = data['currentday']?.toString() ?? _currentDay;
          _checkInTime = data['checkinTime'] ?? '';
          _checkOutTime = data['checkoutTime'] ?? '';
          _checkInImage = data['checkInImage'] ?? '';
          _checkOutImage = data['checkOutImage'] ?? '';
          _latestCheckInTime = data['latestCheckin'] ?? '';
          currentStatus = data['lateststatus'] ?? '';

          /// ✅ ADD THIS
          _updateAttendanceStatus();
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

  Future<void> loadBreakHistory(String date) async {
    final prefs = await SharedPreferences.getInstance();

    String apiKey = prefs.getString('apiKey') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";
    String cid = prefs.getString('cid') ?? "";
    String empCode = prefs.getString('employe_code') ?? "";

    String url =
        "https://hrms.attendify.ai/index.php/MobileApi/empBreakHistory?employeeCode=$empCode&cid=$cid&date=$date";

    try {
      setState(() => isBreakLoading = true);

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "apiKey": apiKey,
          "companyDb": companyDb,
        },
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);

        if (res['status'] == true) {
          setState(() {
            breakTimeline = res['data']['timeline'] ?? [];
            totalWork = res['data']['totalWork'] ?? "";
            totalBreak = res['data']['totalBreak'] ?? "";
          });
        }
      }
    } catch (e) {
      print("Break API Error: $e");
    } finally {
      setState(() => isBreakLoading = false);
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
      drawer: CustomDrawer(currentRoute: '/home'),
      appBar: const Header(),
      body: RefreshIndicator(
        onRefresh: () async {

          DateTime now = DateTime.now();

          await _loadUserData();

          await loadAttendanceForMonth(
            now.year,
            now.month,
          );

          setState(() {
            /// ✅ Reset calendar to today
            selectedDay = now;
            focusedDay = now;

            /// ✅ Show updated card
            showAttendanceCard = false;
          });
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          _checkInImage.isNotEmpty
                              ? () => showImage(_checkInImage)
                              : null,
                          scale),
                    ),
                    const Padding(padding: EdgeInsets.all(3)),
                    Flexible(
                      child: _buildTimeCard(
                          "Check-out",
                          _formatTime(_checkOutTime),
                          _checkOutImage,
                          _checkOutImage.isNotEmpty
                              ? () => showImage(_checkOutImage)
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
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.0), // Set the top-left radius
                      topRight: Radius.circular(12.0), // Set the top-right radius
                      // bottomLeft and bottomRight are zero by default
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: TableCalendar(
                    key: ValueKey(focusedDay),
                    rowHeight: 40,
                    daysOfWeekHeight: 30,
                    calendarStyle: const CalendarStyle(
                      cellMargin: EdgeInsets.all(3),
                      outsideDaysVisible: false,
                    ),
                    firstDay: DateTime.utc(2026, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: focusedDay,
                    selectedDayPredicate: (day) {
                      return isSameDay(selectedDay, day);
                    },

                    onDaySelected: (selected, focused) {

                      DateTime today = DateTime.now();

                      DateTime selectedDate =
                      DateTime(selected.year, selected.month, selected.day);

                      DateTime todayDate =
                      DateTime(today.year, today.month, today.day);

                      String key = DateFormat('yyyy-MM-dd').format(selectedDate);

                      bool isHoliday =
                          attendanceMap.containsKey(key) &&
                              attendanceMap[key]['status'] == "Holiday";

                      /// Block future dates only if NOT holiday
                      if (selectedDate.isAfter(todayDate) && !isHoliday) {
                        return;
                      }
                      setState(() {
                        selectedDay = selected;
                        focusedDay = focused;
                        showAttendanceCard = true;
                      });
                      if(!isHoliday) {
                        loadBreakHistory(key);
                      }
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

                      // headerPadding: EdgeInsets.symmetric(vertical: 4),
                      headerMargin: EdgeInsets.only(bottom: 8),

                      leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                      rightChevronIcon: Icon(Icons.chevron_right, size: 20),

                      leftChevronPadding: EdgeInsets.all(0),
                      rightChevronPadding: EdgeInsets.all(0),

                      titleTextStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, date, _) {
                        return _buildDayCell(date, false ,scale);
                      },
                      todayBuilder: (context, date, _) {
                        return _buildDayCell(date, false,scale, isToday: true);
                      },
                      selectedBuilder: (context, date, _) {
                        return _buildDayCell(date, true , scale);
                      },
                    ),
                  ),
                ),

            _buildCalendarLegend(scale),
             const SizedBox(height: 12),
                if (showAttendanceCard) ...[
                  buildSelectedAttendance(),
                  buildBreakTable(),
                ],
              ],
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
                borderRadius: BorderRadius.circular(_s(12, scale)),
              ),
              child: Stack(
                children: [
                  Positioned(
                      top: -10, right: 20, child: _bubble(_s(40, scale))),
                  Positioned(
                      bottom: -15, left: 30, child: _bubble(_s(45, scale))),
                  Positioned(top: 20, right: 80, child: _bubble(_s(20, scale))),
                  Padding(
                    padding: EdgeInsets.all(_s(8, scale)),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: _s(30, scale),
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: _userProfile.isNotEmpty
                                    ? Image.network(
                                        "https://hrms.attendify.ai/photos/$_userProfile",
                                        width: _s(55, scale),
                                        height: _s(55, scale),
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        "assets/profile.jpg",
                                        width: _s(55, scale),
                                        height: _s(55, scale),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),

                            /// Status Dot
                            if(currentStatus != '')
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: _s(15, scale),
                                height: _s(15, scale),
                                decoration: BoxDecoration(
                                  color: currentStatus == "checkout"
                                      ? Colors.red
                                      : Colors.green,
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
                                    _latestCheckInTime.isNotEmpty
                                        ? "Latest: ${_formatTime(_latestCheckInTime)}"
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
                          onSuccess: () async {
                            DateTime now = DateTime.now();
                            await _loadUserData();
                            await loadAttendanceForMonth(
                            now.year,
                            now.month,
                            );
                            setState(() {
                              selectedDay = now;
                              focusedDay = now;
                              showAttendanceCard = false;
                            });
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

  Widget _buildTimeCard(
      String label,
      String time,
      String image,
      VoidCallback? onTap,
      double scale,
      ) {
    IconData icon = label == "Check-In" ? Icons.login : Icons.logout;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: _s(12, scale),
          horizontal: _s(14, scale),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_s(12, scale)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: _s(6, scale),
              offset: Offset(0, _s(3, scale)),
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
                  size: _s(20, scale),
                ),

                SizedBox(width: _s(6, scale)),

                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _s(14, scale),
                  ),
                ),
              ],
            ),

            Text(
              time,
              style: TextStyle(
                fontSize: _s(14, scale),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _updateAttendanceStatus() {
    if (currentStatus == null || currentStatus.isEmpty) {
      attendanceStatus = "checkin";
    } else if (currentStatus == "checkout") {
      attendanceStatus = "checkin";
    } else {
      attendanceStatus = "checkout";
    }
  }

  Widget _buildDayCell(DateTime date, bool isSelected, double scale, {bool isToday = false}) {
    String key = DateFormat('yyyy-MM-dd').format(date);

    DateTime today = DateTime.now();

    /// 🔥 SHIFT END TIME (today)
    DateTime shiftEnd = DateTime(
      today.year,
      today.month,
      today.day,
      18, // hour
      30, // minute
    );

    bool isTodayDate =
        date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;

    bool isBeforeShiftEnd = today.isBefore(shiftEnd);

    bool hasData = attendanceMap.containsKey(key);
    bool isHoliday = hasData && attendanceMap[key]['status'] == "Holiday";

    bool hasCheckIn =
        hasData && (attendanceMap[key]['checkin'] != null && attendanceMap[key]['checkin'] != "");

    bool hasCheckOut =
        hasData && (attendanceMap[key]['checkout'] != null && attendanceMap[key]['checkout'] != "");

    bool isCheckInOnly = hasCheckIn && !hasCheckOut;
    bool isCheckOutOnly = !hasCheckIn && hasCheckOut;
    bool isPastDay = date.isBefore(DateTime(today.year, today.month, today.day));
    bool isAbsent = !hasData && isPastDay;
    bool isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    BoxBorder? border;


    /// Check-in only
     if (isCheckInOnly) {
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    }


    /// Present (Check-in + Check-out)
    else if (hasCheckIn && hasCheckOut) {

      /// 🔥 TODAY → check shift timing
      if (isTodayDate && isBeforeShiftEnd) {
        /// STILL WORKING → BLUE
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
      } else {
        /// AFTER SHIFT → GREEN
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
      }
    }
    /// Absent
    else if (isAbsent && !isToday && !isWeekend && !isHoliday) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
    }
    /// Holiday
    if (isHoliday) {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
    }


    /// Weekend
    else if (isWeekend) {
      bgColor = Colors.white;
      textColor = Colors.grey;
    }

    /// Today border
    if (isToday) {
      border = Border.all(
        color: Colors.blue,
        width: 2,
      );
    }

    return Container(
      margin: EdgeInsets.all(_s(2, scale)),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,

        border: isToday
            ? Border.all(
          color: Colors.blue,
          width: 1,
        )
            : null,

        boxShadow: isSelected
            ? [
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ]
            : [],
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: _s(13, scale),
            color: textColor,
          ),
        ),
      ),
    );
  }
  Widget buildSelectedAttendance() {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    String key = DateFormat('yyyy-MM-dd').format(selectedDay);

    if (!attendanceMap.containsKey(key)) {
      return const SizedBox();
    }

    var data = attendanceMap[key];

    /// DATE HEADER
    Widget dateHeader = Center(
      child: Text(
        DateFormat('dd-MM-yyyy').format(selectedDay),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _s(16, scale),
        ),
      ),
    );

    /// HOLIDAY CARD
    if (data['status'] == "Holiday") {
      return Container(
        padding: EdgeInsets.all(_s(12, scale)),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(_s(14, scale)),
          border: Border.all(color: Colors.orange.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: _s(6, scale),
              offset: Offset(0, _s(3, scale)),
            )
          ],
        ),
        child: Column(
          children: [

            dateHeader,

            SizedBox(height: _s(14, scale)),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Icon(
                  Icons.celebration,
                  color: Colors.orange,
                  size: _s(22, scale),
                ),

                SizedBox(width: _s(6, scale)),

                Text(
                  data['holidayname'] ?? "Holiday",
                  style: TextStyle(
                    fontSize: _s(15, scale),
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    /// NORMAL ATTENDANCE CARD
    return Container(
      padding: EdgeInsets.all(_s(10, scale)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(12, scale)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: _s(8, scale),
            offset: Offset(0, _s(3, scale)),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          dateHeader,

          SizedBox(height: _s(12, scale)),

          Row(
            children: [

              Expanded(
                child: _buildAttendanceBox(
                  "Check-In",
                  _formatTime(data['checkin']),
                  data['checkinImage'],
                  Colors.green,
                  scale,
                ),
              ),

              SizedBox(width: _s(10, scale)),

              Expanded(
                child: _buildAttendanceBox(
                  "Check-Out",
                  _formatTime(data['checkout']),
                  data['checkoutImage'],
                  Colors.red,
                  scale,
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
      double scale,
      ) {
    return Container(
      padding: EdgeInsets.all(_s(10, scale)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_s(10, scale)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _s(13, scale),
                ),
              ),

              const Spacer(),

              Text(
                time,
                style: TextStyle(
                  fontSize: _s(14, scale),
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),

          SizedBox(height: _s(8, scale)),

          if (image != null && image != "")
            GestureDetector(
              onTap: () => showImage(image),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_s(8, scale)),
                child: Stack(
                  children: [

                    Image.network(
                      "https://hrms.attendify.ai/detectedImages/$image",
                      height: _s(95, scale),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),

                    Positioned(
                      bottom: _s(4, scale),
                      right: _s(4, scale),
                      child: Container(
                        padding: EdgeInsets.all(_s(3, scale)),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.zoom_in,
                          size: _s(14, scale),
                          color: Colors.white,
                        ),
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
  void showImage(String image) {
    String url = "https://hrms.attendify.ai/detectedImages/$image";

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true, // ✅ click outside to close
      builder: (_) {
        final size = MediaQuery.of(context).size;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 40,
          ), // ✅ space around dialog
          child: Stack(
            children: [
              /// Image Container
              Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            // child: Image.network(url, fit: BoxFit.contain),
        child: Container(
                  width: size.width * 0.95, // 🔥 slightly reduced
                  constraints: BoxConstraints(
                    maxHeight: size.height * 0.85,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              ),

              /// Close Button (Improved UI)
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white, // ✅ white background
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 22,
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

  Widget _buildCalendarLegend(double scale) {
    return Container(
      padding: EdgeInsets.all(_s(5, scale)),
      // margin: EdgeInsets.only(top: _s(5, scale)),
      decoration: BoxDecoration(
        color: Colors.white,
        // borderRadius: BorderRadius.circular(_s(10, scale)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12.0), // Set the top-left radius
          bottomRight: Radius.circular(12.0), // Set the top-right radius
          // bottomLeft and bottomRight are zero by default
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: _s(5, scale),
            offset: Offset(0, _s(2, scale)),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center ,
        spacing: _s(15, scale),
        // runSpacing: _s(8, scale),
        children: [
          _legendItem("Present", Colors.green.shade200, scale),
          _legendItem("Check-In Only", Colors.blue.shade200, scale),
          _legendItem("Absent", Colors.red.shade200, scale),
          _legendItem("Holiday", Colors.orange.shade200, scale),
          // _legendBorderItem("Today", Colors.blue, scale),
        ],
      ),
    );
  }

  Widget _legendItem(String text, Color color, double scale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _s(14, scale),
          height: _s(14, scale),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: _s(6, scale)),
        Text(
          text,
          style: TextStyle(
            fontSize: _s(12, scale),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget buildBreakTable() {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);
    String key = DateFormat('yyyy-MM-dd').format(selectedDay);

    if (!attendanceMap.containsKey(key)) {
      return const SizedBox();
    }

    if (isBreakLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (breakTimeline.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Text("No timeline records found"),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// ================= HEADER =================
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              /// TITLE CENTER
              Center(
                child: Text(
                  "Day Break Logs",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _s(15, scale),
                  ),
                ),
              ),

              SizedBox(height: _s(12, scale)),

              /// 3 EQUAL COLUMNS
              Row(
                children: [

                  /// DURATION
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Duration",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: _s(11, scale),
                          ),
                        ),
                        SizedBox(height: _s(4, scale)),
                        Text(
                          totalWork,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: _s(15, scale),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// WORKING
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Working",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: _s(11, scale),
                          ),
                        ),
                        SizedBox(height: _s(4, scale)),
                        Text(
                          totalWork,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: _s(15, scale),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// BREAK
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Break",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: _s(11, scale),
                          ),
                        ),
                        SizedBox(height: _s(4, scale)),
                        Text(
                          totalBreak,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: _s(15, scale),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade300),

          /// ================= TABLE =================
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth, // 🔥 FIX FULL WIDTH
                  ),
                  child: DataTable(
                    columnSpacing: constraints.maxWidth * 0.05,
                    columns: const [
                      DataColumn(label: Text("Sl.No")),
                      DataColumn(label: Text("Image")),
                      DataColumn(label: Text("From")),
                      DataColumn(label: Text("To")),
                      DataColumn(label: Text("Duration")),
                      DataColumn(label: Text("Work")),
                      DataColumn(label: Text("Break")),
                    ],
                    rows: List.generate(breakTimeline.length, (index) {
                      var row = breakTimeline[index];

                      int from = row['from'];
                      int to = row['to'];
                      int sec = to - from;

                      int h = sec ~/ 3600;
                      int m = (sec % 3600) ~/ 60;
                      int s = sec % 60;

                      String dur;

                      if (h > 0) {
                        dur = "${h}h ${m}m ${s}s";
                      } else if (m > 0) {
                        dur = "${m}m ${s}s";
                      } else {
                        dur = "${s}s";
                      }

                      return DataRow(cells: [
                        DataCell(Text("${index + 1}")),

                        DataCell(
                          row['start_image_thumb'] != null &&
                              row['start_image_thumb'] != ""
                              ? GestureDetector(
                            onTap: () => showImage(row['start_image']), // 🔥 FULL IMAGE
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                "https://hrms.attendify.ai/detectedImages/${row['start_image_thumb']}",
                                height: 45,
                                width: 45,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                              : const Text("—"),
                        ),

                        DataCell(Text(row['from_time'] ?? "-")),
                        DataCell(Text(row['to_time'] ?? "-")),
                        DataCell(Text(row['duration_text'] ?? "-")),

                        /// WORK
                        DataCell(
                          row['type'] == 'work'
                              ? Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(dur),
                          )
                              : const Text("-"),
                        ),

                        /// BREAK
                        DataCell(
                          row['type'] == 'break'
                              ? Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(dur),
                          )
                              : const Text("-"),
                        ),
                      ]);
                    }),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

}

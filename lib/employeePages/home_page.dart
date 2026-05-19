import 'dart:convert';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:table_calendar/table_calendar.dart';
import '../global_state.dart';
import 'ApplyLeavePage.dart';
import 'emp_drawer.dart';
import 'header.dart';
import 'package:intl/intl.dart';
import 'SelfAttendanceCamera.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
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
  String totalDuration = "";
  String totalBreak = "";
  bool _isUpdatingLocation = false;

  int pendingCount = 0;

  Map<String, dynamic> summaryData = {};
  late AnimationController animationController;
  late AnimationController blinkController;

  double getLineCenter(double width) => width / 2;

  double getLeftX(double width, double scale) =>
      getLineCenter(width) - _s(60, scale);

  double getRightX(double width, double scale) =>
      getLineCenter(width) + _s(60, scale);

  String _getCacheKey(int year, int month) {
    return "attendance_${year}_$month";
  }

  String _getHolidayKey(int year, int month) {
    return "holiday_${year}_$month";
  }

  late TransformationController _transformationController;
  String loadedMonthKey = "";
  String? errorText;

  bool isWithdrawing = false;
  bool _instructionShown = false;
  bool _instructionChecked = false;

  @override
  void initState() {
    super.initState();
    _currentDay = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _transformationController = TransformationController();
    _loadUserData();
    loadAttendanceForMonth(
      DateTime.now().year,
      DateTime.now().month,
    );
    _initLocation();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

  }

  @override
  void dispose() {
    _transformationController.dispose();
    animationController.dispose();
    blinkController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    await updateLocationAndAddressInBackground();
  }

  Future<void> updateLocationAndAddressInBackground() async {
    if (_isUpdatingLocation) return;

    _isUpdatingLocation = true;

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
    } finally {
      _isUpdatingLocation = false;
    }
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

  Future<Position> _determinePosition() async {
    LocationPermission permission;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    return await Geolocator.getCurrentPosition();
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
    fetchLeaves();
  }

  double _calcScaleFromWidth(double w) {
    const base = 460.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  Future<void> _loadAttendanceData(
      String userId, String year, String month) async {
    final prefs = await SharedPreferences.getInstance();
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

          ///  ADD THIS
          _updateAttendanceStatus();
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching attendance data: $e");
    }
  }

  Future<void> fetchLeaves() async {

    try {
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";
      String userID = prefs.getString('user_id') ?? "";
      String levelId = prefs.getString('level_id') ?? "";

      final response = await http.get(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/MobileApi/allEmpLeaves?userId=$userID&levelId=$levelId"),
        headers: {"apiKey": apiKey, "companyDb": companyDb},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        pendingCount = data['pendingLeavesCount'] ?? 0;
        pendingLeaveNotifier.value = data['pendingLeavesCount'] ?? 0;
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> loadAttendanceForMonth(int year, int month,
      {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final box = Hive.box('attendanceBox');

    String apiKey = prefs.getString('apiKey') ?? "";
    String userCode = prefs.getString('employe_code') ?? "";
    String userId = prefs.getString('user_id') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";
    String deptId = prefs.getString('department') ?? "0";
    String cid = prefs.getString('cid') ?? "0";

    String cacheKey = _getCacheKey(year, month);
    String holidayKey =  _getHolidayKey(year, month);

    final now = DateTime.now();
    final isCurrentMonth = (year == now.year && month == now.month);

    bool shouldUseCache =
        !forceRefresh && box.containsKey(cacheKey) && !isCurrentMonth;

    if (forceRefresh) {
      await box.clear();
    }

    if (shouldUseCache) {
      final cachedData = box.get(cacheKey);

      setState(() {
        attendanceMap = Map<String, dynamic>.from(cachedData);
        loadedMonthKey = "${year}_$month";
        isLoading = false;
      });

      return;
    }

    setState(() => isLoading = true);

    String url =
        "https://hrms.attendify.ai/index.php/MobileApi/get_empattendacedata?company_db=$companyDb&userid=$userCode&year=$year&month=$month";

    String holidayUrl =
        "https://hrms.attendify.ai/index.php/MobileApi/get_daysholiday?company_db=$companyDb&cid=$cid&year=$year&month=$month&deptID=$deptId";

    String leaveUrl =
        "https://hrms.attendify.ai/index.php/MobileApi/employeeLeavedetails";

    try {
      final response = await http.get(Uri.parse(url));
      final holidayResponse = await http.get(Uri.parse(holidayUrl));

      final leaveresponse = await http.post(
        Uri.parse(leaveUrl),
        headers: {"apiKey": apiKey, "companyDb": companyDb},
        body: {
          "cid": cid,
          "user_id": userId,
          "code": userCode,
        },
      );

      Map<String, dynamic> temp = {};

      ///  ATTENDANCE
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['data'] != null) {
          for (var entry in data['data']) {
            String date = entry['attendance_date'].split(" ")[0];

            temp[date] = {
              "status": "Present",
              "lateststatus": entry['status'] ?? "",
              "checkin": entry['first_check_in'] ?? "",
              "checkout": entry['last_check_in'] ?? "",
              "checkinImage": entry['fullfirst_detected_face'],
              "checkoutImage": entry['fulllast_detected_face']
            };
          }
        }
      }

      ///  LEAVE DATA
      if (leaveresponse.statusCode == 200) {
        final leaveData = json.decode(leaveresponse.body);
        if (leaveData != null && leaveData['userLeaves'] != null) {
          for (var item in leaveData['userLeaves']) {
            int status = int.tryParse(item['approved'].toString()) ?? 0;

            ///  FILTER ONLY 0 & 1
            if (status != 0 && status != 1) continue;
            DateTime start = DateTime.parse(item['from_date']);
            DateTime end = DateTime.parse(item['to_date']);

            for (DateTime d = start;
                !d.isAfter(end);
                d = d.add(Duration(days: 1))) {
              String date = DateFormat('yyyy-MM-dd').format(d);

              temp[date] = {
                ...(temp[date] ?? {}),
                "leaves": [
                  ...((temp[date]?['leaves'] ?? []) as List),
                  {
                    "leave_id": item['leave_id'],
                    "applied_date": item['applied_date'],
                    "status": status,
                    "reason": item['reason'] ?? "",
                    "reporting_to_name": item['reporting_to_name'] ?? "",
                    "type": item['type'] ?? "",
                    "days": item['days'],
                    "from_date": item['from_date'],
                    "to_date": item['to_date'],
                  }
                ]
              };
            }
          }
        }
      }

      ///  HOLIDAYS
      if (holidayResponse.statusCode == 200) {
        final holidayData = json.decode(holidayResponse.body);

        if (holidayData['data'] != null) {
          for (var holiday in holidayData['data']) {
            String date = holiday['date'];

            if (temp.containsKey(date)) {
              temp[date]['holidaystatus'] = "Holiday";
              temp[date]['holidayname'] = holiday['name'];
            } else {
              temp[date] = {
                "holidaystatus": "Holiday",
                "holidayname": holiday['name']
              };
            }
          }
        }
      }

      ///  SAVE TO CACHE
      await box.put(cacheKey, temp);

      setState(() {
        attendanceMap = temp;
        loadedMonthKey = "${year}_$month";
        isLoading = false;
      });
    } catch (e) {
      print("API error: $e");

      setState(() => isLoading = false);
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
            breakTimeline = res['timeline'] ?? [];
            summaryData = res['summary'] ?? {};
            totalWork = res['totalWork'] ?? "";
            totalDuration = res['totalDuration'] ?? "";
            totalBreak = res['totalBreak'] ?? "";
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

  List<Map<String, dynamic>> buildRoadMapTimeline() {
    List<Map<String, dynamic>> finalList = [];
    int? lastWorkEndIndex;
    for (var item in breakTimeline) {
      ///  WORK ONLY
      if (item['type'] == 'work') {
        finalList.add({
          'time': item['from_time'],
          'event': item['event_start'],
          'capture': item['start_capture'],
          'start_image_thumb': item['start_image_thumb'],
          'end_image_thumb': item['end_image_thumb'],
          'start_image': item['start_image'],
          'end_image': item['end_image'],
          'side': item['start_capture'] == 'mobile' ? 'right' : 'left',
          'type': 'work',
          'isLive': false,
          'duration': item['duration_text'],
        });

        finalList.add({
          'time': item['to_time'],
          'event': item['event_end'],
          'capture': item['end_capture'],
          'start_image_thumb': item['start_image_thumb'],
          'end_image_thumb': item['end_image_thumb'],
          'start_image': item['start_image'],
          'end_image': item['end_image'],
          'side': item['end_capture'] == 'mobile' ? 'right' : 'left',
          'type': 'work',
          'isLive': false,
          'duration': "",
        });

        lastWorkEndIndex = finalList.length - 1;
      }

      if (item['type'] == 'break') {
        ///  APPLY BREAK DURATION TO PREVIOUS CHECKOUT
        if (lastWorkEndIndex != null) {
          finalList[lastWorkEndIndex]['duration'] = item['duration_text'];
        }
      }

      ///  ADD LIVE STATUS NODE
      if (item['type'] == 'status' && item['is_live'] == true) {
        finalList.add({
          'time': item['start_time_text'],
          'event': 'checkin',
          'capture': item['capture'],
          'start_image_thumb': item['last_image_thumb'],
          'last_image': item['last_image'],
          'side': item['end_capture'] == 'mobile' ? 'right' : 'left',
          'type': 'live',
          'isLive': true,
          'label': item['label']
        });
      }
    }
    return finalList;
  }

  String getFullDayDuration() {
    String? checkin = summaryData['first_check_in'];
    String? checkout = summaryData['last_check_in'];

    if (checkin == null || checkout == null) return "";

    DateTime start = DateTime.parse(checkin);
    DateTime end = DateTime.parse(checkout);

    Duration diff = end.difference(start);

    if (diff.inHours > 0) {
      return "${diff.inHours}h ${diff.inMinutes % 60}m";
    } else {
      return "${diff.inMinutes}m";
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

  double getRowHeight(double scale) {
    return _s(90, scale); //  single source of truth
  }

  @override
  Widget build(BuildContext context) {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);
    return Scaffold(
      drawer: CustomDrawer(
        currentRoute: '/home',
        pendingCount: pendingCount,
      ),
      appBar: const Header(),
      body: RefreshIndicator(
        onRefresh: () async {
          DateTime now = DateTime.now();
          await _loadUserData();
          await loadAttendanceForMonth(
            now.year,
            now.month,
            forceRefresh: true,
          );

          setState(() {
            selectedDay = now;
            focusedDay = now;
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
                onDaySelected: (selected, focused) async {
                  DateTime today = DateTime.now();

                  DateTime selectedDate =
                      DateTime(selected.year, selected.month, selected.day);

                  DateTime todayDate =
                      DateTime(today.year, today.month, today.day);

                  String key = DateFormat('yyyy-MM-dd').format(selectedDate);

                  bool hasData = attendanceMap.containsKey(key);

                  bool isHoliday = hasData &&
                      attendanceMap[key]['holidaystatus'] == "Holiday";

                  ///  CHECK LEAVE FIRST (IMPORTANT)
                  bool hasLeave =
                      hasData && attendanceMap[key]['leaves'] != null;

                  int leaveId = 0;

                  bool isApprovedLeave = false;

                  if (hasLeave) {
                    List leaves = attendanceMap[key]['leaves'];

                    ///  get first leave id (you can change logic if multiple)
                    leaveId = int.tryParse(
                        (leaves.first['leave_id'] ?? "0").toString()) ??
                        0;

                    isApprovedLeave =
                        leaves.any((l) => l['status'] == 1);
                  }

                  ///  NAVIGATION
                  if (selectedDate.isAfter(todayDate) &&
                      !isHoliday &&
                      !isApprovedLeave) {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplyLeavePage(
                          selectedDate: selectedDate,
                          leaveId: leaveId,   //  PASS HERE
                        ),
                      ),
                    );
                    return;
                  }

                  ///  CHECKOUT LOGIC
                  bool latestStatus = hasData &&
                      attendanceMap[key]['lateststatus'] == "checkin";

                  bool hasCheckIn = hasData &&
                      (attendanceMap[key]['checkin'] != null &&
                          attendanceMap[key]['checkin'] != "");


                  bool isPastDay = selectedDate.isBefore(todayDate);

                  bool isEligibleForCheckout =
                      isPastDay && hasCheckIn && latestStatus;

                  if (isEligibleForCheckout) {
                    errorText = null;
                    _openCheckoutModal(key);
                  }

                  ///  NORMAL FLOW
                  setState(() {
                    selectedDay = selected;
                    focusedDay = focused;
                    showAttendanceCard = true;
                    breakTimeline = [];
                  });

                  bool hasCheckOut = hasData &&
                      (attendanceMap[key]['checkout'] != null &&
                          attendanceMap[key]['checkout'] != "");

                  bool hasAttendance = hasCheckIn || hasCheckOut;

                  bool isAbsent =
                      !hasAttendance &&
                          !isHoliday &&
                          selectedDate.isBefore(todayDate);

                  if (isAbsent) {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplyLeavePage(
                          selectedDate: selectedDate,
                          leaveId: 0,
                        ),
                      ),
                    );

                    return;
                  }

                  // await loadBreakHistory(key);
                },
                onPageChanged: (newFocusedDay) {
                  setState(() {
                    focusedDay = newFocusedDay;
                    isLoading = true;
                  });

                  loadAttendanceForMonth(
                    newFocusedDay.year,
                    newFocusedDay.month,
                  ); //  uses cache
                },

                onDayLongPressed: (selected, focused) async {

                  DateTime today = DateTime.now();

                  DateTime selectedDate =
                  DateTime(selected.year, selected.month, selected.day);

                  DateTime todayDate =
                  DateTime(today.year, today.month, today.day);

                  String key = DateFormat('yyyy-MM-dd').format(selectedDate);

                  bool hasData = attendanceMap.containsKey(key);

                  bool isHoliday = hasData &&
                      attendanceMap[key]['holidaystatus'] == "Holiday";

                  /// LEAVE CHECK
                  bool hasLeave =
                      hasData && attendanceMap[key]['leaves'] != null;

                  bool isApprovedLeave = false;

                  if (hasLeave) {
                    List leaves = attendanceMap[key]['leaves'];

                    isApprovedLeave =
                        leaves.any((l) => l['status'] == 1);
                  }

                  /// ATTENDANCE CHECK
                  bool hasCheckIn = hasData &&
                      (attendanceMap[key]['checkin'] != null &&
                          attendanceMap[key]['checkin'] != "");

                  bool hasCheckOut = hasData &&
                      (attendanceMap[key]['checkout'] != null &&
                          attendanceMap[key]['checkout'] != "");

                  bool hasAttendance = hasCheckIn || hasCheckOut;

                  /// ABSENT DAY
                  bool isAbsent =
                      !hasAttendance &&
                          !isHoliday &&
                          selectedDate.isBefore(todayDate);

                  /// CONDITIONS
                  bool allowLongPress =
                      (hasAttendance || isAbsent) &&
                          !isHoliday &&
                          !isApprovedLeave;

                  if (!allowLongPress) {
                    return;
                  }
                  HapticFeedback.lightImpact();
                  final action = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),

                              const SizedBox(height: 18),

                              const Icon(
                                Icons.event_note,
                                color: Color(0xFF0557a2),
                                size: 34,
                              ),

                              const SizedBox(height: 12),

                              Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 8),

                              const Text(
                                "Do you want to apply leave for this date?",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Row(
                                children: [

                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Cancel"),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0557a2),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context, "apply");
                                      },
                                      child: const Text(
                                        "Apply Leave",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );

                  if (action == "apply") {

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApplyLeavePage(
                          selectedDate: selectedDate,
                          leaveId: 0,
                        ),
                      ),
                    );
                  }
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
                    return _buildDayCell(date, false, scale);
                  },
                  todayBuilder: (context, date, _) {
                    return _buildDayCell(date, false, scale, isToday: true);
                  },
                  selectedBuilder: (context, date, _) {
                    return _buildDayCell(date, true, scale);
                  },
                ),
              ),
            ),

            _buildCalendarLegend(scale),
            const SizedBox(height: 8),
            if (showAttendanceCard) ...[
              buildSelectedAttendance(),
              // buildRoadMapCard(),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _formatTo12Hour(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;

    return "$hour12:$minute $period";
  }

  void _openCheckoutModal(String date) {
    TimeOfDay? selectedTime;

    String checkinRaw = attendanceMap[date]['checkin'] ?? "";
    String checkinFormatted = _formatTime(checkinRaw);
    bool isConfirmed = false;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.white, //  white bg
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// HEADER
                    Row(
                      children: const [
                        Icon(Icons.access_time, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          "Add Checkout",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// DATE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Date: ${DateFormat('dd-MM-yyyy').format(DateTime.parse(date))}",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// CHECK-IN TIME
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Check-In: $checkinFormatted",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    /// TIME PICKER
                    GestureDetector(
                      onTap: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );

                        if (picked != null) {
                          setState(() {
                            selectedTime = picked;
                            errorText = null;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          selectedTime == null
                              ? "Select Checkout Time"
                              : _formatTo12Hour(selectedTime!),
                          style: TextStyle(
                            fontSize: 15,
                            color: selectedTime == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isConfirmed,
                          onChanged: (val) {
                            setState(() {
                              isConfirmed = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                isConfirmed = !isConfirmed;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                "I hereby consent to manual self-attendance marking.",
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (errorText != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    Row(
                      children: [
                        /// CANCEL
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                        /// DIVIDER
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),

                        /// SUBMIT
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (selectedTime == null) return;

                              DateTime checkinTime = DateTime.parse(checkinRaw);

                              DateTime selectedDateTime = DateTime(
                                checkinTime.year,
                                checkinTime.month,
                                checkinTime.day,
                                selectedTime!.hour,
                                selectedTime!.minute,
                              );

                              if (selectedDateTime.isBefore(checkinTime)) {
                                setState(() {
                                  errorText =
                                      "Checkout cannot be before check-in";
                                });
                                return;
                              }
                              if (!isConfirmed) {
                                setState(() {
                                  errorText =
                                      "Please confirm before submitting";
                                });
                                return;
                              }

                              String time =
                                  "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";

                              Navigator.pop(context);
                              submitCheckout(date, time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              child: const Text(
                                "Submit",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> submitCheckout(String date, String time) async {
    final prefs = await SharedPreferences.getInstance();

    String apiKey = prefs.getString('apiKey') ?? "";
    String companyDb = prefs.getString('companyDb') ?? "";
    String cid = prefs.getString('cid') ?? "";
    String userId = prefs.getString('employe_code') ?? "";
    String firstName = prefs.getString('username') ?? "";
    String lastName = prefs.getString('last_name') ?? "";

    String url = "https://hrms.attendify.ai/index.php/MobileApi/manualEntry";

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "apiKey": apiKey,
        "companyDb": companyDb,
      },
      body: {
        "cid": cid,
        "userid": userId,
        "firstName": firstName,
        "lastName": lastName,
        "attendance_date": date,
        "check_out_time": time,
        "has_check_out": "1"
      },
    );

    final res = jsonDecode(response.body);

    if (res['status'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'])),
      );

      /// refresh
      DateTime selectedDate = DateTime.parse(date);

      final box = Hive.box('attendanceBox');
      String cacheKey = "attendance_${selectedDate.year}_${selectedDate.month}";

      ///  DELETE OLD CACHE
      await box.delete(cacheKey);

      ///  RELOAD THAT MONTH
      await loadAttendanceForMonth(
        selectedDate.year,
        selectedDate.month,
        forceRefresh: true,
      );

      setState(() {
        focusedDay = selectedDate;
        selectedDay = selectedDate;
      });
      String key = DateFormat('yyyy-MM-dd').format(selectedDate);
      // await loadBreakHistory(key);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? "Failed")),
      );
    }
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
                            if (currentStatus != '')
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
                                    border: Border.all(
                                        color: Colors.white, width: 2),
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

  Widget _buildDayCell(DateTime date, bool isSelected, double scale,
      {bool isToday = false}) {
    String key = DateFormat('yyyy-MM-dd').format(date);
    DateTime today = DateTime.now();

    String currentMonthKey = "${date.year}_${date.month}";
    bool isMonthLoaded = currentMonthKey == loadedMonthKey;

    ///  SHIFT END TIME (today)
    DateTime shiftEnd = DateTime(
      today.year,
      today.month,
      today.day,
      18, // hour
      30, // minute
    );

    bool isTodayDate = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    bool isBeforeShiftEnd = today.isBefore(shiftEnd);

    bool hasData = attendanceMap.containsKey(key);
    bool isHoliday =
        hasData && attendanceMap[key]['holidaystatus'] == "Holiday";
    bool latestStatus =
        hasData && attendanceMap[key]['lateststatus'] == "checkin";

    bool hasCheckIn = hasData &&
        (attendanceMap[key]['checkin'] != null &&
            attendanceMap[key]['checkin'] != "");
    bool hasCheckOut = hasData &&
        (attendanceMap[key]['checkout'] != null &&
            attendanceMap[key]['checkout'] != "");
    bool isCheckInOnly = hasCheckIn && !hasCheckOut;
    bool isPastDay =
        date.isBefore(DateTime(today.year, today.month, today.day));
    bool isAbsent = isMonthLoaded && !hasData && isPastDay;
    bool isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    bool isEligibleForCheckout = isPastDay && hasCheckIn && latestStatus;

    List leaves = attendanceMap[key]?['leaves'] ?? [];

    bool isHalfDay = leaves.any((l) => l['days'].toString() == '0.5');
    bool isApproved = leaves.any((l) => l['status'] == 1);
    bool hasLeave = leaves.isNotEmpty;

    if (hasLeave) {
      List leaves = attendanceMap[key]['leaves'];
      isApproved = leaves.any((l) => l['status'] == 1);
    }

    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    BoxBorder? border;

    if (isWeekend) {
      bgColor = Colors.white;
      textColor = Colors.grey;
    }
    if (isHoliday) {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
    }

    /// Check-in only
    if (isCheckInOnly) {
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    }

    /// Present (Check-in + Check-out)
    else if (hasCheckIn && hasCheckOut) {
      ///  TODAY → check shift timing
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

    if (isHoliday) {
      border = Border.all(
        color: Colors.orange,
        width: 2,
      );
    }

    if (isEligibleForCheckout) {
      bgColor = Colors.yellow.shade200;
      textColor = Colors.orange.shade900;
    }

    /// Today border
    if (isToday) {
      border = Border.all(
        color: Colors.blue,
        width: 2,
      );
    }
    if (isSelected) {
      border = Border.all(
        color: const Color(0xFF0557A2).withOpacity(0.5),
        width: 1,
      );
    }

    return Stack(
      children: [
        /// MAIN DAY CIRCLE
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.all(_s(2, scale)),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: border,
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
        ),

        ///  EXCLAMATION ICON (TOP RIGHT)
        if (isEligibleForCheckout)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: _s(10, scale),
                color: Colors.white,
              ),
            ),
          ),

        ///  LEAVE ICON
        if (hasLeave)
          Positioned(
            top: isEligibleForCheckout ? 16 : 2,
            right: 2,
            child: Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isApproved ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Text(
                isHalfDay ? "HL" : "L",
                style: TextStyle(
                  fontSize: _s(8, scale),
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showLongPressInstruction() async {
    final prefs = await SharedPreferences.getInstance();

    bool alreadyShown =
        prefs.getBool('attendance_longpress_instruction') ?? false;

    if (alreadyShown || !mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0557a2)
                        .withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    size: 30,
                    color: Color(0xFF0557a2),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Quick Leave Shortcut",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "You can now long press on attendance dates to quickly apply leave for absent or attendance days.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF0557a2),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      await prefs.setBool(
                        'attendance_longpress_instruction',
                        true,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "Got it",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildSelectedAttendance() {

    if (!_instructionChecked) {
      _instructionChecked = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLongPressInstruction();
      });
    }

    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    String key = DateFormat('yyyy-MM-dd').format(selectedDay);

    if (!attendanceMap.containsKey(key)) {
      return const SizedBox();
    }

    var data = attendanceMap[key] ?? {};

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

    bool isHoliday = data['holidaystatus'] == "Holiday";

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
          /// DATE
          dateHeader,

          SizedBox(height: _s(10, scale)),

          ///  HOLIDAY SECTION (if exists)
          if (isHoliday) ...[
            Container(
              padding: EdgeInsets.all(_s(10, scale)),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(_s(10, scale)),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.celebration,
                      color: Colors.orange, size: _s(20, scale)),
                  SizedBox(width: _s(6, scale)),
                  Text(
                    data['holidayname'] ?? "Holiday",
                    style: TextStyle(
                      fontSize: _s(14, scale),
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: _s(10, scale)),
          ],

          if (data['leaves'] != null) ...[
            ...List.generate(data['leaves'].length, (i) {
              var leave = data['leaves'][i];

              int status = leave['status'] ?? 0;
              bool isApproved = status == 1;

              DateTime today = DateTime.now();
              DateTime fromDate = DateTime.parse(leave['from_date']);
              DateTime applieDate = DateTime.parse(leave['applied_date']);

              DateTime todayDate = DateTime(today.year, today.month, today.day);
              DateTime fromDateOnly =
              DateTime(fromDate.year, fromDate.month, fromDate.day);

              bool isFutureOrToday = !fromDateOnly.isBefore(todayDate);

              bool showWithdraw =
                  (status == 0) || (status == 1 && isFutureOrToday);

              return Container(
                margin: EdgeInsets.only(bottom: _s(8, scale)),
                padding: EdgeInsets.all(_s(10, scale)),
                decoration: BoxDecoration(
                  color: getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(_s(10, scale)),
                  border: Border.all(color: getStatusColor(status).withOpacity(0.5)),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    ///  TOP ROW (MATCH LIST TAB)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// LEFT (flex 5)
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              /// Applied Date
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    formatDate(applieDate),
                                    style: TextStyle(
                                      fontSize: _s(10, scale),
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: _s(2, scale)),

                              /// Leave Type
                              Text(
                                leave['type'] ?? "",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: _s(13, scale),
                                ),
                              ),

                              SizedBox(height: _s(4, scale)),

                              Row(
                                children: [
                                  const Icon(Icons.person_outline,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      leave['reporting_to_name'] ?? "",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: _s(4, scale)),

                              /// Reason
                              if ((leave['reason'] ?? "").toString().isNotEmpty)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.notes,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: _s(4, scale)),
                                    Expanded(
                                      child: Text(
                                        leave['reason'],
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: _s(11, scale),
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        SizedBox(width: _s(8, scale)),

                        /// RIGHT (flex 4)
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [

                              /// Date Range
                              Text(
                                "${formatDate(DateTime.parse(leave['from_date']))} - ${formatDate(DateTime.parse(leave['to_date']))}",
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: _s(11, scale),
                                  color: Colors.grey.shade600,
                                ),
                              ),

                              SizedBox(height: _s(4, scale)),

                              /// Days
                              Text(
                                "${leave['days']} days",
                                style: TextStyle(
                                  fontSize: _s(11, scale),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              SizedBox(height: _s(6, scale)),

                              /// Status + Withdraw
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [

                                  /// STATUS
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: _s(8, scale),
                                      vertical: _s(2, scale),
                                    ),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      getStatusText(status),
                                      style: TextStyle(
                                        fontSize: _s(10, scale),
                                        fontWeight: FontWeight.w600,
                                        color: getStatusColor(status),
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: _s(6, scale)),

                                  /// ONLY WITHDRAW (NO EDIT)
                                  if (showWithdraw)
                                    GestureDetector(
                                      onTap: () {
                                        withdrawLeave(
                                            leave['leave_id'].toString());
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: _s(8, scale),
                                          vertical: _s(2, scale),
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border:
                                          Border.all(color: Colors.orange),
                                          color: Colors.orange.withOpacity(0.1),
                                        ),
                                        child: const Icon(
                                          Icons.outbound,
                                          size: 14,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: _s(10, scale)),
          ],
          ///  ATTENDANCE ALWAYS SHOW (if data exists)
          if (data['checkin'] != null)
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

  String formatDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Color getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      case 3:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String getStatusText(int status) {
    switch (status) {
      case 1:
        return "Approved";
      case 2:
        return "Rejected";
      case 3:
        return "Withdrawn";
      default:
        return "Pending";
    }
  }

  Future<void> withdrawLeave(String leaveId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm"),
        content: const Text("Are you sure you want to withdraw this leave?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => isWithdrawing = true);
      final prefs = await SharedPreferences.getInstance();

      String apiKey = prefs.getString('apiKey') ?? "";
      String companyDb = prefs.getString('companyDb') ?? "";

      final response = await http.post(
        Uri.parse(
            "https://hrms.attendify.ai/index.php/Setting/leave_withdrawn_web"),
        headers: {
          "apiKey": apiKey,
          "companyDb": companyDb,
        },
        body: {
          "id": leaveId,
        },
      );

      final res = jsonDecode(response.body);

      if (res['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leave withdrawn successfully")),
        );

        DateTime now = DateTime.now();
        await _loadUserData();
        await loadAttendanceForMonth(
          now.year,
          now.month,
          forceRefresh: true,
        );

        setState(() {
          selectedDay = now;
          focusedDay = now;
          showAttendanceCard = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? "Failed to withdraw")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    } finally {
      setState(() => isWithdrawing = false);
    }
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
          (image != null && image != "")
              ? GestureDetector(
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
                )
              : _imagePlaceholder(scale * 1.3),
        ],
      ),
    );
  }

  void showImage(String image) {
    String url = "https://hrms.attendify.ai/detectedImages/$image";

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: true, //  click outside to close
      builder: (_) {
        final size = MediaQuery.of(context).size;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 40,
          ), //  space around dialog
          child: Stack(
            children: [
              /// Image Container
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  // child: Image.network(url, fit: BoxFit.contain),
                  child: Container(
                    width: size.width * 0.95, //  slightly reduced
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
                      color: Colors.white, //  white background
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
        mainAxisAlignment: MainAxisAlignment.center,
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

  Widget buildRoadMapCard() {
    String key = DateFormat('yyyy-MM-dd').format(selectedDay);

    if (!attendanceMap.containsKey(key)) {
      return const SizedBox();
    }

    final timeline = buildRoadMapTimeline();
    if (timeline.isEmpty) return const SizedBox();

    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    return Container(
      margin: EdgeInsets.symmetric(
        // horizontal: _s(3, scale),
        vertical: _s(8, scale),
      ),
      padding: EdgeInsets.all(_s(10, scale)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_s(16, scale)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: _s(10, scale),
          )
        ],
      ),
      child: Column(
        children: [
          /// HEADER
          Center(
            child: Text(
              "Day Log",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: _s(15, scale),
              ),
            ),
          ),

          SizedBox(height: _s(12, scale)),

          Row(
            children: [
              Expanded(child: _topBox("Duration", totalDuration, scale)),
              Expanded(
                  child: _topBox("Working", totalWork, scale,
                      color: Colors.green)),
              Expanded(
                  child:
                      _topBox("Break", totalBreak, scale, color: Colors.red)),
            ],
          ),

          const SizedBox(height: 8),
          Divider(),

          Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: animationController,
                  builder: (_, __) {
                    return CustomPaint(
                      painter: RoadMapPainter(
                        timeline,
                        animationController.value,
                        scale,
                      ),
                    );
                  },
                ),
              ),
              Column(
                children: List.generate(
                  timeline.length,
                  (i) => Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: _s(25, scale)), //  SPACE
                    child: _nodeItem(timeline[i], scale),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  /// TOP BOX
  Widget _topBox(String title, String value, double scale, {Color? color}) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(color: Colors.grey, fontSize: _s(11, scale))),
        SizedBox(height: _s(4, scale)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _s(15, scale),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _nodeItem(Map item, double scale) {
    bool isCheckIn = item['event'] == 'checkin';
    bool isLive = item['isLive'] == true;
    bool isMobile = item['capture'] == 'mobile';
    double centerGap = _s(140, scale);
    Color color = (isCheckIn ? Colors.green : Colors.red);

    return SizedBox(
      height: _s(100, scale),
      child: Row(
        children: [
          /// LEFT SIDE
          Expanded(
            child: isMobile
                ? const SizedBox()
                : Align(
                    alignment: Alignment.centerRight,
                    child: _buildNodeContent(
                        item, scale, color, isCheckIn, isLive),
                  ),
          ),

          SizedBox(width: centerGap),

          /// RIGHT SIDE
          Expanded(
            child: !isMobile
                ? const SizedBox()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _buildNodeContent(
                        item, scale, color, isCheckIn, isLive),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getLightColor(Color color) {
    if (color == Colors.green) return Colors.green.shade200;
    if (color == Colors.red) return Colors.red.shade200;
    if (color == Colors.orange) return Colors.orange.shade200;
    if (color == Colors.blue) return Colors.blue.shade200;

    return color.withValues(alpha: 0.1); // fallback
  }

  Widget _buildNodeContent(
    Map item,
    double scale,
    Color color,
    bool isCheckIn,
    bool isLive,
  ) {
    bool isMobile = item['capture'] == 'mobile';
    String capture = item['capture'] ?? "";

    String startImagethumb = item['start_image_thumb'] ?? "";
    String endImagethumb = item['end_image_thumb'] ?? "";
    String liveImagethumb = item['start_image_thumb'] ?? "";

    String startImage = item['start_image'] ?? "";
    String endImage = item['end_image'] ?? "";
    String liveImage = item['last_image'] ?? "";

    ///  PICK IMAGE
    String imageUrlthumb =
        isLive ? liveImagethumb : (isCheckIn ? startImagethumb : endImagethumb);

    String imageUrl = isLive ? liveImage : (isCheckIn ? startImage : endImage);

    String fullImageUrlthumb = imageUrlthumb.isNotEmpty
        ? "https://hrms.attendify.ai/detectedImages/$imageUrlthumb"
        : "";

    String fullImageUrl = imageUrl;

    ///  APPLY BLINK ONLY FOR LIVE
    return _buildCardUI(
      item,
      scale,
      color,
      isCheckIn,
      isLive,
      isMobile,
      capture,
      fullImageUrl,
      fullImageUrlthumb,
      blinkController,
    );
  }

  IconData getCaptureIcon(String capture) {
    switch (capture) {
      case 'mobile':
        return Icons.location_on;
      case 'camera':
        return Icons.camera_alt;
      case 'cronjob':
        return Icons.schedule;
      case 'marked':
        return Icons.edit;
      default:
        return Icons.device_unknown;
    }
  }

  Color getCaptureColor(String capture) {
    switch (capture) {
      case 'mobile':
        return Colors.orange;
      case 'camera':
        return Colors.blue;
      case 'cronjob':
        return Colors.purple;
      case 'marked':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCardUI(
    Map item,
    double scale,
    Color color,
    bool isCheckIn,
    bool isLive,
    bool isMobile,
    String capture,
    String fullImageUrl,
    String fullImageUrlthumb,
    AnimationController? blinkController,
  ) {
    IconData getCaptureIcon(String capture) {
      switch (capture) {
        case 'mobile':
          return Icons.location_on;
        case 'camera':
          return Icons.camera_alt;
        case 'cronjob':
          return Icons.schedule;
        case 'marked':
          return Icons.edit;
        default:
          return Icons.device_unknown;
      }
    }

    Color getCaptureColor(String capture) {
      switch (capture) {
        case 'mobile':
          return Colors.orange;
        case 'camera':
          return Colors.blue;
        case 'cronjob':
          return Colors.purple;
        case 'marked':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    print('fullImageUrl $fullImageUrl');
    return AnimatedBuilder(
      animation: blinkController ?? animationController,
      builder: (context, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_s(8, scale)),
            onTap: (fullImageUrl.isNotEmpty)
                ? () => showImage(fullImageUrl)
                : null,
            child: Container(
              padding: EdgeInsets.all(_s(3, scale)),
              decoration: BoxDecoration(
                color: _getLightColor(color),
                borderRadius: BorderRadius.circular(_s(8, scale)),
                boxShadow: [
                  if (isLive)
                    BoxShadow(
                      color: Colors.green.withOpacity(
                        0.2 + (blinkController!.value * 0.4),
                      ),
                      blurRadius: 4 + (blinkController.value * 10),
                      spreadRadius: 1 + (blinkController.value * 3),
                    ),
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: _s(5, scale),
                    offset: Offset(0, _s(3, scale)),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(_s(2, scale)),
                            child: fullImageUrlthumb.isNotEmpty
                                ? Image.network(
                                    fullImageUrlthumb,
                                    height: _s(75, scale),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imagePlaceholder(scale),
                                  )
                                : _imagePlaceholder(scale),
                          ),
                          SizedBox(height: _s(3, scale)),
                          Center(
                            child: Text(
                              item['time'] ?? "--",
                              style: TextStyle(
                                fontSize: _s(11, scale),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          )
                        ],
                      ),

                      /// Capture badge
                      if (capture.isNotEmpty)
                        Positioned(
                          bottom: -1,
                          right: 2,
                          child: Container(
                            padding: EdgeInsets.all(_s(2, scale)),
                            decoration: BoxDecoration(
                              color: getCaptureColor(capture),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Icon(
                              getCaptureIcon(capture),
                              size: _s(10, scale),
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _imagePlaceholder(double scale) {
    return Container(
      height: _s(75, scale),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(_s(8, scale)),
      ),
      child: Icon(
        Icons.person,
        size: _s(20, scale),
        color: Colors.grey,
      ),
    );
  }

// end
}

class RoadMapPainter extends CustomPainter {
  final List timeline;
  final double progress;
  final double scale;

  RoadMapPainter(this.timeline, this.progress, this.scale);

  double _s(double v) => v * scale;

  @override
  void paint(Canvas canvas, Size size) {
    double centerX = size.width / 2;
    double centerGap = _s(280);

    double leftX = centerX - (centerGap / 2);
    double rightX = centerX + (centerGap / 2);

    double rowHeight = _s(150);

    for (int i = 0; i < timeline.length - 1; i++) {
      var current = timeline[i];
      var next = timeline[i + 1];

      bool currentRight = current['capture'] == 'mobile';
      bool nextRight = next['capture'] == 'mobile';

      double startX = currentRight ? rightX : leftX;
      double endX = nextRight ? rightX : leftX;

      double startY = i * rowHeight + rowHeight / 2;
      double endY = (i + 1) * rowHeight + rowHeight / 2;

      double midY = (startY + endY) / 2;

      bool isWork = current['event'] == 'checkin';

      Paint paint = Paint()
        ..strokeWidth = _s(4)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..color = isWork ? Colors.green : Colors.red;

      ///  BUILD PATH
      Path path = Path();
      path.moveTo(startX, startY);

      if (startX == endX) {
        /// STRAIGHT LINE
        path.lineTo(startX, endY);
      } else {
        /// CURVED Z PATH
        double curve = _s(12);

        path.lineTo(startX, midY - curve);

        path.quadraticBezierTo(
          startX,
          midY,
          startX + (endX > startX ? curve : -curve),
          midY,
        );

        path.lineTo(endX - (endX > startX ? curve : -curve), midY);

        path.quadraticBezierTo(
          endX,
          midY,
          endX,
          midY + curve,
        );

        path.lineTo(endX, endY);
      }

      ///  DRAW LINE (ONLY ONCE)
      canvas.drawPath(path, paint);

      ///  DRAW DURATION BADGE (ON TOP)
      if (current['duration'] != null &&
          current['duration'].toString().isNotEmpty) {
        double badgeX = (startX == endX) ? startX : (startX + endX) / 2;

        String text = current['duration'];

        TextPainter tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.white,
              fontSize: _s(10),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();

        double paddingH = _s(12);
        double paddingV = _s(6);

        Rect rect = Rect.fromCenter(
          center: Offset(badgeX, midY - _s(1)), // slight lift
          width: tp.width + paddingH,
          height: tp.height + paddingV,
        );

        Paint badgePaint = Paint()..color = isWork ? Colors.green : Colors.red;

        /// SHADOW (PREMIUM LOOK)
        canvas.drawShadow(
          Path()
            ..addRRect(
              RRect.fromRectAndRadius(
                rect,
                Radius.circular(_s(20)),
              ),
            ),
          Colors.black26,
          _s(3),
          false,
        );

        /// BADGE BG
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(_s(20)),
          ),
          badgePaint,
        );

        /// TEXT
        tp.paint(
          canvas,
          Offset(
            rect.left + (rect.width - tp.width) / 2,
            rect.top + (rect.height - tp.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

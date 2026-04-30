import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'SelfAttendanceCamera.dart';

class AttendanceCal extends StatefulWidget {
  const AttendanceCal({super.key});

  @override
  _AttendanceCalState createState() => _AttendanceCalState();
}

class _AttendanceCalState extends State<AttendanceCal> {
  final GlobalKey<SelfAttendanceCameraState> _cameraKey = GlobalKey();
  String attendanceStatus = "checkin";
  String currentStatus = "checkin";
  String _userId = "";
  String _currentDay = '';

  Map<String, dynamic> attendanceMap = {};
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();
  bool showAttendanceCard = true;
  bool isLoading = false;

  List<dynamic> breakTimeline = [];
  bool isBreakLoading = false;
  String totalWork = "";
  String totalDuration = "";
  String totalBreak = "";
  String loadedMonthKey = "";
  String? errorText;
  bool isWithdrawing = false;
  String _getCacheKey(int year, int month) {
    return "attendance_${year}_$month";
  }
  String _getHolidayKey(int year, int month) {
    return "holiday_${year}_$month";
  }

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
    String holidayKey = _getHolidayKey(year, month);

    final now = DateTime.now();
    final isCurrentMonth = (year == now.year && month == now.month);

    bool shouldUseCache =
        !forceRefresh && box.containsKey(cacheKey) && !isCurrentMonth;

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
      appBar: AppBar(
        title: Text(
          'Attendance Calendar',
          style: TextStyle(
            color: Colors.white,
            fontSize: _s(20, scale),
          ),
        ),
        backgroundColor: const Color(0xFF0557a2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          DateTime now = DateTime.now();

          await _loadUserData();

          await loadAttendanceForMonth(
            now.year,
            now.month,
          );

          setState(() {
            ///  Reset calendar to today
            selectedDay = now;
            focusedDay = now;

            ///  Show updated card
            showAttendanceCard = false;
          });
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          children: [
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
                  // if (selectedDate.isAfter(todayDate) &&
                  //     !isHoliday &&
                  //     !isApprovedLeave) {
                  //
                  //   Navigator.push(
                  //     context,
                  //     MaterialPageRoute(
                  //       builder: (_) => ApplyLeavePage(
                  //         selectedDate: selectedDate,
                  //         leaveId: leaveId,   //  PASS HERE
                  //       ),
                  //     ),
                  //   );
                  //   return;
                  // }

                  /// 👉 CHECKOUT LOGIC
                  bool latestStatus = hasData &&
                      attendanceMap[key]['lateststatus'] == "checkin";

                  bool hasCheckIn = hasData &&
                      (attendanceMap[key]['checkin'] != null &&
                          attendanceMap[key]['checkin'] != "");

                  bool hasCheckOut = hasData &&
                      (attendanceMap[key]['checkout'] != null &&
                          attendanceMap[key]['checkout'] != "");

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

                  await loadBreakHistory(key);
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
            const SizedBox(height: 12),
            if (showAttendanceCard) ...[
              buildSelectedAttendance(),
              buildBreakTable(),
            ],

            const SizedBox(height: 12),
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
    String formateddate = _formatTime(date);
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


  Widget buildSelectedAttendance() {
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


  Widget buildBreakTable() {
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);
    String key = DateFormat('yyyy-MM-dd').format(selectedDay);

    if (!attendanceMap.containsKey(key) || breakTimeline.isEmpty) {
      return const SizedBox();
    }

    if (isBreakLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 650;
    double colWidth = isWide ? 100 : 110;

    TextStyle timeStyle = TextStyle(
      fontSize: _s(12, scale),
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    );

    TextStyle subTimeStyle = TextStyle(
      fontSize: _s(11, scale),
      color: Colors.grey.shade600,
    );

    TextStyle labelStyle = TextStyle(
      fontSize: _s(10, scale),
      fontWeight: FontWeight.w500,
      color: Colors.grey,
    );

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 15),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [


          Row(
            children: [
              // Expanded(child: _topBox("Duration", totalDuration, scale)),
              Expanded(child: _topBox("Working", totalWork, scale, color: Colors.green)),
              Expanded(child: _topBox("Break", totalBreak, scale, color: Colors.red)),
            ],
          ),

          const SizedBox(height: 8),
          Divider(),

          /// TABLE
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [

                /// HEADER ROW
                Row(
                  children: [
                    // _cell("Sl.No", _s(60, scale), isHeader: true),
                    _cell("From", _s(colWidth, scale), isHeader: true),
                    _cell("To", _s(colWidth, scale), isHeader: true),
                    // _cell("Duration", _s(colWidth, scale), isHeader: true),
                    _cell("Working", _s(colWidth, scale), isHeader: true),
                    _cell("Break", _s(colWidth, scale), isHeader: true),
                  ],
                ),

                /// ROWS
                ...breakTimeline.asMap().entries.map((entry) {
                  int index = entry.key;
                  var row = entry.value;

                  bool isWork = row['type'] == 'work';
                  bool isBreak = row['type'] == 'break';
                  bool isStatus = row['type'] == 'status';

                  return Container(
                    color: isBreak
                        ? Colors.orange.shade50
                        : isStatus
                        ? Colors.blue.shade50
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        /// FROM
                        SizedBox(
                          width: _s(colWidth, scale),
                          child: Center(
                            child: isWork
                                ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(row['from_time'] ?? "-" , style: timeStyle),
                              ],
                            )
                                : isStatus
                                ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 8, color: Colors.green),
                                    SizedBox(width: 5),
                                    Text("IN"),
                                  ],
                                ),
                                Text(row['start_time_text'] ?? "-" , style: timeStyle),
                              ],
                            )
                                : Text(row['from_time'] ?? "-" , style: timeStyle),
                          ),
                        ),

                        /// TO
                        SizedBox(
                          width: _s(colWidth, scale),
                          child: Center(
                            child: isWork
                                ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(row['to_time'] ?? "-",style: timeStyle),
                              ],
                            )
                                : isStatus
                                ? Text("-")
                                : Text(row['to_time'] ?? "-",style: timeStyle),
                          ),
                        ),

                        /// WORK
                        SizedBox(
                          width: _s(colWidth + 10, scale),
                          child: Center(
                            child: isWork
                                ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                row['duration_text'] ?? "-",
                                style: TextStyle(
                                  fontSize: _s(11, scale),
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                                :isStatus ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text("Live" , style: TextStyle(
                                fontSize: _s(11, scale),
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade800,
                              ),),
                            ) :
                            const Text("-"),
                          ),
                        ),

                        /// BREAK
                        SizedBox(
                          width: _s(colWidth, scale),
                          child: Center(
                            child: isBreak
                                ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                row['duration_text'] ?? "-",
                                style: TextStyle(
                                  fontSize: _s(11, scale),
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade900,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                                : const Text("-"),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// HEADER + CELL
  Widget _cell(String text, double width, {bool isHeader = false}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: isHeader
              ? const TextStyle(fontWeight: FontWeight.bold)
              : null,
        ),
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

}

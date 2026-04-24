import 'dart:convert';
import 'dart:ui' as ui;
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class HrAttendanceCal extends StatefulWidget {
  final String employeeCode;

  const HrAttendanceCal({
    super.key,
    required this.employeeCode,
  });

  @override
  _HrAttendanceCalState createState() => _HrAttendanceCalState();
}

class _HrAttendanceCalState extends State<HrAttendanceCal>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  String attendanceStatus = "checkin";
  String currentStatus = "checkin";
  String _userId = "";
  String _userCode = "";
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
  late PageController _pageController;
  int currentPage = 0;

  String empName = "";
  String empDept = "";
  String empImage = "";
  String? errorText;

  String _getCacheKey(int year, int month, String userId) {
    return "attendance_${userId}_${year}_$month";
  }

  String _getHolidayKey(int year, int month, String userId) {
    return "holiday_${userId}_${year}_$month";
  }

  late AnimationController animationController;
  late AnimationController blinkController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentDay = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadUserData();
    loadAttendanceForMonth(
      DateTime.now().year,
      DateTime.now().month,
    );

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    animationController.dispose();
    blinkController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HrAttendanceCal oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.employeeCode != widget.employeeCode) {
      _reloadEmployee();
    }
  }

  Future<void> _reloadEmployee() async {
    setState(() {
      isLoading = true;
      attendanceMap.clear();
      breakTimeline.clear();
      empName = "";
      empDept = "";
      empImage = "";
    });

    await _loadUserData();

    DateTime now = DateTime.now();

    await loadAttendanceForMonth(
      now.year,
      now.month,
      forceRefresh: false,
    );

    setState(() {
      selectedDay = now;
      focusedDay = now;
      showAttendanceCard = true;
      isLoading = false;
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      _userId = widget.employeeCode;
      _userCode = widget.employeeCode;
    });

    await _loadAttendanceData(
      _userId,
      DateTime.now().year.toString(),
      DateTime.now().month.toString(),
    );
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

    String userId = _userCode;
    String companyDb = prefs.getString('companyDb') ?? "";
    String deptId = prefs.getString('department') ?? "0";
    String cid = prefs.getString('cid') ?? "0";

    String cacheKey = _getCacheKey(year, month, userId);
    String holidayKey = _getHolidayKey(year, month, userId);

    final now = DateTime.now();
    final isCurrentMonth = (year == now.year && month == now.month);

    bool shouldUseCache = !forceRefresh &&
        box.containsKey(cacheKey) &&
        !isCurrentMonth;

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
        "https://hrms.attendify.ai/index.php/MobileApi/get_empattendacedata?company_db=$companyDb&userid=$userId&year=$year&month=$month";

    String holidayUrl =
        "https://hrms.attendify.ai/index.php/MobileApi/get_daysholiday?company_db=$companyDb&cid=$cid&year=$year&month=$month&deptID=$deptId";

    try {
      final response = await http.get(Uri.parse(url));
      final holidayResponse = await http.get(Uri.parse(holidayUrl));

      Map<String, dynamic> temp = {};

      /// 🔥 ATTENDANCE
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final info = data['info']; // ✅ ADD THIS

        if (info != null) {
          String first = info['first_name'] ?? "";
          String last = info['last_name'] ?? "";

          if (last == "null") last = "";

          String profile = info['user_profile'] ?? "";

          setState(() {
            empName = "$first $last".trim();
            empDept = info['departmentname'] ?? "";
            empImage = profile.isNotEmpty
                ? "https://hrms.attendify.ai/photos/$profile"
                : "";
          });
        }

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

      /// 🔥 HOLIDAYS
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

      /// ✅ SAVE TO CACHE
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
    // String empCode = widget.employeeCode;
    String empCode = _userCode;

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
    super.build(context);
    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Attendance - $empName",
          style: TextStyle(
            color: Colors.white,
            fontSize: _s(20, scale),
          ),
          maxLines: 1, // allow wrap
          overflow: TextOverflow.visible,
          softWrap: true,
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

                  bool isHoliday =
                      attendanceMap.containsKey(key) &&
                          attendanceMap[key]['holidaystatus'] == "Holiday";

                  /// Block future dates only if NOT holiday
                  if (selectedDate.isAfter(todayDate) && !isHoliday) {
                    return;
                  }

                  /// 🔥 ADD THIS BLOCK (NEW LOGIC)
                  bool hasData = attendanceMap.containsKey(key);


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

                  /// 👉 OPEN MODAL ONLY (don’t stop normal flow)
                  if (isEligibleForCheckout) {
                    errorText = null;
                    _openCheckoutModal(key);
                  }

                  /// ✅ KEEP YOUR ORIGINAL FLOW
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
                  ); // ✅ uses cache
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
              const SizedBox(height: 12),
              _buildTabHeader(),
              const SizedBox(height: 8),
              IndexedStack(
                index: currentPage,
                children: [
                  buildBreakTable(),
                  buildRoadMapCard(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildTabHeader() {
    String key = DateFormat('yyyy-MM-dd').format(selectedDay);
    if (!attendanceMap.containsKey(key) || breakTimeline.isEmpty) {
      return const SizedBox();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _tabItem("Day Log", 0),
        const SizedBox(width: 20),
        _tabItem("Day Flow", 1),

      ],
    );
  }

  Widget _tabItem(String title, int index) {
    bool isActive = currentPage == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          currentPage = index;
        });
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.blue : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 2,
            width: isActive ? 40 : 0,
            color: Colors.blue,
          )
        ],
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
          backgroundColor: Colors.white, // ✅ white bg
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
    String userId = _userCode ;
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

      /// 🔥 DELETE OLD CACHE
      await box.delete(cacheKey);

      /// 🔥 RELOAD THAT MONTH
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
      await loadBreakHistory(key);
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
    bool isHoliday = hasData && attendanceMap[key]['holidaystatus'] == "Holiday";
    bool latestStatus = hasData &&
        attendanceMap[key]['lateststatus'] == "checkin";

    bool hasCheckIn = hasData && (attendanceMap[key]['checkin'] != null && attendanceMap[key]['checkin'] != "");
    bool hasCheckOut = hasData && (attendanceMap[key]['checkout'] != null && attendanceMap[key]['checkout'] != "");
    bool isCheckInOnly = hasCheckIn && !hasCheckOut;
    bool isPastDay = date.isBefore(DateTime(today.year, today.month, today.day));
    bool isAbsent = isMonthLoaded && !hasData && isPastDay;
    bool isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    bool isEligibleForCheckout =
        isPastDay &&
            hasCheckIn &&
            latestStatus;

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
      ],
    );
  }


  Widget buildSelectedAttendance() {
    final scale = _calcScaleFromWidth(MediaQuery
        .of(context)
        .size
        .width);

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

          /// 🔶 HOLIDAY SECTION (if exists)
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

          /// ✅ ATTENDANCE ALWAYS SHOW (if data exists)
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
            ) : _imagePlaceholder(scale * 1.3),
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
    double colWidth = isWide ? 100 : 100;

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

          /// HEADER
          // Center(
          //   child: Text(
          //     "Day Log",
          //     style: TextStyle(
          //       fontWeight: FontWeight.bold,
          //       fontSize: _s(15, scale),
          //     ),
          //   ),
          // ),
          //
          // SizedBox(height: _s(12, scale)),

          Row(
            children: [
              Expanded(child: _topBox("Duration", totalDuration, scale)),
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
                    _cell("Duration", _s(colWidth, scale), isHeader: true),
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

                        // _cell("${index + 1}", _s(60, scale)),
                        // _cell("${index + 1}", _s(60, scale)),

                        /// FROM
                        SizedBox(
                          width: _s(colWidth, scale),
                          child: Center(
                            child: isWork
                                ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(row['from_time'] ?? "-"),
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
                                Text(row['start_time_text'] ?? "-"),
                              ],
                            )
                                : Text(row['from_time'] ?? "-"),
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
                                Text(row['to_time'] ?? "-"),
                              ],
                            )
                                : isStatus
                                ? Text("-")
                                : Text(row['to_time'] ?? "-"),
                          ),
                        ),

                        SizedBox(
                          width: _s(colWidth, scale),
                          child: Center(
                            child: isStatus ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text("Live"),
                            ) : Text(
                              row['duration_text'] ?? "-",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        /// WORK
                        SizedBox(
                          width: _s(colWidth, scale),
                          child: Center(
                            child: isWork
                                ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(row['duration_text'] ?? "-"),
                            )
                                :const Text("-"),
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
                              child: Text(row['duration_text'] ?? "-"),
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

  List<Map<String, dynamic>> buildRoadMapTimeline() {
    List<Map<String, dynamic>> finalList = [];
    int? lastWorkEndIndex;
    for (var item in breakTimeline) {
      /// ✅ WORK ONLY
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

  Widget buildRoadMapCard() {
    String key = DateFormat('yyyy-MM-dd').format(selectedDay);

    // ✅ SAME CONDITION AS TABLE
    if (!attendanceMap.containsKey(key) || breakTimeline.isEmpty) {
      return const SizedBox();
    }

    final timeline = buildRoadMapTimeline();
    if (timeline.isEmpty) return const SizedBox();

    final scale = _calcScaleFromWidth(MediaQuery.of(context).size.width);

    return Container(
      margin: EdgeInsets.symmetric(vertical: _s(8, scale)),
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

          Row(
            children: [
              Expanded(child: _topBox("Duration", totalDuration, scale)),
              Expanded(child: _topBox("Working", totalWork, scale, color: Colors.green)),
              Expanded(child: _topBox("Break", totalBreak, scale, color: Colors.red)),
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
                    padding: EdgeInsets.symmetric(vertical: _s(25, scale)),
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

    /// 🔥 PICK IMAGE
    String imageUrlthumb =
    isLive ? liveImagethumb : (isCheckIn ? startImagethumb : endImagethumb);

    String imageUrl = isLive ? liveImage : (isCheckIn ? startImage : endImage);

    String fullImageUrlthumb = imageUrlthumb.isNotEmpty
        ? "https://hrms.attendify.ai/detectedImages/$imageUrlthumb"
        : "";

    String fullImageUrl = imageUrl;

    /// 🔥 APPLY BLINK ONLY FOR LIVE
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

  Color _getLightColor(Color color) {
    if (color == Colors.green) return Colors.green.shade200;
    if (color == Colors.red) return Colors.red.shade200;
    if (color == Colors.orange) return Colors.orange.shade200;
    if (color == Colors.blue) return Colors.blue.shade200;

    return color.withValues(alpha: 0.1); // fallback
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
            onTap: (fullImageUrl != null && fullImageUrl.isNotEmpty)
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

      /// 🔥 BUILD PATH
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

      /// ✅ DRAW LINE (ONLY ONCE)
      canvas.drawPath(path, paint);

      /// 🔥 DRAW DURATION BADGE (ON TOP)
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

class SizeReportingWidget extends StatefulWidget {
  final Widget child;
  final Function(Size size) onSizeChange;

  const SizeReportingWidget({
    super.key,
    required this.child,
    required this.onSizeChange,
  });

  @override
  State<SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<SizeReportingWidget> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _key.currentContext;
      if (context != null) {
        final size = context.size;
        if (size != null) {
          widget.onSizeChange(size);
        }
      }
    });

    return Container(
      key: _key,
      child: widget.child,
    );
  }
}
// ===================================================================================


class EmployeeSwipeScreen extends StatefulWidget {
  final List<String> employeeList;
  final int initialIndex;

  const EmployeeSwipeScreen({
    super.key,
    required this.employeeList,
    this.initialIndex = 0,
  });

  @override
  State<EmployeeSwipeScreen> createState() => _EmployeeSwipeScreenState();
}

class _EmployeeSwipeScreenState extends State<EmployeeSwipeScreen> {
  late PageController _pageController;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _preload(int index) {
    if (index < 0 || index >= widget.employeeList.length) return;

    // optional: you can trigger cache preload here if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.employeeList.length,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => currentIndex = index);

          _preload(index + 1);
          _preload(index - 1);
        },
        itemBuilder: (context, index) {
          return HrAttendanceCal(
            employeeCode: widget.employeeList[index],
          );
        },
      ),
    );
  }
}
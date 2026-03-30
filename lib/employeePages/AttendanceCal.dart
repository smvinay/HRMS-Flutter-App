import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceCal extends StatefulWidget {
  @override
  _AttendanceCalState createState() => _AttendanceCalState();
}

class _AttendanceCalState extends State<AttendanceCal> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _userId = "";
  String _companyDb = "";
  String _deptid = "";
  String _cid = "";

  Map<DateTime, Map<String, dynamic>> _attendanceData = {};
  // Map<DateTime, Map<String, dynamic>> _attendanceData

  bool _isLoading = false;

  final Map<String, Color> _statusColors = {
    'Present': const Color.fromARGB(255, 110, 209, 115),
    'Absent': Colors.red.shade300,
    'In': Colors.blue.shade300,
    'Holiday': Colors.orange.shade300,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEmployeeDataForMonth(_focusedDay.year, _focusedDay.month);
  }

Future<void> _fetchEmployeeDataForMonth(int year, int month) async {
  final prefs = await SharedPreferences.getInstance();

  setState(() {
    _userId = prefs.getString('employe_code') ?? "";
    _companyDb = prefs.getString('companyDb') ?? "";
    _deptid = prefs.getString('department') ?? "0";
    _cid = prefs.getString('cid') ?? "0";
    _isLoading = true;
  });

  final String cacheKey = 'attendance_${month.toString().padLeft(2, '0')}-$year';
  DateTime now = DateTime.now();
  DateTime requestedMonth = DateTime(year, month);
  DateTime currentMonth = DateTime(now.year, now.month);

  /// Use cache only for past months
  bool isPastMonth =
      requestedMonth.year < currentMonth.year ||
          (requestedMonth.year == currentMonth.year &&
              requestedMonth.month < currentMonth.month);

  if (isPastMonth && prefs.containsKey(cacheKey)) {
    final cachedData = prefs.getString(cacheKey);
    if (cachedData != null) {
      final Map<String, dynamic> decoded = json.decode(cachedData);
      Map<DateTime, Map<String, dynamic>> loadedData = {};

      decoded.forEach((key, value) {
        loadedData[DateTime.parse(key)] = Map<String, dynamic>.from(value);
      });

      setState(() {
        _attendanceData = loadedData;
        _isLoading = false;
      });

      return; // Skip API call
    }
  }

  // API URLs
  String url =
      "https://hrms.attendify.ai/index.php/MobileApi/get_empattendacedata?company_db=$_companyDb&userid=$_userId&year=$year&month=$month";
  String url2 =
      "https://hrms.attendify.ai/index.php/MobileApi/get_daysholiday?company_db=$_companyDb&cid=$_cid&year=$year&month=$month&deptID=$_deptid";

  try {
    final response = await http.get(Uri.parse(url));
    final holidayResponse = await http.get(Uri.parse(url2));

    if (response.statusCode == 200 && holidayResponse.statusCode == 200) {
      final data = json.decode(response.body);
      final holidayData = json.decode(holidayResponse.body);



      Map<DateTime, Map<String, dynamic>> updatedData = {};
      Set<DateTime> fetchedDates = {};
      Set<DateTime> holidayDates = {};

      // Handle Holidays
      if (holidayData['data'] != null) {
        for (var holiday in holidayData['data']) {
          DateTime holidayDate = DateTime.parse(holiday['date']);
          holidayDate = DateTime(holidayDate.year, holidayDate.month, holidayDate.day);
          holidayDates.add(holidayDate);

          updatedData[holidayDate] = {
            'status': 'Holiday',
            'checkinImage': null,
            'checkoutImage': null,
            'first_check_in': null,
            'last_check_in': null,
            'holidayname': holiday['name'],
          };
        }
      }

      print(updatedData);

      int daysInMonth = DateTime(year, month + 1, 0).day;

      // Handle Attendance
      if (data['data'] != null) {
        for (var entry in data['data']) {
          if (entry['attendance_date'] != null && entry['attendance_date'].toString().isNotEmpty) {
            DateTime fullDate = DateTime.parse(entry['attendance_date']);
            DateTime date = DateTime(fullDate.year, fullDate.month, fullDate.day);
            fetchedDates.add(date);

            String status;
            if ((entry['first_check_in'] != null && entry['first_check_in'].toString().isNotEmpty) &&
                (entry['last_check_in'] != null && entry['last_check_in'].toString().isNotEmpty)) {
              status = "Present";
            } else if ((entry['first_check_in'] == null || entry['first_check_in'].toString().isEmpty) &&
                (entry['last_check_in'] == null || entry['last_check_in'].toString().isEmpty)) {
              status = "Absent";
            } else {
              status = "In";
            }

            updatedData[date] = {
              'status': status,
              'checkinImage': entry['fullfirst_detected_face'] ?? null,
              'checkoutImage': entry['fulllast_detected_face'] ?? null,
              'first_check_in': entry['first_check_in'] ?? '',
              'last_check_in': entry['last_check_in'] ?? '',
              'holidayname': null,
            };
          }
        }
      }

      // Fill Absent for remaining past days (excluding holidays & already fetched)
      for (int i = 1; i <= daysInMonth; i++) {
        DateTime day = DateTime(year, month, i);
        bool isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
        bool isPastOrToday = day.isBefore(now) || (day.day == now.day && day.month == now.month && day.year == now.year);

        if (isPastOrToday && !isWeekend && !fetchedDates.contains(day)) {
          updatedData[day] = {
            'status': 'Absent',
            'checkinImage': null,
            'checkoutImage': null,
            'first_check_in': null,
            'last_check_in': null,
            'holidayname': null,
          };
        }
      }

      setState(() {
        _attendanceData = updatedData;
        _isLoading = false;
      });

      // Store in cache if past month
      if (requestedMonth.isBefore(currentMonth)) {
        Map<String, dynamic> encodedData = {};
        updatedData.forEach((key, value) {
          encodedData[key.toIso8601String()] = value;
        });
        prefs.setString(cacheKey, json.encode(encodedData));
      }

    } else {
      setState(() {
        _isLoading = false;
      });
    }
  } catch (e) {
    print("Error fetching data: $e");
    setState(() {
      _isLoading = false;
    });
  }
}

  double _calcScaleFromWidth(double w) {
    const base = 475.0;
    final raw = (w / base);
    return raw.clamp(0.7, 1.2);
  }

  double _s(double size, double scale) {
    return size * scale;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final scale = _calcScaleFromWidth(screenWidth);

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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              _buildCalendarCard(scale),
              SizedBox(height: _s(5, scale)),
              _buildColorLegend(scale),
              SizedBox(height: _s(8, scale)),
              _buildImageSection(screenWidth, scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard(double scale) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Card(
        color: Colors.white,
        key: ValueKey(_focusedDay),
        elevation: _s(4, scale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_s(12, scale)),
        ),
        child: Padding(
          padding: EdgeInsets.all(_s(8, scale)),
          child: TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

            onDaySelected: (selectedDay, focusedDay) {

              DateTime today = DateTime.now();
              DateTime selected =
              DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

              DateTime todayDate =
              DateTime(today.year, today.month, today.day);

              /// allow holiday click
              bool isHoliday =
                  _attendanceData[selected]?['status'] == "Holiday";

              if (selected.isAfter(todayDate) && !isHoliday) {
                return;
              }

              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },

            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              _fetchEmployeeDataForMonth(focusedDay.year, focusedDay.month);
            },

            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: _s(16, scale),
                fontWeight: FontWeight.bold,
              ),
            ),

            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: _s(12, scale),
                fontWeight: FontWeight.w500,
              ),
              weekendStyle: TextStyle(
                fontSize: _s(12, scale),
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),

            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.yellow.shade200,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.blue, width: _s(2, scale)),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(color: Colors.black),
              todayTextStyle: TextStyle(color: Colors.black),
              defaultTextStyle: TextStyle(fontSize: _s(13, scale)),
              weekendTextStyle: TextStyle(
                fontSize: _s(13, scale),
                color: Colors.grey,
              ),
              outsideDaysVisible: false,
            ),

            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, _) {

                DateTime normalizedDate =
                DateTime(date.year, date.month, date.day);

                String? status = _attendanceData[normalizedDate]?['status'];

                bool isWeekend =
                    date.weekday == DateTime.saturday ||
                        date.weekday == DateTime.sunday;

                DateTime today = DateTime.now();

                bool isToday =
                    today.year == date.year &&
                        today.month == date.month &&
                        today.day == date.day;

                Color? bgColor;

                if (status != null) {
                  bgColor = _statusColors[status]?.withOpacity(0.3);
                }

                /// if today but no status yet
                if (isToday && bgColor == null) {
                  bgColor = Colors.yellow.shade200;
                }

                return Container(
                  margin: EdgeInsets.all(_s(4, scale)),
                  padding: EdgeInsets.all(_s(6, scale)),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: _s(14, scale),
                        fontWeight: FontWeight.bold,
                        color: isWeekend ? Colors.grey : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorLegend(double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _s(12, scale),
        vertical: _s(8, scale),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _statusColors.entries.map((entry) {
          return Row(
            children: [
              Container(
                width: _s(12, scale),
                height: _s(12, scale),
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: _s(6, scale)),
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: _s(12, scale),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageSection(double screenWidth, double scale) {

    if (_selectedDay == null) return const SizedBox();

    DateTime selectedDate =
    DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

    final dayData = _attendanceData.entries.firstWhere(
          (entry) {
        DateTime keyDate =
        DateTime(entry.key.year, entry.key.month, entry.key.day);
        return keyDate == selectedDate;
      },
      orElse: () => MapEntry(DateTime.now(), {}),
    ).value;

    if (dayData != null &&
        dayData.isNotEmpty &&
        (dayData['status'] == "Present" || dayData['status'] == "In" ||  dayData['status'] == "Holiday")) {

      final String checkinFullPath =
          'https://hrms.attendify.ai/detectedImages/${dayData['checkinImage']}';

      final String checkoutFullPath =
          'https://hrms.attendify.ai/detectedImages/${dayData['checkoutImage']}';

      String checkinTimeRaw = dayData['first_check_in'] ?? '';
      String checkoutTimeRaw = dayData['last_check_in'] ?? '';

      String checkinTime = "";
      String checkoutTime = "";

      if (checkinTimeRaw.isNotEmpty) {
        checkinTime = DateFormat('HH:mm')
            .format(DateTime.parse(checkinTimeRaw));
      }

      if (checkoutTimeRaw.isNotEmpty) {
        checkoutTime = DateFormat('HH:mm')
            .format(DateTime.parse(checkoutTimeRaw));
      }

      final String formattedDate =
      DateFormat('dd-MM-yyyy').format(selectedDate);


      /// HOLIDAY CARD
      if (dayData['status'] == "Holiday") {

        final String holidayName =
            dayData['holidayname'] ?? "Holiday";

        final String formattedDate =
        DateFormat('dd-MM-yyyy').format(selectedDate);

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

          Center(
          child: Text(
          formattedDate,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: _s(16, scale),
          ),
        ),
    ),

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
                    holidayName,
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

      return Card(
        color: Colors.white,
        elevation: _s(1, scale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_s(12, scale)),
        ),
        child: Padding(
          padding: EdgeInsets.all(_s(5, scale)),
          child: Column(
          children: [

          /// Selected Date
          Text(
          formattedDate,
          style: TextStyle(
            fontSize: _s(16, scale),
            fontWeight: FontWeight.bold,
          ),
        ),

        SizedBox(height: _s(10, scale)),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNetworkImage("Check-In", checkinFullPath, checkinTime, scale),
            _buildNetworkImage("Check-Out", checkoutFullPath, checkoutTime, scale),
          ],
        ),
        ],
      ),
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildNetworkImage(
      String title,
      String imageUrl,
      String time,
      double scale,
      ) {
    return Column(
      children: [

        Text(
          '$title : $time',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _s(14, scale),
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: _s(8, scale)),

        Container(
          width: _s(180, scale),
          height: _s(160, scale),
          padding: EdgeInsets.all(_s(3, scale)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_s(8, scale)),
            image: imageUrl.isNotEmpty
                ? DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            )
                : null,
          ),
        ),
      ],
    );
  }



}

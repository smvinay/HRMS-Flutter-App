import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceCal extends StatefulWidget {
  @override
  _AttendanceCalState createState() => _AttendanceCalState();
}

class _AttendanceCalState extends State<AttendanceCal> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _userId = "";
  String _companyDb = "";
  String _deptid = "";
  String _cid = "";

  Map<DateTime, Map<String, dynamic>> _attendanceData = {};
  // Map<DateTime, Map<String, dynamic>> _attendanceData

  bool _isLoading = false;

  // final Map<DateTime, String> _attendanceData = {
  //   DateTime(2025, 3, 5): 'Present',
  //   DateTime(2025, 3, 6): 'Absent',
  //   DateTime(2025, 3, 7): 'Holiday',
  //   DateTime(2025, 3, 12): 'Present',
  //   DateTime(2025, 3, 18): 'Absent',
  //   DateTime(2025, 3, 26): 'In',
  // };

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

  // Use cache if this is a past month
  if (requestedMonth.isBefore(currentMonth) && prefs.containsKey(cacheKey)) {
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
      "https://app.attendify.ai/template/public/index.php/MobileApi/get_empattendacedata?company_db=$_companyDb&userid=$_userId&year=$year&month=$month";
  String url2 =
      "https://app.attendify.ai/template/public/index.php/MobileApi/get_daysholiday?company_db=$_companyDb&cid=$_cid&year=$year&month=$month&deptID=$_deptid";

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
            'holidayname': holiday['name'],
          };
        }
      }

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



  // Future<void> _fetchEmployeeDataForMonth(int year, int month) async {
  //   final prefs = await SharedPreferences.getInstance();

  //   setState(() {
  //     _userId = prefs.getString('employe_code') ?? "";
  //     _companyDb = prefs.getString('companyDb') ?? "";
  //     _deptid = prefs.getString('department') ?? "0";
  //     _cid = prefs.getString('cid') ?? "0";
  //     _isLoading = true;
  //   });

  //   String url =
  //       "https://app.attendify.ai/template/public/index.php/MobileApi/get_empattendacedata?company_db=$_companyDb&userid=$_userId&year=$year&month=$month";

  //   String url2 =
  //       "https://app.attendify.ai/template/public/index.php/MobileApi/get_daysholiday?company_db=$_companyDb&cid=$_cid&year=$year&month=$month&deptID=$_deptid";

  //   try {
  //     final response = await http.get(Uri.parse(url));
  //     final holidayResponse = await http.get(Uri.parse(url2));

  //     if (response.statusCode == 200 && holidayResponse.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       final holidayData = json.decode(holidayResponse.body);

  //       Map<DateTime, Map<String, dynamic>> updatedData = {};
  //       Set<DateTime> fetchedDates = {};
  //       Set<DateTime> holidayDates = {};

  //       // Step 1: Handle Holidays First
  //       if (holidayData['data'] != null) {
  //         for (var holiday in holidayData['data']) {
  //           DateTime holidayDate = DateTime.parse(holiday['date']);
  //           holidayDate =
  //               DateTime(holidayDate.year, holidayDate.month, holidayDate.day);
  //           holidayDates.add(holidayDate);

  //           updatedData[holidayDate] = {
  //             'status': 'Holiday',
  //             'checkinImage': null,
  //             'checkoutImage': null,
  //             'holidayname': holiday['name'],
  //           };
  //         }
  //       }

  //       DateTime now = DateTime.now();
  //       int daysInMonth = DateTime(year, month + 1, 0).day;

  //       // Step 2: Process Attendance from API
  //       if (data['data'] != null) {
  //         for (var entry in data['data']) {
  //           if (entry['attendance_date'] != null &&
  //               entry['attendance_date'].toString().isNotEmpty) {
  //             DateTime fullDate = DateTime.parse(entry['attendance_date']);
  //             DateTime date =
  //                 DateTime(fullDate.year, fullDate.month, fullDate.day);
  //             fetchedDates.add(date);

  //             String status;
  //             if ((entry['first_check_in'] != null &&
  //                     entry['first_check_in'].toString().isNotEmpty) &&
  //                 (entry['last_check_in'] != null &&
  //                     entry['last_check_in'].toString().isNotEmpty)) {
  //               status = "Present";
  //             } else if ((entry['first_check_in'] == null ||
  //                     entry['first_check_in'].toString().isEmpty) &&
  //                 (entry['last_check_in'] == null ||
  //                     entry['last_check_in'].toString().isEmpty)) {
  //               status = "Absent";
  //             } else {
  //               status = "In";
  //             }

  //             updatedData[date] = {
  //               'status': status,
  //               'checkinImage': entry['fullfirst_detected_face'] ?? null,
  //               'checkoutImage': entry['fulllast_detected_face'] ?? null,
  //               'holidayname' : null,
  //             };
  //           }
  //         }
  //       };

  //       // Step 3: Fill remaining past and today as Absent (but don't overwrite Holidays or Attendance)
  //       for (int i = 1; i <= daysInMonth; i++) {
  //         DateTime day = DateTime(_focusedDay.year, _focusedDay.month, i);

  //         bool isWeekend = day.weekday == DateTime.saturday ||
  //             day.weekday == DateTime.sunday;
  //         bool isPastOrToday = day.isBefore(now) ||
  //             (day.day == now.day &&
  //                 day.month == now.month &&
  //                 day.year == now.year);


  //          if (isPastOrToday && !isWeekend && !fetchedDates.contains(day)) {
  //           updatedData[day] = {
  //             'status': 'Absent',
  //             'checkinImage': null,
  //             'checkoutImage': null,
  //               'holidayname' : null,
  //           };
  //         }
  //       }

  //       setState(() {
  //         _attendanceData = updatedData;
  //         _isLoading = false;
  //       });
  //     } else {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     print("Error fetching data: $e");
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Calendar'),
        backgroundColor: const Color(0xFF0557a2),
        titleTextStyle: TextStyle(color: Colors.white ,fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white), // 👈 Make back icon white
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              _buildCalendarCard(),
              SizedBox(height: 5),
              _buildColorLegend(),
              SizedBox(height: 8),
              _buildImageSection(screenWidth),
            ],
          ),
        ),
      ),
    );
  }

// Widget _buildCalendarCard() {
//   return Card(
//     elevation: 4,
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     child: Padding(
//       padding: EdgeInsets.all(8),
//       child: TableCalendar(
//         key: ValueKey(_focusedDay), // triggers rebuild when month changes
//         firstDay: DateTime.utc(2000, 1, 1),                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       
//         lastDay: DateTime.utc(2100, 12, 31),
//         focusedDay: _focusedDay,
//         calendarFormat: _calendarFormat,
//         selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//         onDaySelected: (selectedDay, focusedDay) {
//           setState(() {
//             _selectedDay = selectedDay;
//             _focusedDay = focusedDay;
//           });
//         },
//         onPageChanged: (focusedDay) {
//           setState(() {
//             _focusedDay = focusedDay;
//           });
//           _fetchEmployeeDataForMonth(focusedDay.year, focusedDay.month);
//         },
//         headerStyle: HeaderStyle(
//           formatButtonVisible: false,
//           titleCentered: true,
//           titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//         ),
//         daysOfWeekStyle: DaysOfWeekStyle(
//           weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
//           weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
//         ),
//         calendarStyle: CalendarStyle(
//           todayDecoration: BoxDecoration(
//             border: Border.all(color: Colors.blueAccent),
//             shape: BoxShape.circle,
//           ),
//           selectedDecoration: BoxDecoration(
//             color: Colors.yellow.shade300,
//             shape: BoxShape.circle,
//           ),
//           selectedTextStyle: TextStyle(color: Colors.black),
//           todayTextStyle: TextStyle(color: Colors.black),
//         ),
//         calendarBuilders: CalendarBuilders(
//           defaultBuilder: (context, date, _) {
//             DateTime normalizedDate = DateTime(date.year, date.month, date.day);
//             String? status = _attendanceData[normalizedDate]?['status'];

//             bool isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

//             return Container(
//               margin: EdgeInsets.all(4),
//               padding: EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: status != null
//                     ? _statusColors[status]?.withOpacity(0.3)
//                     : Colors.transparent,
//                 shape: BoxShape.circle,
//               ),
//               child: Center(
//                 child: Text(
//                   '${date.day}',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: isWeekend
//                         ? Colors.grey
//                         : Colors.black,
//                   ),
//                 ),
//               ),
//             );
//           },
//           selectedBuilder: (context, date, _) {
//             DateTime normalizedDate = DateTime(date.year, date.month, date.day);
//             String? status = _attendanceData[normalizedDate]?['status'];

//             return Container(
//               margin: EdgeInsets.all(4),
//               padding: EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: status != null
//                     ? _statusColors[status]?.withOpacity(0.4)
//                     : Colors.transparent,
//                 border: Border.all(color: Colors.blue, width: 2),
//                 shape: BoxShape.circle,
//               ),
//               child: Center(
//                 child: Text(
//                   '${date.day}',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black,
//                   ),
//                 ),
//               ),
//             );
//           },
//           todayBuilder: (context, date, _) {
//             return Container(
//               margin: EdgeInsets.all(4),
//               padding: EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: Colors.yellow.shade200,
//                 shape: BoxShape.circle,
//               ),
//               child: Center(
//                 child: Text(
//                   '${date.day}',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black,
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     ),
//   );
// }


  Widget _buildCalendarCard() {
  return AnimatedSwitcher(
    duration: Duration(milliseconds: 150),
    child: Card(
      key: ValueKey(_focusedDay), // Trigger animation when _focusedDay changes.
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: TableCalendar(
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            weekendStyle: TextStyle(
              fontSize: 12,
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
              color: Colors.transparent, // Color comes from calendarBuilders.
              border: Border.all(color: Colors.blue, width: 2),
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(color: Colors.black),
            todayTextStyle: TextStyle(color: Colors.black),
            defaultTextStyle: TextStyle(fontSize: 13),
            weekendTextStyle: TextStyle(fontSize: 13, color: Colors.grey),
            outsideDaysVisible: false,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, date, _) {
              DateTime normalizedDate =
                  DateTime(date.year, date.month, date.day);
              String? status = _attendanceData[normalizedDate]?['status'];
              bool isWeekend = date.weekday == DateTime.saturday ||
                  date.weekday == DateTime.sunday;

              return Container(
                margin: EdgeInsets.all(4),
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: status != null
                      ? _statusColors[status]?.withOpacity(0.3)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isWeekend ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              );
            },
            selectedBuilder: (context, date, _) {
              DateTime normalizedDate =
                  DateTime(date.year, date.month, date.day);
              String? status = _attendanceData[normalizedDate]?['status'];

              return Container(
                margin: EdgeInsets.all(4),
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: status != null
                      ? _statusColors[status]?.withOpacity(0.4)
                      : Colors.transparent,
                  border: Border.all(color: Colors.blue, width: 2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              );
            },
            todayBuilder: (context, date, _) {
              return Container(
                margin: EdgeInsets.all(4),
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade200,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
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


  Widget _buildColorLegend() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _statusColors.entries.map((entry) {
          return Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: entry.value,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(entry.key,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImageSection(double screenWidth) {
    if (_selectedDay == null) return SizedBox(); // no date selected

    // Normalize selected day (only date, no time)
    DateTime selectedDate =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

    // Find exact matching key in the map
    final dayData = _attendanceData.entries.firstWhere(
      (entry) {
        DateTime keyDate =
            DateTime(entry.key.year, entry.key.month, entry.key.day);
        return keyDate == selectedDate;
      },
      orElse: () => MapEntry(DateTime.now(), {}), // fallback to empty
    ).value;

    // Debug
    // print("Selected: $selectedDate");
    // print("dayData: $dayData");

    if (dayData != null &&
        dayData.isNotEmpty &&
        (dayData['status'] == "Present" || dayData['status'] == "In")) {
      final String defaultImage =
          ''; // Replace with your actual default image path

      final String checkinFullPath = dayData['checkinImage'] != null &&
              dayData['checkinImage'] != ''
          ? 'https://vision.techkshetra.ai/faceRecognitionEngine/application/uploads/${dayData['checkinImage']}'
          : defaultImage;

      final String checkoutFullPath = dayData['checkoutImage'] != null &&
              dayData['checkoutImage'] != ''
          ? 'https://vision.techkshetra.ai/faceRecognitionEngine/application/uploads/${dayData['checkoutImage']}'
          : defaultImage;

      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNetworkImage("Check-In", checkinFullPath),
                  _buildNetworkImage("Check-Out", checkoutFullPath),
                ],
              ),
            ],
          ),
        ),
      );
    } else if(dayData['status'] == "Holiday"){
final String holidayname = dayData['holidayname'] != null && dayData['holidayname'].toString().isNotEmpty
    ? dayData['holidayname']
    : '- - -';

      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
             children: [
              Row(     
                mainAxisAlignment: MainAxisAlignment.center,        
                children: [
                Text(holidayname,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
             ],
          ),
        ),
      );
    }   
    else {
      return SizedBox(); // No image shown
    }
  }

  Widget _buildNetworkImage(String title, String imageUrl) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Container(
          width: 155,
          height: 155,
          padding: EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

}

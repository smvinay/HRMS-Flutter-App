import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceCal extends StatefulWidget {
  @override
  _AttendanceCalState createState() => _AttendanceCalState();
}

class _AttendanceCalState extends State<AttendanceCal> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<DateTime, String> _attendanceData = {
    DateTime(2025, 3, 5): 'Present',
    DateTime(2025, 3, 6): 'Absent',
    DateTime(2025, 3, 7): 'Holiday',
    DateTime(2025, 3, 12): 'Present',
    DateTime(2025, 3, 18): 'Absent',
    DateTime(2025, 3, 26): 'In',
  };

  final Map<String, Color> _statusColors = {
    'Present': Colors.green.shade300,
    'Absent': Colors.red.shade300,
    'In': Colors.blue.shade300,
    'Holiday': Colors.orange.shade300,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
            appBar: AppBar(title: Text("Attendance Calendar")),
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

  Widget _buildCalendarCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(5),
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
            _focusedDay = focusedDay;
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.yellow.shade300,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(color: Colors.black),
            todayTextStyle: TextStyle(color: Colors.black),
            defaultTextStyle: TextStyle(fontSize: 13),
            weekendTextStyle: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, date, _) {
              DateTime normalizedDate = DateTime(date.year, date.month, date.day);
              String? status = _attendanceData[normalizedDate];
              bool isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

              return Container(
                margin: EdgeInsets.all(4),
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: status != null ? _statusColors[status] : Colors.transparent,
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
              Text(entry.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          );
        }).toList(),
      ),
    );
  }

 Widget _buildImageSection(double screenWidth) {
  return Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Ensure equal spacing
            children: [
              _buildImageContainer("Check-In", "assets/checkin.png"),
              _buildImageContainer("Check-Out", "assets/checkout.png"),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildImageContainer(String title, String imagePath) {
  return Column(
    children: [
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), // Title at top
      SizedBox(height: 5),
      Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
        ),
      ),
    ],
  );
}

}

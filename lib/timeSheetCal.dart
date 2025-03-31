import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class TimesheetCal extends StatefulWidget {
  @override
  _TimesheetCalState createState() => _TimesheetCalState();
}

class _TimesheetCalState extends State<TimesheetCal> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 📌 Dates with their respective status
  final Map<DateTime, String> _statusData = {
    DateTime(2025, 3, 25): 'Approved',
    DateTime(2025, 3, 3): 'Approved',
    DateTime(2025, 3, 4): 'Approved',
    DateTime(2025, 3, 20): 'Submitted',
    DateTime(2025, 3, 19): 'Saved',
    DateTime(2025, 3, 13): 'Rejected',
  };

  // 📌 Color Mapping for Status
  final Map<String, Color> _statusColors = {
    'Approved': Colors.blue.shade300, // Light Blue
    'Submitted': Colors.lightGreen.shade300, // Light Green
    'Saved': Colors.orange.shade300, // Light Orange
    'Rejected': Colors.red.shade300, // Light Red
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
      appBar: AppBar(title: Text("Timesheet Calendar")),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            children: [
              _buildCalendarCard(),
              SizedBox(height: 5),
              _buildColorLegend(), // Color Legend
              SizedBox(height: 8),
              _buildSummaryCard(
                  "Timesheet Submitted", "1", Colors.black87, screenWidth),
              _buildSummaryCard(
                  "Timesheet Save", "1", Colors.black87, screenWidth),
              _buildSummaryCard(
                  "Timesheet Approved", "3", Colors.black87, screenWidth),
              _buildSummaryCard(
                  "Timesheet Rejected", "1", Colors.black87, screenWidth),
            ],
          ),
        ),
      ),
    );
  }

  // 📌 Calendar with Custom Colors
  Widget _buildCalendarCard() {
    return Card(
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
            _focusedDay = focusedDay;
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            weekendStyle: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
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
            weekendTextStyle:
                TextStyle(fontSize: 13, color: Colors.grey), // Gray text for weekends
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, date, _) {
              DateTime normalizedDate =
                  DateTime(date.year, date.month, date.day);
              String? status = _statusData[normalizedDate];

              bool isWeekend =
                  date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

              return Container(
                margin: EdgeInsets.all(4),
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: status != null
                      ? _statusColors[status]
                      : Colors.transparent, // Apply status color if available
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

  // 📌 Color Legend Below Calendar
  // Widget _buildColorLegend() {
  //   return Card(
  //     elevation: 3,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //     child: Padding(
  //       padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: _statusColors.entries.map((entry) {
  //           return _buildLegendItem(entry.key, entry.value);
  //         }).toList(),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildColorLegend() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _statusColors.entries.map((entry) {
          return Row(
            children: [
              Container(
                width: 11,
                height: 11,
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


  // 📌 Summary Cards
  Widget _buildSummaryCard(
      String title, String count, Color color, double screenWidth) {
    return Container(
      width: screenWidth,
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
              Text(
                count,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

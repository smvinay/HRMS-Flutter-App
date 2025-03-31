import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class LeaveCal extends StatefulWidget {
  @override
  _LeaveCalState createState() => _LeaveCalState();
}

class _LeaveCalState extends State<LeaveCal> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Map<DateTime, String> _leaveStatus = {
    DateTime(2025, 3, 5): 'Approved',
    DateTime(2025, 3, 10): 'Rejected',
    DateTime(2025, 3, 15): 'Pending',
  };

  final Map<String, Color> _statusColors = {
    'Approved': Colors.blue.shade300,
    'Pending': Colors.orange.shade300,
    'Rejected': Colors.red.shade300,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _showApplyLeaveDialog(DateTime day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Apply for Leave"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _leaveStatus[day] = 'Pending';
              });
              Navigator.pop(context);
            },
            child: Text("Apply"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: Text("Leave Calendar")),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              _buildCalendarCard(),
              SizedBox(height: 5),
              _buildColorLegend(),
              SizedBox(height: 8),
              _buildLeaveSummary(screenWidth),
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
            if (selectedDay.isAfter(DateTime.now()) || isSameDay(selectedDay, DateTime.now())) {
              _showApplyLeaveDialog(selectedDay);
            }
          },
          onPageChanged: (focusedDay) => _focusedDay = focusedDay,
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
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, date, _) {
              DateTime normalizedDate = DateTime(date.year, date.month, date.day);
              String? status = _leaveStatus[normalizedDate];

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
                      color: isWeekend ? Colors.grey : (status != null ? Colors.white : Colors.black),
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
              Text(entry.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeaveSummary(double screenWidth) {
    return Column(
      children: [
        _buildSummaryCard("Available Leaves", "Sick: 6 | Casual: 12", Colors.black87, screenWidth),
        _buildSummaryCard("Taken Leaves", "Sick: 2 | Casual: 4", Colors.black87, screenWidth),
        _buildSummaryCard("Pending Leaves", "1", Colors.black87, screenWidth),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color, double screenWidth) {
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
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
              Text(count, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

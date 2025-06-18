import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApplyLeavePage extends StatefulWidget {
  @override
  _ApplyLeavePageState createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  String? _leaveType = 'Casual';
  String _leaveDayType = 'Full Day';

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  double _duration = 1.0;

  final TextEditingController _reasonController = TextEditingController();

  Future<void> _submitLeave() async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString("userId");

    Map<String, dynamic> leaveData = {
      'user_id': userId,
      'leave_type': _leaveType,
      'day_type': _leaveDayType,
      'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
      'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
      'duration': _duration,
      'reason': _reasonController.text,
    };

    // TODO: Replace with API call
    print("Sending: $leaveData");

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leave Submitted")));
    Navigator.pop(context);
  }

  void _handleDayTypeChange(String? value) {
    setState(() {
      _leaveDayType = value!;
      if (_leaveDayType == 'Half Day') {
        _duration = 0.5;
        _fromDate = DateTime.now();
        _toDate = DateTime.now();
      } else {
        _duration = _toDate.difference(_fromDate).inDays.toDouble() + 1;
      }
    });
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
        }

        if (_leaveDayType == 'Full Day') {
          _duration = _toDate.difference(_fromDate).inDays.toDouble() + 1;
        }
      });
    }
  }

  Widget _buildDropdown(String label, List<String> options, String selected, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: selected,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      items: options.map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap, bool enabled) {
    return TextFormField(
      readOnly: true,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      controller: TextEditingController(
        text: DateFormat('dd-MM-yyyy').format(date),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isHalfDay = _leaveDayType == 'Half Day';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Apply Leave"),
        backgroundColor: const Color(0xFF0557a2),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildDropdown("Leave Type", ['Casual', 'Sick'], _leaveType!, (val) {
              setState(() => _leaveType = val);
            }),
            const SizedBox(height: 12),
            _buildDropdown("Days", ['Full Day', 'Half Day'], _leaveDayType, _handleDayTypeChange),
            const SizedBox(height: 12),
            _buildDateField("From Date", _fromDate, () => _pickDate(isFromDate: true), !isHalfDay),
            const SizedBox(height: 12),
            _buildDateField("To Date", _toDate, () => _pickDate(isFromDate: false), !isHalfDay),
            const SizedBox(height: 10),
            Text("Duration: $_duration day(s)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.send, color: Colors.white),
              label: Text("Submit Leave", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0557a2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: _submitLeave,
            ),
          ],
        ),
      ),
    );
  }
}

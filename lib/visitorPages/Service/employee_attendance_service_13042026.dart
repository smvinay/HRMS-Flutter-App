import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_welcome_overlay.dart';
import 'package:flutter/material.dart';

class EmployeeAttendanceService {

  Timer? _timer;

  /// Queue to show employees one by one
  final Queue<Map<String, dynamic>> _employeeQueue = Queue();

  bool _isShowing = false;

  void start(BuildContext context) {

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {

      try {

        final prefs = await SharedPreferences.getInstance();

        final apiKey = prefs.getString('apiKey');
        final companyDb = prefs.getString('companyDb');
        final cid = prefs.getString('cid');
        final level_id = prefs.getString('level_id');

        if (apiKey == null || companyDb == null || cid == null || level_id != '7') {
          return;
        }

        final url = Uri.parse(
          "https://hrms.attendify.ai/index.php/MobileApi/getEmpAttMob",
        );

        final response = await http.post(
          url,
          headers: {
            'apiKey': apiKey,
            'companyDb': companyDb,
          },
          body: {
            "cid": cid
          },
        );

        if (response.statusCode == 200) {

          final data = json.decode(response.body);

          // print(data);

          if (data is List && data.isNotEmpty) {

            /// add all employees to queue
            for (var emp in data) {
              _employeeQueue.add(emp);
            }

            /// start displaying if not already
            _processQueue(context);

          }

        }

      } catch (e) {
        print(e);
      }

    });

  }

  void _processQueue(BuildContext context) async {

    if (_isShowing || _employeeQueue.isEmpty) return;

    _isShowing = true;

    while (_employeeQueue.isNotEmpty) {

      final emp = _employeeQueue.removeFirst();

      final name = emp["first_name"];
      final checkInTime = emp["checkInTime"];
      final userid = emp["userid"] ?? "";
      final photo = emp["user_profile"] != null
          ? "https://hrms.attendify.ai/photos/${emp["profile_thumbnail"]}"
          : "";

      EmployeeOverlayService().show(
        context,
        name.toString(),
        photo.toString(),
        checkInTime.toString(),
        userid.toString(),
      );

      /// wait until overlay hides
      await Future.delayed(const Duration(seconds: 2));
    }

    _isShowing = false;

  }

  void stop() {
    _timer?.cancel();
  }

}
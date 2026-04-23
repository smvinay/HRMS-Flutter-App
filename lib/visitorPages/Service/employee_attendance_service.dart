import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'socket_service.dart';
import 'employee_welcome_overlay.dart';

class EmployeeAttendanceService {

  static final EmployeeAttendanceService _instance =
  EmployeeAttendanceService._internal();

  factory EmployeeAttendanceService() => _instance;

  EmployeeAttendanceService._internal();

  final Queue<Map<String, dynamic>> _queue = Queue();
  bool _isShowing = false;
  bool _initialized = false;

  /// prevent duplicate users
  final Set<String> _shownUsers = {};

  /// socket reference
  final SocketService _socketService = SocketService();

  void start(BuildContext context) async {

    if (_initialized) return; // prevent multiple init
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final cid = prefs.getString('unique_code');

    if (cid == null) return;

    /// connect socket
    _socketService.connect(context, cid);

    /// listen to socket events
    _socketService.socket.on("employee_checkin", (data) {

      if (data == null) return;

      final emp = Map<String, dynamic>.from(data);

      final userId = emp["userid"] ?? "";

      /// avoid duplicate popup
      if (_shownUsers.contains(userId)) return;

      _shownUsers.add(userId);

      _queue.add(emp);

      _processQueue(context);
    });
  }

  void _processQueue(BuildContext context) async {

    if (_isShowing || _queue.isEmpty) return;

    _isShowing = true;

    while (_queue.isNotEmpty) {

      final emp = _queue.removeFirst();

      final name = emp["first_name"] ?? "";
      final userid = emp["userid"] ?? "";
      final checkInTime = emp["checkInTime"] ?? "";
      final photo = emp["profile_thumbnail"] != null
          ? "https://hrms.attendify.ai/photos/${emp["profile_thumbnail"]}"
          : "";

      EmployeeOverlayService().show(
        Navigator.of(context, rootNavigator: true).context,
        name.toString(),
        photo.toString(),
        checkInTime.toString(),
        userid.toString(),
      );

      await Future.delayed(const Duration(seconds: 2));
    }

    _isShowing = false;
  }

  void stop() {
    _socketService.disconnect();
    _initialized = false;
    _shownUsers.clear();
  }
}
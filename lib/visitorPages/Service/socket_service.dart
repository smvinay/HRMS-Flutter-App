import 'dart:collection';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'employee_welcome_overlay.dart';

class SocketService {

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();
  bool _connected = false;

  late IO.Socket socket;

  final Queue<Map<String, dynamic>> _queue = Queue();
  bool _isShowing = false;

  void connect(context, String companyId) {

    if (_connected) {
      print("Already connected");
      return;
    }

    socket = IO.io(
      "http://hrms.attendify.ai:3000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .build(),
    );

    socket.onConnect((_) {
      print("Socket connected");

      _connected = true;

      socket.emit("join_company", companyId);
    });

    socket.onDisconnect((_) {
      print("Socket disconnected");

      _connected = false;
    });

    /// IMPORTANT: remove old listener before adding new
    socket.off("employee_checkin");

    socket.on("employee_checkin", (data) {

      if (data == null) return;

      _queue.add(Map<String, dynamic>.from(data));

      _processQueue(context);
    });
  }

  void _processQueue(context) async {

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
        context,
        name.toString(),
        photo.toString(),
        checkInTime.toString(),
        userid.toString(),
      );

      await Future.delayed(const Duration(seconds: 2));
    }

    _isShowing = false;
  }

  void disconnect() {
    socket.disconnect();
  }
}
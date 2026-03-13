import 'dart:async';
import 'package:flutter/material.dart';

class EmployeeOverlayService {

  static final EmployeeOverlayService _instance =
  EmployeeOverlayService._internal();

  factory EmployeeOverlayService() => _instance;

  EmployeeOverlayService._internal();

  OverlayEntry? _overlayEntry;
  bool _isShowing = false;

  void show(BuildContext context, String name, String photo, checkInTime, userid) {

    if (_isShowing) return;

    _isShowing = true;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: _WelcomeCard(
              name: name,
              photo: photo,
              checkInTime: checkInTime,
              userid: userid,
              onFinish: hide,
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }
}

class _WelcomeCard extends StatefulWidget {

  final String name;
  final String photo;
  final String checkInTime;
  final String userid;
  final VoidCallback onFinish;

  const _WelcomeCard({
    required this.name,
    required this.photo,
    required this.checkInTime,
    required this.userid,
    required this.onFinish,
  });

  @override
  State<_WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<_WelcomeCard>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();

    /// auto hide after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      widget.onFinish();
    });
  }

  String formatTime(String dateTime) {
    try {
      DateTime dt = DateTime.parse(dateTime);
      return "${dt.day}-${dt.month}-${dt.year}  ${dt.hour}:${dt.minute}";
    } catch (e) {
      return dateTime;
    }
  }
  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;
    final width = size.width;

    final imageSize = width * 0.75; // 75% screen width
    final tickSize = width * 0.18;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(1),
            Colors.green.withOpacity(1),
          ],
        ),
      ),
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              /// SUCCESS TICK ICON
              Container(
                width: tickSize,
                height: tickSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0,8),
                    )
                  ],
                ),
                child: Icon(
                  Icons.check,
                  color: const Color(0xFF00A86B),
                  size: tickSize * 0.6,
                ),
              ),

              const SizedBox(height: 35),

              /// EMPLOYEE IMAGE
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0,10),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.photo,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 35),

              /// WELCOME TEXT
              Text(
                "WELCOME",
                style: TextStyle(
                  fontSize: width * 0.07,
                  letterSpacing: 3,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
              ),

              const SizedBox(height: 8),

              /// EMPLOYEE NAME
              Text(
                widget.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              /// EMPLOYEE CODE
              Text(
                widget.userid,
                style: TextStyle(
                  fontSize: width * 0.03,
                  fontWeight: FontWeight.w300,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 10),

              /// CHECK IN TIME WITH ICON
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Icon(
                    Icons.access_time,
                    color: Colors.white70,
                    size: width * 0.04,
                  ),

                  const SizedBox(width: 6),

                  Text(
                    formatTime(widget.checkInTime),
                    style: TextStyle(
                      fontSize: width * 0.04,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }
}
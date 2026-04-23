import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AnimatedToast extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const AnimatedToast({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<AnimatedToast> createState() => AnimatedToastState();
}

class AnimatedToastState extends State<AnimatedToast>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fade = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    /// AUTO HIDE AFTER 3 SEC
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isError ? Colors.red : Colors.green,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6)
                ],
              ),
              child: Text(
                widget.message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
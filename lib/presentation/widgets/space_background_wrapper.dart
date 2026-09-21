import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SpaceBackgroundWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const SpaceBackgroundWrapper({super.key, required this.child});

  @override
  ConsumerState<SpaceBackgroundWrapper> createState() => _SpaceBackgroundWrapperState();
}

class _SpaceBackgroundWrapperState extends ConsumerState<SpaceBackgroundWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 40 second continuous loop
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return Stack(
      children: [
        // Background color based on theme
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(225, 210, 250, 1),
            ),
          ),
        ),


        // App Content
        widget.child,
      ],
    );
  }
}

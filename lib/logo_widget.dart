import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final bool showBorder;
  final double padding;

  const LogoWidget({
    Key? key,
    this.size = 40,
    this.backgroundColor = const Color(0xFF6A1B9A),
    this.textColor = Colors.white,
    this.showBorder = false,
    this.padding = 6.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: showBorder ? Border.all(color: Colors.white, width: 1.5) : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                'PS',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

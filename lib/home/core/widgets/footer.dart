import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  final String appName;
  final Color textColor;
  final Color dividerColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppFooter({
    Key? key,
    this.appName = 'Purple Safety',
    this.textColor = Colors.white,
    this.dividerColor = Colors.white30,
    this.fontSize = 12.0,
    this.padding = const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      child: Column(
        children: [
          Divider(height: 1, color: dividerColor, thickness: 0.5),
          const SizedBox(height: 20),
          Text(
            '© ${DateTime.now().year} $appName. All rights reserved.',
            style: TextStyle(
              fontSize: fontSize,
              color: textColor,
              fontStyle: FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SimpleFooter extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final EdgeInsetsGeometry padding;

  const SimpleFooter({
    Key? key,
    this.text = '© Purple Safety App. All rights reserved.',
    this.color = Colors.white,
    this.size = 12.0,
    this.padding = const EdgeInsets.symmetric(vertical: 20.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(fontSize: size, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}

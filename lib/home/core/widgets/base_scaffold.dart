import 'package:flutter/material.dart';
import 'footer.dart';

class BaseScaffold extends StatelessWidget {
  final Widget body;
  final String appName;
  final AppBar? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Color backgroundColor;
  final bool showFooter;
  final bool resizeToAvoidBottomInset;

  const BaseScaffold({
    Key? key,
    required this.body,
    this.appName = 'Purple Safety',
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.backgroundColor = const Color(0xFFF3E5F5),
    this.showFooter = true,
    this.resizeToAvoidBottomInset = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Column(
        children: [
          Expanded(child: body),
          if (showFooter)
            // Wrap footer in SafeArea to avoid system navigation bar overlap (fallback)
            SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Container(
                color: const Color(0xFF6A1B9A),
                child: AppFooter(appName: appName, textColor: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

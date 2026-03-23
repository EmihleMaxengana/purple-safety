import 'package:flutter/material.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback? onSOSActivated;
  const SOSButton({Key? key, this.onSOSActivated}) : super(key: key);

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.onSOSActivated,
      child: const Text('SOS'),
    );
  }
}

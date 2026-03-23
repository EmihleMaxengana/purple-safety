import 'package:flutter/material.dart';

class LiveLocationCard extends StatelessWidget {
  final bool isSharing;
  final VoidCallback onStopSharing;
  final VoidCallback onUpdateContacts;

  const LiveLocationCard({
    Key? key,
    required this.isSharing,
    required this.onStopSharing,
    required this.onUpdateContacts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('Live Location Card'),
    );
  }
}

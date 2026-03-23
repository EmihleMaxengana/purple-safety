import 'package:flutter/material.dart';

class ForgotPasswordModal extends StatefulWidget {
  const ForgotPasswordModal({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Center(child: Text('Forgot Password Modal')),
    );
  }
}

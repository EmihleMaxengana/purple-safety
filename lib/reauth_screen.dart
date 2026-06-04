import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purple_safety/services/auth_service.dart';
// import 'package:purple_safety/login_screen.dart';

class ReauthScreen extends StatefulWidget {
  const ReauthScreen({Key? key, this.onAuthenticated}) : super(key: key);

  final VoidCallback? onAuthenticated;

  @override
  State<ReauthScreen> createState() => _ReauthScreenState();
}

class _ReauthScreenState extends State<ReauthScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscure = true;
  String _error = '';
  bool _isLoading = false;

  Color get _primary => const Color(0xFF6A1B9A);
  Color get _accent => const Color(0xFFBF7DCB);
  Color get _bgDark => const Color(0xFF100c1f);

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password');
      return;
    }

    setState(() => _isLoading = true);

    final isValid = await _authService.reauthenticateWithPassword(password);
    if (isValid) {
      await _authService.markSessionVerified();
      widget.onAuthenticated?.call();
    } else {
      setState(() {
        _error = 'Incorrect password';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'user@example.com';

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // IconButton(
                  //   icon: const Icon(
                  //     Icons.arrow_back,
                  //     color: Color(0xFFBF7DCB),
                  //   ),
                  //   onPressed: () => Navigator.maybePop(context),
                  // ),
                  // const SizedBox.shrink(),
                  Text(
                    'Re-authenticate',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF800080), Color(0xFF4B0082)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock, color: Colors.white, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'Please re-authenticate to continue',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFCCCCFF)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      userEmail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFBF7DCB),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                enabled: !_isLoading,
                style: const TextStyle(color: Color(0xFFCCCCFF)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1a0f2e),
                  hintText: 'Enter your password',
                  hintStyle: const TextStyle(color: Color(0xFFBF7DCB)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                      color: _accent,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFD105FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFD105FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: !_isLoading ? (_) => _submit() : null,
              ),
              const SizedBox(height: 12),
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Expanded(
                  //   child: OutlinedButton(
                  //     style: OutlinedButton.styleFrom(
                  //       side: const BorderSide(color: Color(0xFFBF7DCB)),
                  //       foregroundColor: _accent,
                  //       padding: const EdgeInsets.symmetric(vertical: 14),
                  //     ),
                  //     onPressed: _isLoading
                  //         ? null
                  //         : () => Navigator.pushAndRemoveUntil(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (_) => const LoginScreen(),
                  //             ),
                  //             (route) => false,
                  //           ),
                  //     child: const Text(
                  //       'Use different account',
                  //       style: TextStyle(color: Color(0xFFBF7DCB)),
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFCCCCFF),
                                ),
                              ),
                            )
                          : const Text(
                              'Unlock',
                              style: TextStyle(color: Color(0xFFCCCCFF)),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Fingerprint auth not yet configured',
                            ),
                          ),
                        );
                      },
                child: Text(
                  'Use fingerprint',
                  style: TextStyle(color: _accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

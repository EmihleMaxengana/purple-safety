import 'dart:async';
import 'package:flutter/material.dart';
import 'package:purple_safety/emergency/emergency_manager.dart';
import 'package:purple_safety/emergency/sos_alert_service.dart';
import 'package:purple_safety/authentication/auth_service.dart';
import 'package:purple_safety/models/incident_model.dart';
import 'package:purple_safety/navigation/main_screen.dart';
import 'package:purple_safety/safety/safety_tools_screen.dart';

class DiscreetCalculatorScreen extends StatefulWidget {
  const DiscreetCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<DiscreetCalculatorScreen> createState() => _DiscreetCalculatorScreenState();
}

class _DiscreetCalculatorScreenState extends State<DiscreetCalculatorScreen> {
  // Calculator state
  String _display = '0';
  double? _firstNumber;
  String? _operator;
  bool _isNewNumber = true;
  bool _isSOSTriggered = false;
  bool _sosTriggeredOnThisSession = false;
  bool _showToolsHint = false;
  bool _isLoading = false;

  // Contacts (for emergency manager)
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = EmergencyManager().getCurrentContacts();
    setState(() {
      _contacts = contacts;
    });
  }

  void _pressNumber(String number) {
    if (_isNewNumber) {
      _display = number;
      _isNewNumber = false;
    } else {
      if (_display == '0' && number != '.') {
        _display = number;
      } else {
        _display += number;
      }
    }
    setState(() {});
  }

  void _pressOperator(String op) {
    if (_firstNumber == null || _operator == null) {
      _firstNumber = double.tryParse(_display) ?? 0;
    } else {
      _calculateResult();
    }
    _operator = op;
    _isNewNumber = true;
    _showToolsHint = false;
    setState(() {});
  }

  void _pressEquals() async {
    // If we haven't triggered SOS yet, trigger it now
    if (!_sosTriggeredOnThisSession) {
      await _triggerSOS();
      return;
    }

    // If SOS already triggered, do normal calculation
    _calculateResult();
  }

  Future<void> _triggerSOS() async {
    if (_isLoading) return;

    // Flash "SOS is triggered"
    setState(() {
      _display = '🚨 SOS is triggered';
      _isSOSTriggered = true;
      _isLoading = true;
    });

    // Get user info
    final user = AuthService().getCurrentUser();
    String userName = 'Someone';
    String userId = 'anonymous';

    if (user != null) {
      userId = user.uid;
      final userData = await AuthService().getUserData(user.uid);
      userName = userData?['name'] ?? 'A user';
    }

    // Use a default location (Pretoria, South Africa)
    final double lat = -25.7479;
    final double lng = 28.2293;

    try {
      await SOSAlertService.sendCommunitySOSAlert(
        userId: userId,
        userName: userName,
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      await _sendSMSFallback(userName, lat, lng);
    }

    // Activate emergency mode
    EmergencyManager().activateEmergencyMode(context, contacts: _contacts);

    // After SOS triggered, show answer and then hint
    setState(() {
      _sosTriggeredOnThisSession = true;
      _isSOSTriggered = false;
      _isLoading = false;
      _showToolsHint = true;
    });

    // Calculate the actual result if we have a calculation
    _calculateResult(withFlash: false);

    // After showing result, also show the hint
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _display = _display + '\npress 5 for tools';
        });
      }
    });
  }

  Future<void> _sendSMSFallback(String userName, double lat, double lng) async {
    if (_contacts.isEmpty) return;

    final locationLink = 'https://maps.google.com/?q=$lat,$lng';
    final message =
        '🚨 SOS ALERT: $userName needs immediate help!\n\n'
        '📍 Location: $locationLink\n\n'
        'This is an automated safety alert from Purple Safety.\n'
        'Please check on them or contact emergency services.';

    for (var contact in _contacts) {
      if (contact.phone != null && contact.phone!.isNotEmpty) {
        try {
          await SOSAlertService.sendSMS(
            phoneNumber: contact.phone!,
            message: message,
          );
        } catch (e) {
          debugPrint('SMS fallback failed for ${contact.name}: $e');
        }
      }
    }
  }

  void _calculateResult({bool withFlash = true}) {
    if (_firstNumber == null || _operator == null) {
      return;
    }

    final secondNumber = double.tryParse(_display) ?? 0;
    double result = 0;

    switch (_operator) {
      case '+':
        result = _firstNumber! + secondNumber;
        break;
      case '-':
        result = _firstNumber! - secondNumber;
        break;
      case '×':
        result = _firstNumber! * secondNumber;
        break;
      case '÷':
        if (secondNumber != 0) {
          result = _firstNumber! / secondNumber;
        } else {
          _display = 'Error';
          _firstNumber = null;
          _operator = null;
          _isNewNumber = true;
          setState(() {});
          return;
        }
        break;
      default:
        result = secondNumber;
    }

    String resultStr = result.toString();
    if (resultStr.endsWith('.0')) {
      resultStr = resultStr.substring(0, resultStr.length - 2);
    }

    setState(() {
      _display = resultStr;
      _firstNumber = null;
      _operator = null;
      _isNewNumber = true;

      if (_sosTriggeredOnThisSession && !_showToolsHint) {
        _showToolsHint = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _display = _display + '\npress 5 for tools';
            });
          }
        });
      }
    });
  }

  void _pressClear() {
    // If SOS was triggered on this session, pressing C exits discreet mode
    if (_sosTriggeredOnThisSession) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
      return;
    }

    // Normal clear behavior
    setState(() {
      _display = '0';
      _firstNumber = null;
      _operator = null;
      _isNewNumber = true;
      _showToolsHint = false;
    });
  }

  void _pressFive() {
    // If SOS triggered and we have the hint, navigate to tools
    if (_sosTriggeredOnThisSession && _showToolsHint) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SafetyToolsScreen(
            onCallEmergency: () {},
          ),
        ),
      );
      return;
    }

    // Otherwise, treat as normal number input
    _pressNumber('5');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: const Text(
          'Calculator',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomRight,
            height: 120,
            width: double.infinity,
            child: Text(
              _display,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
              maxLines: 3,
            ),
          ),
          const Divider(color: Colors.grey, thickness: 1),
          Expanded(
            child: Column(
              children: [
                _buildButtonRow(['C', '÷', '×', '-']),
                _buildButtonRow(['7', '8', '9', '+']),
                _buildButtonRow(['4', '5', '6', '=']),
                _buildButtonRow(['1', '2', '3', '0']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonRow(List<String> buttons) {
    return Expanded(
      child: Row(
        children: buttons.map((label) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: _buildButton(label),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(String label) {
    Color bgColor;
    Color textColor = Colors.white;

    if (label == 'C') {
      bgColor = Colors.red.shade700;
    } else if (label == '÷' || label == '×' || label == '-' || label == '+') {
      bgColor = Colors.orange.shade700;
    } else if (label == '=') {
      bgColor = Colors.green.shade700;
    } else {
      bgColor = Colors.grey.shade700;
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          _onButtonPressed(label);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _onButtonPressed(String label) {
    if (_isLoading) return;

    switch (label) {
      case 'C':
        _pressClear();
        break;
      case '÷':
        _pressOperator('÷');
        break;
      case '×':
        _pressOperator('×');
        break;
      case '-':
        _pressOperator('-');
        break;
      case '+':
        _pressOperator('+');
        break;
      case '=':
        _pressEquals();
        break;
      case '5':
        _pressFive();
        break;
      default:
        _pressNumber(label);
        break;
    }
  }
}
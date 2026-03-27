import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purple_safety/services/auth_service.dart';

class DiscreetModeScreen extends StatefulWidget {
  const DiscreetModeScreen({Key? key}) : super(key: key);

  @override
  State<DiscreetModeScreen> createState() => _DiscreetModeScreenState();
}

class _DiscreetModeScreenState extends State<DiscreetModeScreen> {
  bool _showChat = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _calculatorDisplay = '0';
  String _currentInput = '';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCalculatorTap(String value) {
    setState(() {
      if (value == 'C') {
        _currentInput = '';
        _calculatorDisplay = '0';
      } else if (value == '=') {
        try {
          final result = _evaluateExpression(_currentInput);
          _calculatorDisplay = result.toString();
          _currentInput = result.toString();
        } catch (e) {
          _calculatorDisplay = 'Error';
          _currentInput = '';
        }
      } else {
        _currentInput += value;
        _calculatorDisplay = _currentInput;
      }
    });
  }

  double _evaluateExpression(String expr) {
    final parts = expr.split(RegExp(r'[+\-*/]'));
    if (parts.length != 2) return 0;
    final double a = double.tryParse(parts[0]) ?? 0;
    final double b = double.tryParse(parts[1]) ?? 0;
    if (expr.contains('+')) return a + b;
    if (expr.contains('-')) return a - b;
    if (expr.contains('*')) return a * b;
    if (expr.contains('/')) return a / b;
    return 0;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final user = AuthService().getCurrentUser();
    String userName = 'Anonymous';
    if (user != null) {
      final userData = await AuthService().getUserData(user.uid);
      userName = userData?['name'] ?? 'Anonymous';
    }
    await FirebaseFirestore.instance.collection('discreet_chat').add({
      'userId': user?.uid ?? '',
      'userName': userName,
      'message': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _showChat ? _buildChatView() : _buildCalculatorView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatorView() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPress: _toggleChat,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _calculatorDisplay,
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          childAspectRatio: 1.5,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _calcButton('7'),
            _calcButton('8'),
            _calcButton('9'),
            _calcButton('/'),
            _calcButton('4'),
            _calcButton('5'),
            _calcButton('6'),
            _calcButton('*'),
            _calcButton('1'),
            _calcButton('2'),
            _calcButton('3'),
            _calcButton('-'),
            _calcButton('C'),
            _calcButton('0'),
            _calcButton('='),
            _calcButton('+'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Long press display to start discreet chat',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _calcButton(String label) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _onCalculatorTap(label),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    final user = AuthService().getCurrentUser();
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('discreet_chat')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data!.docs;
              return ListView.builder(
                controller: _scrollController,
                reverse: false,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  final isMe = data['userId'] == user?.uid;
                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.purple : Colors.blueGrey,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['userName'] ?? 'Unknown',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['message'],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type message...',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
              IconButton(
                icon: const Icon(Icons.calculate, color: Colors.white),
                onPressed: _toggleChat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

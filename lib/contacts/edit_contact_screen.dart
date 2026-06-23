import 'package:flutter/material.dart';
import 'package:purple_safety/home/home_screen.dart';
import 'package:purple_safety/safety/biometric_services.dart';

class EditContactScreen extends StatefulWidget {
  final Contact contact;
  final Function(Contact) onUpdate;
  final VoidCallback onDelete;

  const EditContactScreen({
    Key? key,
    required this.contact,
    required this.onUpdate,
    required this.onDelete,
  }) : super(key: key);

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late String _selectedRelationship;

  final List<String> _relationshipOptions = [
    'Family',
    'Friend',
    'Partner',
    'Colleague',
    'Neighbor',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _phoneController = TextEditingController(text: widget.contact.phone ?? '');
    _selectedRelationship = widget.contact.relationship ?? 'Family';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String rawNumber) {
    if (rawNumber.isEmpty) return '';
    String cleaned = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (!cleaned.startsWith('27') && cleaned.length <= 9) {
      cleaned = '27$cleaned';
    }
    return cleaned;
  }

  Future<void> _saveChanges() async {
    final authenticated = await BiometricService.authenticateWithUserPreference(
  context: context,
  reason: 'Authenticate to save contact changes',
);

    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication failed. Changes not saved.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final updatedContact = Contact(
      id: widget.contact.id,
      name: _nameController.text.trim(),
      initials: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()[0].toUpperCase()
          : '?',
      color: widget.contact.color,
      active: widget.contact.active,
      phone: _formatPhoneNumber(_phoneController.text.trim()),
      relationship: _selectedRelationship,
      socialLinks: {}, // WhatsApp removed
    );

    widget.onUpdate(updatedContact);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact updated successfully')),
    );
  }

  Future<void> _deleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${widget.contact.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authenticated = await BiometricService.authenticateWithUserPreference(
  context: context,
  reason: 'Authenticate to delete this contact',
);

      if (authenticated) {
        widget.onDelete();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Contact not deleted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Contact'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteContact,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full Name',
                  style: TextStyle(
                    color: Color(0xFFa078c0),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    icon: Icons.person,
                    hint: 'Full Name',
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Phone Number',
                  style: TextStyle(
                    color: Color(0xFFa078c0),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    icon: Icons.phone,
                    hint: 'Phone Number (for SMS)',
                  ).copyWith(
                    helperText: 'Format: 0712345678 or +27712345678',
                    helperStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Relationship',
                  style: TextStyle(
                    color: Color(0xFFa078c0),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedRelationship,
                    dropdownColor: const Color(0xFF2a1f3e),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.people,
                        color: Color(0xFFBF7DCB),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    items: _relationshipOptions.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRelationship = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData icon,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBF7DCB)),
      prefixIcon: Icon(icon, color: const Color(0xFFBF7DCB)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD105FF)),
      ),
    );
  }
}
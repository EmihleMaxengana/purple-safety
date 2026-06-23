import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:purple_safety/home/home_screen.dart';

class AddContactScreen extends StatefulWidget {
  final Function(Contact) onAdd;
  final int currentCount;

  const AddContactScreen({
    Key? key,
    required this.onAdd,
    required this.currentCount,
  }) : super(key: key);

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedRelationship;
  
  bool _isLoading = false;
  bool _showForm = false;

  final List<String> _relationshipOptions = [
    'Family',
    'Friend',
    'Partner',
    'Colleague',
    'Neighbor',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts permission is required to add contacts'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final dynamic contact = await _contactPicker.selectContact();
      
      if (contact != null) {
        List<String> phoneNumbers = _getPhoneNumbers(contact);
        
        if (phoneNumbers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This contact has no phone number'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        String selectedNumber = phoneNumbers.first;
        if (phoneNumbers.length > 1) {
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Select Phone Number'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: phoneNumbers.map((phone) {
                  return ListTile(
                    title: Text(phone),
                    subtitle: Text(
                      _isSouthAfricanNumber(phone) ? 'South African number' : 'International',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, phone),
                  );
                }).toList(),
              ),
            ),
          );
          if (result != null) {
            selectedNumber = result;
          } else {
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }
        
        // Set the phone number and show form
        _phoneController.text = selectedNumber;
        setState(() {
          _isLoading = false;
          _showForm = true;
        });
        
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error picking contact: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking contact: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> _getPhoneNumbers(dynamic contact) {
    List<String> numbers = [];
    try {
      if (contact.phoneNumbers != null) {
        if (contact.phoneNumbers is List) {
          for (var phone in contact.phoneNumbers) {
            if (phone != null) {
              String phoneStr = phone.toString();
              String cleaned = _cleanPhoneNumber(phoneStr);
              if (cleaned.isNotEmpty && !numbers.contains(cleaned)) {
                numbers.add(cleaned);
              }
            }
          }
        } else if (contact.phoneNumbers is String) {
          String cleaned = _cleanPhoneNumber(contact.phoneNumbers);
          if (cleaned.isNotEmpty) numbers.add(cleaned);
        }
      }
    } catch (e) {
      print('Error extracting phone numbers: $e');
    }
    return numbers;
  }

  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';
    
    if (cleaned.startsWith('0') && cleaned.length >= 10) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length == 9 && !cleaned.startsWith('27')) {
      cleaned = '27$cleaned';
    }
    return cleaned;
  }

  bool _isSouthAfricanNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return cleaned.startsWith('27') || (cleaned.length == 9 && !cleaned.startsWith('0'));
  }

  void _saveContact() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the contact name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number is required'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_selectedRelationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a relationship'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String formattedPhone = _formatPhoneNumber(_phoneController.text);

    final newContact = Contact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      initials: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()[0].toUpperCase()
          : '?',
      color: Colors.primaries[DateTime.now().millisecond % Colors.primaries.length],
      active: true,
      phone: formattedPhone,
      relationship: _selectedRelationship,
      socialLinks: {},
    );

    widget.onAdd(newContact);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newContact.name} added to trusted contacts'),
        backgroundColor: Colors.green,
      ),
    );
    
    // Go back to home screen
    Navigator.pop(context);
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _selectedRelationship = null;
    setState(() {
      _showForm = false;
      _isLoading = false;
    });
  }

  String _formatPhoneNumber(String rawNumber) {
    if (rawNumber.isEmpty) return '';
    String cleaned = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('0') && cleaned.length >= 10) {
      cleaned = cleaned.substring(1);
    }
    if (!cleaned.startsWith('27') && cleaned.length == 9) {
      cleaned = '27$cleaned';
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Trusted Contact'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_showForm) {
              _clearForm();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
          ),
        ),
        child: _showForm ? _buildForm() : _buildSelectionScreen(),
      ),
    );
  }

  Widget _buildSelectionScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.contacts,
              color: Colors.white38,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Add a Trusted Contact',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a contact from your device to auto-fill\nthe phone number, then enter their name manually',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.purple),
              )
            else
              ElevatedButton.icon(
                onPressed: _pickContact,
                icon: const Icon(Icons.contact_phone, color: Colors.white),
                label: const Text(
                  'Select from Contacts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Full Name *',
                hintStyle: TextStyle(color: Color(0xFFBF7DCB)),
                prefixIcon: Icon(Icons.person, color: Color(0xFFBF7DCB)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Phone number field
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Phone Number *',
                hintStyle: TextStyle(color: Color(0xFFBF7DCB)),
                prefixIcon: Icon(Icons.phone, color: Colors.green),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Relationship dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedRelationship,
              dropdownColor: const Color(0xFF2a1f3e),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Select Relationship *',
                hintStyle: TextStyle(color: Color(0xFFBF7DCB)),
                prefixIcon: Icon(Icons.people, color: Color(0xFFBF7DCB)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              items: _relationshipOptions.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRelationship = value;
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // Add contact button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveContact,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
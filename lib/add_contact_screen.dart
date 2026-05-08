import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:purple_safety/home/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  String? _selectedRelationship;
  
  // State variables
  bool _isLoading = false;
  String? _selectedPhoneNumber;
  bool _hasWhatsApp = false;

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
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      // Request permission
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

      // Pick contact
      final dynamic contact = await _contactPicker.selectContact();
      
      if (contact != null) {
        // Extract phone numbers
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
        
        // If multiple phone numbers, let user choose
        if (phoneNumbers.length == 1) {
          _setContactData(phoneNumbers.first);
        } else {
          _showPhoneNumberDialog(phoneNumbers);
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
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
              String cleaned = _cleanPhoneNumber(phone.toString());
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
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.isEmpty) return '';
    
    // Handle South African numbers
    if (cleaned.startsWith('0') && cleaned.length >= 10) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length == 9 && !cleaned.startsWith('27')) {
      cleaned = '27$cleaned';
    }
    return cleaned;
  }

  void _showPhoneNumberDialog(List<String> phoneNumbers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Phone Number'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: phoneNumbers.map((phone) {
              return ListTile(
                title: Text(phone),
                subtitle: Text(
                  _isSouthAfricanNumber(phone) ? 'South African number' : 'International',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _setContactData(phone);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  bool _isSouthAfricanNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return cleaned.startsWith('27') || (cleaned.length == 9 && !cleaned.startsWith('0'));
  }

  void _setContactData(String phoneNumber) {
    setState(() {
      _selectedPhoneNumber = phoneNumber;
      _phoneController.text = phoneNumber;
      _isLoading = false;
    });
    
    // Check if the number has WhatsApp
    _checkWhatsAppAvailability(phoneNumber);
    
    // Show form after selecting phone
    _showAddContactForm();
  }

  Future<void> _checkWhatsAppAvailability(String phoneNumber) async {
    // Clean the number for WhatsApp
    String whatsappNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (whatsappNumber.startsWith('0')) {
      whatsappNumber = whatsappNumber.substring(1);
    }
    if (!whatsappNumber.startsWith('27') && whatsappNumber.length == 9) {
      whatsappNumber = '27$whatsappNumber';
    }
    
    // Check if WhatsApp is installed and number is valid
    final whatsappUrl = 'https://wa.me/$whatsappNumber';
    final Uri uri = Uri.parse(whatsappUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        setState(() {
          _hasWhatsApp = true;
          _whatsappController.text = whatsappNumber;
        });
      } else {
        setState(() {
          _hasWhatsApp = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasWhatsApp = false;
      });
    }
  }

  void _showAddContactForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottomSheet) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1a0f2e),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Contact Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          Navigator.pop(context);
                          _clearForm();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Name field (manual entry)
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

                  // Phone number field (auto-filled from contact)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      enabled: false,
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

                  // WhatsApp field with detection status
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: _hasWhatsApp 
                          ? Border.all(color: Colors.green, width: 1)
                          : null,
                    ),
                    child: TextFormField(
                      controller: _whatsappController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'WhatsApp Number',
                        hintStyle: const TextStyle(color: Color(0xFFBF7DCB)),
                        prefixIcon: Icon(
                          Icons.chat, 
                          color: _hasWhatsApp ? Colors.green : Color(0xFFBF7DCB),
                        ),
                        suffixIcon: _hasWhatsApp
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : null,
                        helperText: _hasWhatsApp 
                            ? '✓ WhatsApp detected on this number' 
                            : 'Enter WhatsApp number (optional)',
                        helperStyle: TextStyle(
                          color: _hasWhatsApp ? Colors.green : Colors.white38,
                          fontSize: 10,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                        setStateBottomSheet(() {
                          _selectedRelationship = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Add contact button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _saveContact();
                        Navigator.pop(context);
                      },
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
                  const SizedBox(height: 12),
                  
                  // Reselect contact button
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _clearForm();
                      _pickContact();
                    },
                    child: const Text(
                      'Select a different contact',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _whatsappController.clear();
    _selectedRelationship = null;
    _selectedPhoneNumber = null;
    _hasWhatsApp = false;
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

  void _saveContact() {
    // Validate required fields
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
    String formattedWhatsApp = _formatPhoneNumber(_whatsappController.text);

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
      socialLinks: {
        if (formattedWhatsApp.isNotEmpty) 'whatsapp': formattedWhatsApp,
      },
    );

    widget.onAdd(newContact);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newContact.name} added to trusted contacts'),
        backgroundColor: Colors.green,
      ),
    );
    
    _clearForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Trusted Contact'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
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
        child: Center(
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
                  'Select a contact from your device to auto-fill\ntheir phone number, then add their name manually',
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
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickContact,
                        icon: const Icon(Icons.contact_phone, color: Colors.white),
                        label: const Text(
                          'Select Contact',
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
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          // Manual entry without selecting from contacts
                          _clearForm();
                          _showAddContactForm();
                        },
                        icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                        label: const Text(
                          'Enter manually',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
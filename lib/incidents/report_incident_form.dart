import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/incident_model.dart';
import '../services/incident_service.dart';

class ReportIncidentForm extends StatefulWidget {
  final bool isAnonymous;
  
  const ReportIncidentForm({Key? key, required this.isAnonymous}) : super(key: key);

  @override
  State<ReportIncidentForm> createState() => _ReportIncidentFormState();
}

class _ReportIncidentFormState extends State<ReportIncidentForm> {
  final _formKey = GlobalKey<FormState>();
  final IncidentService _incidentService = IncidentService();
  final ImagePicker _picker = ImagePicker();
  
  // User info
  String? _userName;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _alternativePhoneController = TextEditingController();
  
  // Incident info - REMOVED title, location, crime, accident, other
  String _selectedType = 'missingPerson'; // Only missingPerson and harassment
  final TextEditingController _descriptionController = TextEditingController();
  
  // Missing person fields
  final TextEditingController _missingPersonNameController = TextEditingController();
  final TextEditingController _missingPersonAgeController = TextEditingController();
  final TextEditingController _lastSeenLocationController = TextEditingController();
  File? _missingPersonImage;
  
  // Media
  List<File> _images = [];
  List<File> _videos = [];
  bool _isLoading = false;
  
  // Updated incident types - removed crime, accident, other
  final List<String> _incidentTypes = [
    'missingPerson',
    'harassment',
  ];
  
  final Map<String, String> _typeLabels = {
    'missingPerson': 'Missing Person',
    'harassment': 'Harassment',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _alternativePhoneController.dispose();
    _descriptionController.dispose();
    _missingPersonNameController.dispose();
    _missingPersonAgeController.dispose();
    _lastSeenLocationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!widget.isAnonymous) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        setState(() {
          _userName = userDoc.data()?['name'] ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(File(image.path));
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _videos.add(File(video.path));
      });
    }
  }

  Future<void> _pickMissingPersonImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _missingPersonImage = File(image.path);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _videos.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      String userId = widget.isAnonymous ? 'anonymous' : (user?.uid ?? 'anonymous');
      
      IncidentType type = IncidentType.values.firstWhere(
        (e) => e.toString() == 'IncidentType.$_selectedType',
        orElse: () => IncidentType.missingPerson,
      );
      
      // Get location (using geocoding to get location name from current position)
      String locationName = 'Unknown location';
      double? latitude;
      double? longitude;
      
      try {
        // You'll need to get current location here
        // For now, we'll use placeholder or ask user
        locationName = _lastSeenLocationController.text.isNotEmpty 
            ? _lastSeenLocationController.text 
            : 'Location not specified';
      } catch (e) {
        locationName = 'Location not specified';
      }
      
      final incident = Incident(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: widget.isAnonymous ? null : _userName,
        userPhone: _phoneController.text,
        alternativePhone: _alternativePhoneController.text.isNotEmpty ? _alternativePhoneController.text : null,
        isAnonymous: widget.isAnonymous,
        title: _selectedType == 'missingPerson' 
            ? 'MISSING: ${_missingPersonNameController.text}' 
            : 'Harassment Report',
        description: _descriptionController.text,
        type: type,
        missingPersonName: _selectedType == 'missingPerson' ? _missingPersonNameController.text : null,
        missingPersonAge: _selectedType == 'missingPerson' && _missingPersonAgeController.text.isNotEmpty
            ? int.tryParse(_missingPersonAgeController.text)
            : null,
        lastSeenLocation: _selectedType == 'missingPerson' ? _lastSeenLocationController.text : null,
        missingPersonImageUrl: _missingPersonImage != null ? _missingPersonImage!.path : null,
        location: locationName,
        latitude: latitude,
        longitude: longitude,
        imageUrls: [], // Will be uploaded to storage in production
        videoUrls: [], // Will be uploaded to storage in production
        timestamp: DateTime.now(),
      );
      
      await _incidentService.createIncident(incident);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAnonymous ? 'Report Anonymously' : 'Report Incident'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info section
                const Text(
                  'Your Contact Information',
                  style: TextStyle(
                    color: Color(0xFFa078c0),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                
                if (!widget.isAnonymous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFFBF7DCB)),
                        const SizedBox(width: 8),
                        Text(
                          _userName ?? 'Loading...',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                
                if (!widget.isAnonymous) const SizedBox(height: 12),
                
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number *',
                  hint: 'Your contact number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                _buildTextField(
                  controller: _alternativePhoneController,
                  label: 'Alternative Phone Number',
                  hint: 'Optional secondary contact number',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                
                // Incident type dropdown - Only Missing Person and Harassment
                const Text(
                  'Incident Type *',
                  style: TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    dropdownColor: const Color(0xFF2a1f3e),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    items: _incidentTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_typeLabels[type]!),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedType = value!),
                  ),
                ),
                const SizedBox(height: 16),
                
                // REMOVED: Title field
                
                // Missing person section
                if (_selectedType == 'missingPerson') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Missing Person Details',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        _buildTextField(
                          controller: _missingPersonNameController,
                          label: 'Full Name *',
                          hint: 'Name of the missing person',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter missing person name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        _buildTextField(
                          controller: _missingPersonAgeController,
                          label: 'Age',
                          hint: 'Age of missing person',
                          icon: Icons.cake,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        
                        _buildTextField(
                          controller: _lastSeenLocationController,
                          label: 'Last Seen Location *',
                          hint: 'Where were they last seen?',
                          icon: Icons.location_searching,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter last seen location';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        const Text(
                          'Photo of Missing Person',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickMissingPersonImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                            ),
                            child: _missingPersonImage != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _missingPersonImage!,
                                          width: double.infinity,
                                          height: 150,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () => setState(() => _missingPersonImage = null),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate, color: Colors.orange, size: 40),
                                        SizedBox(height: 8),
                                        Text(
                                          'Tap to add photo',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // REMOVED: Location field
                
                // Description
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description *',
                  hint: 'Describe what happened in detail',
                  icon: Icons.description,
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Evidence section (for harassment only)
                if (_selectedType == 'harassment') ...[
                  const Text(
                    'Evidence (Optional)',
                    style: TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, color: Color(0xFFBF7DCB)),
                                  SizedBox(height: 4),
                                  Text('Add Photo', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickVideo,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam, color: Color(0xFFBF7DCB)),
                                  SizedBox(height: 4),
                                  Text('Add Video', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_images.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_images[index], width: 80, height: 80, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
                  if (_videos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.videocam, color: Colors.white, size: 30),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeVideo(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Submit Report',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFBF7DCB)),
            prefixIcon: Icon(icon, color: const Color(0xFFBF7DCB)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
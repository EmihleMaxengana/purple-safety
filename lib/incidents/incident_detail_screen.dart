import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/incident_model.dart';
import '../services/incident_service.dart';

class IncidentDetailScreen extends StatefulWidget {
  final Incident incident;
  
  const IncidentDetailScreen({Key? key, required this.incident}) : super(key: key);

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final IncidentService _incidentService = IncidentService();
  final TextEditingController _commentController = TextEditingController();
  bool _isCommentingAnonymous = false;
  bool _isLoading = false;
  bool _isMarkingFound = false;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.incident.commentCount;
    _listenToCommentCount();
  }

  void _listenToCommentCount() {
    _incidentService.getComments(widget.incident.id).listen((comments) {
      if (mounted) {
        setState(() {
          _commentCount = comments.length;
        });
      }
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _incidentService.addComment(
        incidentId: widget.incident.id,
        comment: _commentController.text.trim(),
        isAnonymous: _isCommentingAnonymous,
      );
      
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment added')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // FIXED: Share using XFile like the tools page
  Future<void> _shareIncident() async {
    String shareMessage;
    
    if (widget.incident.type == IncidentType.missingPerson) {
      shareMessage = '''
🚨🚨 URGENT: MISSING PERSON 🚨🚨

🔍 NAME: ${widget.incident.missingPersonName ?? 'Unknown'}
📏 AGE: ${widget.incident.missingPersonAge ?? 'Unknown'}
📍 LAST SEEN: ${widget.incident.lastSeenLocation ?? 'Unknown'}
📅 REPORTED: ${_formatTime(widget.incident.timestamp)}

📝 DETAILS:
${widget.incident.description}

📞 CONTACT: ${widget.incident.isAnonymous ? 'Report via Purple Safety app' : (widget.incident.userPhone ?? 'Report via Purple Safety app')}

---
Please share this post to help find them.
Download Purple Safety app to help your community.
''';
    } else {
      shareMessage = '''
⚠️ INCIDENT REPORT ⚠️

📌 TYPE: ${_getTypeLabel().toUpperCase()}
📅 WHEN: ${_formatTime(widget.incident.timestamp)}
📍 WHERE: ${widget.incident.location}

📝 DETAILS:
${widget.incident.description}

---
Please stay safe. Report incidents via Purple Safety app.
''';
    }
    
    // Share using XFile (same as tools page)
    if (widget.incident.type == IncidentType.missingPerson && 
        widget.incident.missingPersonImageUrl != null && 
        widget.incident.missingPersonImageUrl!.isNotEmpty) {
      try {
        final imageFile = File(widget.incident.missingPersonImageUrl!);
        if (await imageFile.exists()) {
          await Share.shareXFiles(
            [XFile(widget.incident.missingPersonImageUrl!)],
            text: shareMessage,
            subject: 'Missing Person Alert - Purple Safety',
          );
        } else {
          await Share.share(shareMessage, subject: 'Purple Safety Alert');
        }
      } catch (e) {
        await Share.share(shareMessage, subject: 'Purple Safety Alert');
      }
    } else {
      await Share.share(shareMessage, subject: 'Purple Safety Alert');
    }
    
    await _incidentService.shareIncident(widget.incident.id);
  }

  Future<void> _callReporter() async {
    final phone = widget.incident.userPhone;
    if (phone != null && phone.isNotEmpty) {
      final Uri url = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  Future<void> _markAsFound() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Found'),
        content: const Text(
          'Has this person been found and is safe?\n\n'
          'This post will be marked as "FOUND" and removed from the community feed after 2 hours.\n\n'
          'Everyone in the community will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Yes, Mark as Found'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isMarkingFound = true);
      
      try {
        await _incidentService.markAsFound(widget.incident.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Person marked as found! Everyone has been notified.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isMarkingFound = false);
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPoster = currentUser?.uid == widget.incident.userId;
    final showFoundButton = widget.incident.type == IncidentType.missingPerson && 
                            !widget.incident.isFound && 
                            isPoster;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          if (showFoundButton)
            IconButton(
              icon: _isMarkingFound
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle, color: Colors.green),
              onPressed: _isMarkingFound ? null : _markAsFound,
              tooltip: 'Mark as Found',
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareIncident,
            tooltip: 'Share',
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getTypeColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getTypeColor().withOpacity(0.5)),
                      ),
                      child: Text(
                        _getTypeLabel(),
                        style: TextStyle(color: _getTypeColor()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      widget.incident.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Reported ${_formatTime(widget.incident.timestamp)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    
                    // Missing person image
                    if (widget.incident.type == IncidentType.missingPerson && 
                        widget.incident.missingPersonImageUrl != null &&
                        widget.incident.missingPersonImageUrl!.isNotEmpty)
                      Container(
                        height: 180,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(widget.incident.missingPersonImageUrl!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[800],
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_outline, color: Colors.white54, size: 40),
                                      SizedBox(height: 8),
                                      Text(
                                        'No photo available',
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    
                    // Missing person details
                    if (widget.incident.type == IncidentType.missingPerson)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_search, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'MISSING PERSON',
                                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (widget.incident.missingPersonName != null)
                              _buildInfoRow('Name:', widget.incident.missingPersonName!),
                            if (widget.incident.missingPersonAge != null)
                              _buildInfoRow('Age:', widget.incident.missingPersonAge.toString()),
                            if (widget.incident.lastSeenLocation != null)
                              _buildInfoRow('Last seen:', widget.incident.lastSeenLocation!),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    // Evidence images for harassment
                    if (widget.incident.imageUrls.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Evidence Images',
                              style: TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.incident.imageUrls.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(widget.incident.imageUrls[index]),
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.broken_image, color: Colors.white54),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const Text(
                      'Description',
                      style: TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.incident.description,
                      style: const TextStyle(color: Colors.white70, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Location',
                      style: TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.incident.location,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Reported by',
                      style: TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          widget.incident.isAnonymous ? 'Anonymous' : (widget.incident.userName ?? 'User'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    if (widget.incident.userPhone != null && !widget.incident.isAnonymous) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _callReporter,
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              widget.incident.userPhone!,
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    
                    // Dynamic comment count
                    Row(
                      children: [
                        Icon(Icons.comment, color: const Color(0xFFBF7DCB), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$_commentCount comments',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.share, color: const Color(0xFFBF7DCB), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.incident.shareCount} shares',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Comments',
                      style: TextStyle(color: Color(0xFFa078c0), fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    
                    StreamBuilder<List<IncidentComment>>(
                      stream: _incidentService.getComments(widget.incident.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No comments yet. Be the first to comment.',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                          );
                        }
                        
                        final comments = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.isAnonymous ? 'Anonymous' : (comment.userName ?? 'User'),
                                        style: const TextStyle(
                                          color: Color(0xFFBF7DCB),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatTime(comment.timestamp),
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    comment.comment,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1a0f2e),
                border: Border(top: BorderSide(color: Colors.purple.withOpacity(0.3))),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isLoading ? null : _addComment,
                        icon: const Icon(Icons.send, color: Color(0xFFBF7DCB)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _isCommentingAnonymous,
                        onChanged: (value) {
                          setState(() {
                            _isCommentingAnonymous = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF6A1B9A),
                      ),
                      const Text(
                        'Comment anonymously',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor() {
    switch (widget.incident.type) {
      case IncidentType.missingPerson:
        return Colors.orange;
      case IncidentType.harassment:
        return Colors.purple;
      case IncidentType.crime:
        return Colors.red;
      case IncidentType.accident:
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel() {
    switch (widget.incident.type) {
      case IncidentType.missingPerson:
        return 'Missing Person';
      case IncidentType.harassment:
        return 'Harassment';
      case IncidentType.crime:
        return 'Crime';
      case IncidentType.accident:
        return 'Accident';
      default:
        return 'Other';
    }
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purple_safety/messaging/dm_service.dart';
import 'package:purple_safety/messaging/chat_screen.dart';
import 'package:purple_safety/trip/full_map_screen.dart';
import 'package:purple_safety/services/storage_service.dart';
import 'package:purple_safety/contacts/firestore_service.dart';
import 'package:purple_safety/models/incident_model.dart';

class DMScreen extends StatefulWidget {
  final String? shareTripId;

  const DMScreen({Key? key, this.shareTripId}) : super(key: key);

  @override
  State<DMScreen> createState() => _DMScreenState();
}

class _DMScreenState extends State<DMScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allUsers = [];
  List<String> _selectedRecipients = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> _communityUsers = [];
  List<Map<String, dynamic>> _filteredCommunityUsers = [];
  TextEditingController _searchController = TextEditingController();
  bool _isLoadingCommunity = true;

  final FirestoreService _firestoreService = FirestoreService();
  
  StreamSubscription? _contactsSubscription;
  
  // Unread count for inbox tab badge
  int _unreadCount = 0;
  StreamSubscription<int>? _unreadCountSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCommunityData();
    _listenToTrustedContacts();
    _listenToUnreadCount();
  }

  @override
  void dispose() {
    _contactsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _unreadCountSubscription = DmService
        .getUnreadCountStream(user.uid)
        .listen((count) {
          if (mounted) {
            setState(() {
              _unreadCount = count;
            });
          }
        });
  }

  void _listenToTrustedContacts() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _allUsers = [];
      });
      return;
    }

    _isLoading = true;

    _contactsSubscription = _firestoreService
        .getContactsStream(user.uid)
        .listen((contacts) {
          final List<Map<String, dynamic>> trustedContacts = contacts.map((contact) {
            return {
              'id': contact.id,
              'name': contact.name,
              'email': contact.phone ?? 'No phone number',
            };
          }).toList();

          _loadSavedRecipients(trustedContacts);
        });
  }

  Future<void> _loadSavedRecipients(List<Map<String, dynamic>> trustedContacts) async {
    final saved = await DmService.getSelectedRecipients();
    
    final validSavedIds = trustedContacts.map((c) => c['id'] as String).toSet();
    final filteredSaved = saved.where((id) => validSavedIds.contains(id)).toList();
    
    if (filteredSaved.length != saved.length) {
      await DmService.saveSelectedRecipients(filteredSaved);
    }

    if (mounted) {
      setState(() {
        _allUsers = trustedContacts;
        _selectedRecipients = filteredSaved;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCommunityData() async {
    final users = await DmService.getAllUsersWithProfile();
    setState(() {
      _communityUsers = users;
      _filteredCommunityUsers = users;
      _isLoadingCommunity = false;
    });
  }

  void _filterCommunity(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCommunityUsers = _communityUsers;
      } else {
        _filteredCommunityUsers = _communityUsers
            .where((user) =>
                user['name'].toLowerCase().contains(query.toLowerCase()) ||
                user['email'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _shareTripId() async {
    if (widget.shareTripId == null) return;
    if (_selectedRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one contact to share')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final senderName = await DmService.getUserName(user.uid);

    for (var recipientId in _selectedRecipients) {
      await DmService.sendTripIdMessage(
        recipientUserId: recipientId,
        senderName: senderName,
        tripId: widget.shareTripId!,
        senderId: user.uid,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Trip ID sent to ${_selectedRecipients.length} contact(s)')),
    );
    Navigator.pop(context);
  }

  Future<void> _saveSelection() async {
    await DmService.saveSelectedRecipients(_selectedRecipients);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Auto-share recipients saved')),
    );
  }

  void _followTrip(String tripId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullMapScreen(initialTripId: tripId),
      ),
    );
  }

  void _copyTripId(String tripId) {
    Clipboard.setData(ClipboardData(text: tripId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip ID copied'), duration: Duration(seconds: 1)),
    );
  }

  void _showUserProfile(Map<String, dynamic> user) {
    final hasNextOfKin = user['nextOfKinName'] != null && user['nextOfKinName'].toString().isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1a0f2e),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.purple,
                  child: Text(
                    user['name'][0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'],
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user['email'],
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildProfileInfoRow('Gender', user['gender']),
            const SizedBox(height: 12),
            if (hasNextOfKin) ...[
              const Text(
                'Next of Kin',
                style: TextStyle(color: Color(0xFFa078c0), fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildProfileInfoRow('Name', user['nextOfKinName']),
              const SizedBox(height: 8),
              _buildProfileInfoRow('Relationship', user['nextOfKinRelation']),
            ] else ...[
              const Text(
                'No next of kin information available',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        recipientId: user['id'],
                        recipientName: user['name'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Send Message', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'Not set',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _openChat(String recipientId, String recipientName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await DmService.markAllFromSenderAsRead(user.uid, recipientId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientId: recipientId,
          recipientName: recipientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final bool isShareMode = widget.shareTripId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0e0718),
      appBar: AppBar(
        title: Text(isShareMode ? 'Share Trip with Contacts' : 'Direct Messages',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Auto-share'),
            const Tab(text: 'Community'),
            // ============================================================
            // INBOX TAB WITH BADGE
            // ============================================================
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Inbox'),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ============================================================
          // AUTO-SHARE TAB
          // ============================================================
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.purple))
              : Container(
                  color: const Color(0xFF0e0718),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFF1a0f2e),
                        child: Text(
                          isShareMode
                              ? 'Select your trusted contacts to receive this Trip ID:'
                              : 'Select trusted contacts who will automatically receive your Trip ID when you start sharing.',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      if (_allUsers.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline, color: Colors.white38, size: 64),
                                const SizedBox(height: 16),
                                const Text(
                                  'No trusted contacts yet',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add contacts from the Home screen first',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _allUsers.length,
                            itemBuilder: (context, index) {
                              final userItem = _allUsers[index];
                              final isSelected = _selectedRecipients.contains(userItem['id']);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF6A1B9A).withOpacity(0.3) : const Color(0xFF1a0f2e),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: CheckboxListTile(
                                  title: Text(userItem['name'],
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                  subtitle: Text(userItem['email'], style: const TextStyle(color: Colors.white70)),
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedRecipients.add(userItem['id']);
                                      } else {
                                        _selectedRecipients.remove(userItem['id']);
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFFD105FF),
                                  checkColor: Colors.white,
                                  tileColor: Colors.transparent,
                                ),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isShareMode ? _shareTripId : _saveSelection,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6A1B9A),
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  isShareMode ? 'Share' : 'Save Auto-share List',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_allUsers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${_allUsers.length} trusted contact${_allUsers.length > 1 ? 's' : ''} available',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),

          // ============================================================
          // COMMUNITY TAB
          // ============================================================
          _isLoadingCommunity
              ? const Center(child: CircularProgressIndicator(color: Colors.purple))
              : Container(
                  color: const Color(0xFF0e0718),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search by name or email...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            filled: true,
                            fillColor: const Color(0xFF1a0f2e),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: _filterCommunity,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _filteredCommunityUsers.length,
                          itemBuilder: (context, index) {
                            final userItem = _filteredCommunityUsers[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1a0f2e),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  child: Text(
                                    userItem['name'][0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(userItem['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                subtitle: Text(userItem['email'], style: const TextStyle(color: Colors.white70)),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                                onTap: () => _showUserProfile(userItem),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

          // ============================================================
          // INBOX TAB - FIXED: Shows latest message (sent or received)
          // ============================================================
          Container(
            color: const Color(0xFF0e0718),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DmService.getMessagesStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.purple));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nSend a message from the Community tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                // ============================================================
                // FIXED: Group by conversation partner and get the MOST RECENT message
                // ============================================================
                final Map<String, Map<String, dynamic>> groupedMessages = {};
                final Map<String, String> conversationNames = {};
                final Map<String, bool> conversationReadStatus = {};
                
                for (var msg in messages) {
                  final senderId = msg['senderId'] as String;
                  final currentUserId = user.uid;
                  
                  // Determine the conversation partner ID (the other person)
                  String conversationId;
                  if (senderId == currentUserId) {
                    // If I sent it, we need to get the recipient ID
                    // For messages sent by me, the senderId is me, but we need to know who I sent it to
                    // Since we don't store recipientId in the DM document, we use senderId as the key
                    // and the senderName will be the other person's name
                    conversationId = senderId;
                  } else {
                    conversationId = senderId;
                  }
                  
                  // Store the sender name for display
                  final senderName = msg['senderName'] ?? 'Unknown';
                  
                  // Only keep the most recent message per conversation
                  if (!groupedMessages.containsKey(conversationId)) {
                    groupedMessages[conversationId] = msg;
                    conversationNames[conversationId] = senderName;
                    conversationReadStatus[conversationId] = msg['read'] ?? false;
                  } else {
                    // Compare timestamps - keep the newer one
                    final existingTimestamp = groupedMessages[conversationId]?['timestamp'] as Timestamp?;
                    final newTimestamp = msg['timestamp'] as Timestamp?;
                    
                    if (newTimestamp != null && existingTimestamp != null) {
                      if (newTimestamp.toDate().isAfter(existingTimestamp.toDate())) {
                        groupedMessages[conversationId] = msg;
                        conversationNames[conversationId] = senderName;
                        conversationReadStatus[conversationId] = msg['read'] ?? false;
                      }
                    }
                  }
                }

                // Convert to list and sort by timestamp (newest first)
                final groupedList = groupedMessages.entries.toList();
                groupedList.sort((a, b) {
                  final timestampA = a.value['timestamp'] as Timestamp?;
                  final timestampB = b.value['timestamp'] as Timestamp?;
                  if (timestampA == null && timestampB == null) return 0;
                  if (timestampA == null) return 1;
                  if (timestampB == null) return -1;
                  return timestampB.toDate().compareTo(timestampA.toDate());
                });

                return ListView.builder(
                  itemCount: groupedList.length,
                  itemBuilder: (context, index) {
                    final entry = groupedList[index];
                    final conversationId = entry.key;
                    final msg = entry.value;
                    final displayName = conversationNames[conversationId] ?? 'Unknown';
                    final isConversationRead = conversationReadStatus[conversationId] ?? false;
                    
                    final isTripShare = msg['type'] == 'trip_share';
                    final isSentByMe = msg['senderId'] == user.uid;

                    // ============================================================
                    // MESSAGE PREVIEW - Shows the latest message (sent or received)
                    // ============================================================
                    String previewText = '';
                    if (isTripShare) {
                      previewText = '📌 Shared a Trip ID with you';
                    } else if (msg['type'] == 'image') {
                      previewText = '📷 Image';
                    } else if (msg['type'] == 'video') {
                      previewText = '🎬 Video';
                    } else if (msg['type'] == 'audio') {
                      previewText = '🎵 Audio';
                    } else {
                      previewText = msg['message'] ?? '';
                    }

                    // Show "You: " prefix if we sent it
                    if (isSentByMe) {
                      previewText = 'You: $previewText';
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        // ============================================================
                        // DIFFERENT BACKGROUND COLOR FOR UNREAD (like alerts section)
                        // ============================================================
                        color: isConversationRead 
                            ? const Color(0xFF1a0f2e)  // Read - normal dark
                            : const Color(0xFF2a1f3e), // Unread - darker (like alerts)
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isConversationRead 
                              ? Colors.purple.withOpacity(0.1) 
                              : Colors.purple.withOpacity(0.3),
                        ),
                      ),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.purple,
                              child: Text(
                                (displayName.isNotEmpty ? displayName[0] : '?').toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            // ============================================================
                            // RED DOT NEXT TO UNREAD MESSAGES (only if not sent by me)
                            // ============================================================
                            if (!isConversationRead && !isSentByMe)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isConversationRead ? FontWeight.w500 : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          previewText,
                          style: TextStyle(
                            color: isConversationRead ? Colors.white70 : Colors.white,
                            fontWeight: isConversationRead ? FontWeight.normal : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isTripShare
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                                    onPressed: () => _copyTripId(msg['tripId']),
                                    tooltip: 'Copy Trip ID',
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    onPressed: () => _followTrip(msg['tripId']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ],
                              )
                            : null,
                        onTap: () {
                          // Get the other person's ID for the chat
                          String otherPersonId = conversationId;
                          String otherPersonName = displayName;
                          
                          // If I sent the message and conversationId is my ID, 
                          // we need to find the recipient ID from the message
                          // For now, use the senderId if it's not me, otherwise use conversationId
                          if (isSentByMe) {
                            // For messages sent by me, the recipient ID might be stored elsewhere
                            // We'll use the senderId from the message if it's not me
                            // In this case, conversationId might be the senderId (which is me)
                            // So we need to use the senderId from the message
                            final msgSenderId = msg['senderId'] ?? '';
                            if (msgSenderId != user.uid) {
                              otherPersonId = msgSenderId;
                              otherPersonName = msg['senderName'] ?? 'Unknown';
                            }
                          }
                          
                          _openChat(otherPersonId, otherPersonName);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
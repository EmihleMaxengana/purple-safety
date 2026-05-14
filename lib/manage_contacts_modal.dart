import 'package:flutter/material.dart';
import 'package:purple_safety/home/home_screen.dart';
import 'package:purple_safety/edit_contact_screen.dart';

class ManageContactsModal extends StatefulWidget {
  final List<Contact> contacts;
  final Function(String) onDelete;
  final Function(Contact) onUpdate;

  const ManageContactsModal({
    Key? key,
    required this.contacts,
    required this.onDelete,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<ManageContactsModal> createState() => _ManageContactsModalState();
}

class _ManageContactsModalState extends State<ManageContactsModal> {
  late List<Contact> _contacts;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.contacts);
  }

  @override
  void didUpdateWidget(covariant ManageContactsModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local contacts when widget contacts change
    if (oldWidget.contacts != widget.contacts) {
      setState(() {
        _contacts = List.from(widget.contacts);
      });
    }
  }

  void _handleDelete(String contactId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete this contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Call the delete function
      await widget.onDelete(contactId);
      
      // Immediately update local list
      setState(() {
        _contacts.removeWhere((contact) => contact.id == contactId);
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _handleEdit(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditContactScreen(
          contact: contact,
          onUpdate: (updatedContact) async {
            await widget.onUpdate(updatedContact);
            // Update local list
            setState(() {
              final index = _contacts.indexWhere((c) => c.id == updatedContact.id);
              if (index != -1) {
                _contacts[index] = updatedContact;
              }
            });
          },
          onDelete: () => _handleDelete(contact.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1a0f2e),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Manage Trusted Contacts',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(
                      child: Text(
                        'No contacts yet.\nTap the + button to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white24),
                      itemBuilder: (context, index) {
                        final c = _contacts[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: c.color.withOpacity(0.5),
                                child: Text(
                                  c.initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Contact info - Expanded with flexible text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 2),
                                    if (c.relationship != null)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people,
                                            color: Colors.white70,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              c.relationship!,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone,
                                          color: Colors.white70,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            c.phone ?? 'No phone number',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (c.socialLinks.containsKey('whatsapp'))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.chat,
                                              color: Colors.green,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                c.socialLinks['whatsapp']!,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              
                              // Action buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    onPressed: () => _handleEdit(c),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => _handleDelete(c.id),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
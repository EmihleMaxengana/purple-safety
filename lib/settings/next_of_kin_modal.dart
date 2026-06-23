// lib/next_of_kin_modal.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> showNextOfKinModal(
  BuildContext context,
  String userId,
  String userName,
) async {
  // Fetch next of kin data from Firestore
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  if (!userDoc.exists) return;

  final data = userDoc.data()!;
  final nextOfKinName = data['nextOfKinName'] as String?;
  final nextOfKinPhone = data['nextOfKinPhone'] as String?;
  final nextOfKinRelation = data['nextOfKinRelation'] as String?;
  final nextOfKinAltPhone = data['nextOfKinAltPhone'] as String?;

  final hasNextOfKin = (nextOfKinName != null && nextOfKinName.isNotEmpty);

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
                backgroundColor: Colors.purple,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 32),
          const Text(
            'Next of Kin Information',
            style: TextStyle(
              color: Color(0xFFa078c0),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (hasNextOfKin) ...[
            _buildInfoRow(Icons.person, 'Name', nextOfKinName!),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.people, 'Relationship', nextOfKinRelation ?? 'Not specified'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Phone', _formatPhone(nextOfKinPhone)),
            if (nextOfKinAltPhone != null && nextOfKinAltPhone.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.phone_android, 'Alternative', _formatPhone(nextOfKinAltPhone)),
            ],
          ] else ...[
            const Icon(Icons.person_off, color: Colors.white38, size: 48),
            const SizedBox(height: 8),
            const Text(
              'No next of kin information available',
              style: TextStyle(color: Colors.white54),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget _buildInfoRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, color: const Color(0xFFBF7DCB), size: 20),
      const SizedBox(width: 12),
      SizedBox(
        width: 100,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    ],
  );
}

String _formatPhone(String? phone) {
  if (phone == null || phone.isEmpty) return 'Not provided';
  String cleaned = phone.replaceAll(RegExp(r'\D'), '');
  if (cleaned.startsWith('27') && cleaned.length == 11) {
    cleaned = cleaned.substring(2);
  }
  if (cleaned.length == 9) {
    return '+27 ${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5)}';
  }
  return phone;
}
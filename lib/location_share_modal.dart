import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationShareModal extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const LocationShareModal({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
  }) : super(key: key);

  String get _locationLink => 'https://www.google.com/maps?q=$latitude,$longitude';
  String get _shareMessage => '📍 I\'m at $locationName\n\n$_locationLink';

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _locationLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location link copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  void _shareViaSystem(BuildContext context) {
    Share.share(_shareMessage, subject: 'My Location - Purple Safety');
    Navigator.pop(context);
  }

  void _shareViaWhatsApp(BuildContext context) async {
    final url = 'https://wa.me/?text=${Uri.encodeComponent(_shareMessage)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp is not installed'),
          backgroundColor: Colors.red,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _shareViaMessenger(BuildContext context) async {
    final url = 'https://m.me/?text=${Uri.encodeComponent(_shareMessage)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messenger is not installed'),
          backgroundColor: Colors.red,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _shareViaTwitter(BuildContext context) async {
    final url = 'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_shareMessage)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Twitter/X is not installed'),
          backgroundColor: Colors.red,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _shareViaInstagram(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _locationLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied! Open Instagram and paste in stories or DMs'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.pop(context);
  }

  void _shareViaTelegram(BuildContext context) async {
    final url = 'https://t.me/share/url?url=${Uri.encodeComponent(_locationLink)}&text=${Uri.encodeComponent(_shareMessage)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telegram is not installed'),
          backgroundColor: Colors.red,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _shareViaSMS(BuildContext context) async {
    final url = 'sms:?body=${Uri.encodeComponent(_shareMessage)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open SMS'),
          backgroundColor: Colors.red,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1a0f2e),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Share Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),

          // Location preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        locationName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Copy Link button
          _buildShareOption(
            icon: Icons.link,
            color: Colors.blue,
            title: 'Copy Link',
            subtitle: 'Copy location URL to clipboard',
            onTap: () => _copyLink(context),
          ),
          const SizedBox(height: 12),

          // Share via row title
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Share via',
              style: TextStyle(
                color: Color(0xFFa078c0),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Social media icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSocialIcon(
                icon: Icons.chat,
                label: 'WhatsApp',
                color: Colors.green,
                onTap: () => _shareViaWhatsApp(context),
              ),
              _buildSocialIcon(
                icon: Icons.message,
                label: 'Messenger',
                color: Colors.blue,
                onTap: () => _shareViaMessenger(context),
              ),
              _buildSocialIcon(
                icon: Icons.abc,
                label: 'X',
                color: Colors.white,
                onTap: () => _shareViaTwitter(context),
              ),
              _buildSocialIcon(
                icon: Icons.camera_alt,
                label: 'Instagram',
                color: Colors.purple,
                onTap: () => _shareViaInstagram(context),
              ),
              _buildSocialIcon(
                icon: Icons.send,
                label: 'Telegram',
                color: Colors.blue,
                onTap: () => _shareViaTelegram(context),
              ),
              _buildSocialIcon(
                icon: Icons.sms,
                label: 'SMS',
                color: Colors.green,
                onTap: () => _shareViaSMS(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // More apps button
          TextButton.icon(
            onPressed: () => _shareViaSystem(context),
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            label: const Text(
              'More apps...',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
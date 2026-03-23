import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyModeScreen extends StatelessWidget {
  const EmergencyModeScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> services = const [
    {'name': 'Police', 'number': '10111', 'icon': Icons.local_police},
    {'name': 'Ambulance', 'number': '10177', 'icon': Icons.local_hospital},
    {'name': 'Fire', 'number': '10177', 'icon': Icons.fire_hydrant},
    {
      'name': 'Gender-Based Violence Command Centre',
      'number': '0800 428 428',
      'icon': Icons.help_center,
    },
    {'name': 'Childline', 'number': '0800 055 555', 'icon': Icons.child_care},
    {
      'name': 'Suicide Crisis Line',
      'number': '0800 567 567',
      'icon': Icons.heart_broken,
    },
    {
      'name': 'National AIDS Helpline',
      'number': '0800 012 322',
      'icon': Icons.medical_services,
    },
  ];

  Future<void> _callNumber(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0e0718), Color(0xFF100c1f)],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return Card(
            color: const Color(0xFF1a0f2e),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.purple.withOpacity(0.3)),
            ),
            child: ListTile(
              leading: Icon(
                service['icon'],
                color: Colors.purple.shade300,
                size: 28,
              ),
              title: Text(
                service['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                service['number'],
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: const Icon(Icons.phone, color: Colors.green),
              onTap: () => _callNumber(service['number']),
            ),
          );
        },
      ),
    );
  }
}

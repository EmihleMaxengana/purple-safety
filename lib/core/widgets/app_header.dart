import 'package:flutter/material.dart';

AppBar buildAppHeader({
  VoidCallback? onAvatarPressed,
  int unreadAlertsCount = 0,
  VoidCallback? onNotificationPressed,
  VoidCallback? onDMTap,
}) {
  return AppBar(
    backgroundColor: const Color(0xFF6A1B9A),
    elevation: 0,
    leading: null,
    automaticallyImplyLeading: false,
    centerTitle: false,
    titleSpacing: 0,
    title: Container(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  alignment: Alignment.center,
                  child: const Text(
                    'PS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Purple Safety',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Your Personal Safety Companion',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      // DM Icon
      if (onDMTap != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
            onPressed: onDMTap,
            tooltip: 'Direct Messages',
          ),
        ),
      // Notification Icon with badge
      if (onNotificationPressed != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white, size: 20),
                onPressed: onNotificationPressed,
              ),
              if (unreadAlertsCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      // User Avatar
      if (onAvatarPressed != null)
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 12),
          child: InkWell(
            onTap: onAvatarPressed,
            borderRadius: BorderRadius.circular(16),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ),
    ],
  );
}
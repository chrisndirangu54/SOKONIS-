import 'package:flutter/material.dart';
import '../services/notification_service.dart'; // Adjust path as needed
import '../models/notification_model.dart'; // Model for Notification

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  NotificationScreenState createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  final NotificationService _notificationService = NotificationService();
  int unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // Method to load notifications from the NotificationService
  void _loadNotifications() async {
    try {
      List<NotificationModel> notifications =
          (await _notificationService.getNotifications())
              .cast<NotificationModel>();
      setState(() {
        _notifications = notifications;
        unreadNotificationsCount = notifications.where((n) => !n.isRead).length;
      });
    } catch (e) {
      // Handle any errors in fetching notifications
      print('Error loading notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  key: Key(_notifications[index]
                      .id), // Assuming each notification has a unique ID
                  onDismissed: (direction) {
                    _removeNotification(index);
                  },
                  background: Container(color: Colors.red),
                  child: ListTile(
                    title: Text(_notifications[index].title),
                    subtitle: Text(_notifications[index].body),
                    onTap: () {
                      _handleNotificationTap(_notifications[index]);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _removeNotification(index),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // Handle tapping a notification to show more details or navigate
  void _handleNotificationTap(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(notification.title),
          content: Text(notification.body),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Remove notification from the list and potentially update backend or storage
  void _removeNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
    // Optionally: Implement removal logic from backend/storage via NotificationService
  }
}

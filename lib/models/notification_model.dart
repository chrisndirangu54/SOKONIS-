class NotificationModel {
  final String id;
  final String title;
  final String body;

  bool isRead;

  NotificationModel(
      {required this.id,
      required this.title,
      required this.body,
      required this.isRead});
}

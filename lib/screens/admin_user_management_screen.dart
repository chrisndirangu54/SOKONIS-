import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserManagementScreen extends StatelessWidget {
  const AdminUserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var users = snapshot.data!.docs;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index];
              var userData = user.data() as Map<String, dynamic>;

              // Determine the status and actions available for each user
              bool isRider = userData['isRider'] ?? false;
              bool isAttendant = userData['isAttendant'] ?? false;

              return ListTile(
                title: Text(userData['name']),
                subtitle: Text(userData['email']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isRider) ...[
                      ElevatedButton(
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.id)
                              .update({'isRider': true}).then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${userData['name']} is now a rider!'),
                              ),
                            );
                          });
                        },
                        child: const Text('Promote to Rider'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!isAttendant) ...[
                      ElevatedButton(
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.id)
                              .update({'isAttendant': true}).then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${userData['name']} is now an attendant!'),
                              ),
                            );
                          });
                        },
                        child: const Text('Promote to Attendant'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isRider || isAttendant) ...[
                      ElevatedButton(
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.id)
                              .update({
                            'isRider': false,
                            'isAttendant': false,
                          }).then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${userData['name']} has been demoted.'),
                              ),
                            );
                          });
                        },
                        child: const Text('Demote'),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

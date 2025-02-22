import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grocerry/models/group_buy_model.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/services/groupbuy_service.dart';
import 'package:share_plus/share_plus.dart';

class GroupBuyPage extends StatelessWidget {
  GroupBuyService? groupBuyService;
  final User user;
  final LatLng userLocation;

  late BuildContext context;

  GroupBuyPage({
    super.key,
    this.groupBuyService,
    required this.user,
    required this.userLocation,
    required String groupBuyId,
  });
                      void _joinGroupBuyWithLink(String link) {
                        // Implement the logic to join a group buy using the provided link
                        // For example, you might parse the link to get the group buy ID and then join the group buy
                        final groupBuyId = _parseGroupBuyIdFromLink(link);
                        if (groupBuyId != null) {
                          groupBuyService?.joinGroupBuy(groupBuyId, user).then((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Successfully joined the group buy!')),
                            );
                          }).catchError((e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to join the group buy: $e')),
                            );
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid group buy link')),
                          );
                        }
                      }
                      
                      String? _parseGroupBuyIdFromLink(String link) {
                        // Implement the logic to parse the group buy ID from the link
                        // For example, you might use a regular expression to extract the ID from the link
                        final uri = Uri.tryParse(link);
                        if (uri != null && uri.pathSegments.isNotEmpty) {
                          return uri.pathSegments.last;
                        }
                        return null;
                      }
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Group Buys'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showCreateGroupBuyDialog(),
        ),
        // Add this button to join with a link
        IconButton(
          icon: const Icon(Icons.link),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Join Group Buy with Link'),
                content: TextField(
                  decoration: const InputDecoration(labelText: 'Enter Group Buy Link'),
                  onSubmitted: (link) {
                    Navigator.of(context).pop();
                    _joinGroupBuyWithLink(link);
                  },
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: const Text('Join'),
                    onPressed: () {
                      String? link = (context.findRenderObject() as EditableText).controller?.text;
                      if (link != null && link.isNotEmpty) {
                        Navigator.of(context).pop();
                        _joinGroupBuyWithLink(link);
                      }
                      

                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
      body: StreamBuilder<List<GroupBuy>>(
        stream: groupBuyService?.fetchActiveGroupBuys(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No active group buys available.'));
          }

          final activeGroupBuys = snapshot.data!;

          return ListView.builder(
            itemCount: activeGroupBuys.length,
            itemBuilder: (context, index) {
              final groupBuy = activeGroupBuys[index];
              return _buildGroupBuyCard(groupBuy);
            },
          );
        },
      ),
    );
  }

  Widget _buildGroupBuyCard(GroupBuy groupBuy) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Host: ${groupBuy.hostId}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Start Time: ${groupBuy.startTime}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'End Time: ${groupBuy.endTime}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => _joinGroupBuy(context, groupBuy),
                  child: const Text('Join Group Buy'),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareGroupBuy(groupBuy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _joinGroupBuy(BuildContext context, GroupBuy groupBuy) {
    groupBuyService?.joinGroupBuy(groupBuy.id, user).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined the group buy!')),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join the group buy: $e')),
      );
    });
  }

void _showCreateGroupBuyDialog() {
  String? productId;
  double? basePrice;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Create Group Buy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Product ID'),
                onChanged: (value) => productId = value,
              ),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Base Price'),
                onChanged: (value) => basePrice = double.tryParse(value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (productId != null && basePrice != null) {
                String newGroupId = await createGroupBuy(productId!, user, basePrice!);
                Navigator.of(context).pop(); // Close dialog
                _shareGroupBuy(GroupBuy(
                  id: newGroupId,
                  hostId: user,
                  currentPrice: basePrice!,
                  minPrice: basePrice!,
                  startTime: DateTime.now(),
                  endTime: DateTime.now().add(const Duration(minutes: 5)), userLocation: userLocation,
                ));
              }
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
}

Future<String> createGroupBuy(String productId, User hostId, double basePrice) async {
  final groupId = FirebaseFirestore.instance.collection('GroupBuy').doc().id;
  final startTime = DateTime.now();
  final endTime = startTime.add(const Duration(minutes: 5));

  final groupBuy = GroupBuy(
    id: groupId,
    hostId: hostId,
    currentPrice: basePrice,
    minPrice: basePrice,
    startTime: startTime,
    endTime: endTime, userLocation: userLocation,
  );

  // Assuming groupBuyService.createGroupBuy takes three arguments
  await groupBuyService?.createGroupBuy(hostId, userLocation);
  return groupId;
}

void _shareGroupBuy(GroupBuy groupBuy) {
  final shareText = 'Join my Group Buy! Use this link: ${Uri.base.toString()}groupbuy/${groupBuy.id}';
  Share.share(shareText);
}
}
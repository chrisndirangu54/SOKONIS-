import 'package:flutter/material.dart';
import 'package:grocerry/services/notification_service.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../screens/order_details_screen.dart';

class PendingDeliveriesScreen extends StatelessWidget {
  const PendingDeliveriesScreen({super.key});

Future<void> _sendPaymentNotification(String orderId, String customerId) async {
  // Assuming you have a notification service
  final NotificationService notificationService = NotificationService();
  
  await notificationService.sendNotification(
    to: customerId,
    title: 'Payment Required',
    body: 'Please confirm payment for order $orderId.',
    data: {
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'orderId': orderId,
      'action': 'confirm_payment', // Additional data to handle specific action
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Deliveries'),
      ),
      body: orderProvider.pendingOrders.isEmpty
          ? const Center(child: Text('No pending deliveries'))
          : ListView.builder(
              itemCount: orderProvider.pendingOrders.length,
              itemBuilder: (context, index) {
                final order = orderProvider.pendingOrders[index];
                return ListTile(
                  title: Text(order.orderId),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${order.status}'),
                      const SizedBox(height: 4),
                      Text('Customer Address: ${order.user.address}'),
                      if (order.user.liveLocation != null)
                        Text('Customer Location: ${order.user.liveLocation}'),
                      if (order.riderLocation != null && order.status == 'On the way')
                        Text('Rider Location: ${order.riderLocation}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (user.isRider) ...[
                            if (order.status == 'Ready for Delivery') ...[
                              if (order.paymentMethod == 'COD') ...[
                                ElevatedButton(
                                  onPressed: () async {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Payment Method'),
                                        content: const Text('How was the payment handled?'),
                                        actions: [
                                          TextButton(
                                            child: const Text('Customer Paid Cash'),
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              orderProvider.updateOrderStatus(
                                                  order.orderId, 'Delivered');
                                            },
                                          ),
                                          TextButton(
                                            child: const Text('Prompt Customer to Pay'),
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await _sendPaymentNotification(order.orderId, order.user.id);
                                              orderProvider.updateOrderStatus(
                                                  order.orderId, 'Payment Confirmation Pending');
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Payment Confirmation'),
                                                  content: const Text(
                                                      'Please confirm payment has been received from the customer.'),
                                                  actions: [
                                                    TextButton(
                                                      child: const Text('Payment Received'),
                                                      onPressed: () async {
                                                        orderProvider.updateOrderStatus(
                                                            order.orderId, 'Delivered');
                                                        Navigator.of(context).pop();
                                                      },
                                                    ),
                                                    TextButton(
                                                      child: const Text('Cancel'),
                                                      onPressed: () => Navigator.of(context).pop(),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Text('Handle Payment'),
                                ),
                              ] else ...[
                                ElevatedButton(
                                  onPressed: () {
                                    orderProvider.updateOrderStatus(order.orderId, 'Delivered');
                                  },
                                  child: const Text('Confirm Delivery'),
                                ),
                              ],
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  orderProvider.updateOrderStatus(order.orderId, 'Not Delivered');
                                },
                                child: const Text('Was Not Delivered'),
                              ),
                            ],
                          ] else if (!user.isRider) ...[
                            if (order.status == 'Pending') ...[
                              ElevatedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm'),
                                      content: const Text(
                                          'Are you sure you want to mark this order as preparing?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    orderProvider.updateOrderStatus(order.orderId, 'Preparing');
                                  }
                                },
                                child: const Text('Confirm Preparing'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm'),
                                      content: const Text(
                                          'Are you sure you want to mark this order as ready for delivery?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    orderProvider.updateOrderStatus(
                                        order.orderId, 'Ready for Delivery');
                                  }
                                },
                                child: const Text('Confirm Ready for Delivery'),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(orderId: order.orderId),
                    ));
                  },
                );
              },
            ),
    );
  }
}
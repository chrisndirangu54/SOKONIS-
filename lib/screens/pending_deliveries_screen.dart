import 'package:flutter/material.dart';
import 'package:grocerry/services/notification_service.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../screens/order_details_screen.dart';
import '../providers/cart_provider.dart'; // Import CartProvider

class PendingDeliveriesScreen extends StatelessWidget {
  const PendingDeliveriesScreen({super.key});

  Future<void> _sendPaymentNotification(String orderId, String customerId) async {
    final NotificationService notificationService = NotificationService();
    await notificationService.sendNotification(
      to: customerId,
      title: 'Payment Required',
      body: 'Please confirm payment for order $orderId.',
      data: {
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'orderId': orderId,
        'action': 'confirm_payment',
      },
    );
  }

  // Helper method to show attendant confirmation dialog
  Future<void> showAttendantConfirmationDialog(
      BuildContext context, Map<String, dynamic> item, CartProvider cart) async {
    final NotificationService notificationService = NotificationService();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Item: ${item['productId']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Quantity: ${item['quantity']}'),
            Text('Notes: ${item['notes']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              cart.handleAttendantDecision(item['productId'], 'confirm');
              await notificationService.sendNotification(
                to: Provider.of<UserProvider>(context, listen: false).user.id ?? '',
                title: 'Item Confirmed',
                body: 'Item ${item['productId']} with notes "${item['notes']}" has been confirmed.',
                data: {'itemId': item['productId']},
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirm'),
          ),
          TextButton(
            onPressed: () async {
              cart.handleAttendantDecision(item['productId'], 'decline');
              await notificationService.sendNotification(
                to: Provider.of<UserProvider>(context, listen: false).user.id ?? '',
                title: 'Item Declined',
                body: 'Item ${item['productId']} with notes "${item['notes']}" has been declined.',
                data: {'itemId': item['productId']},
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () {
              cart.handleAttendantDecision(item['productId'], 'chargeMore');
              Navigator.of(ctx).pop();
              _showPriceAdjustmentDialog(context, item, cart);
            },
            child: const Text('Charge More'),
          ),
        ],
      ),
    );
  }

  // Helper method for price adjustment
  Future<void> _showPriceAdjustmentDialog(
      BuildContext context, Map<String, dynamic> item, CartProvider cart) async {
    final NotificationService notificationService = NotificationService();
    TextEditingController priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Price'),
        content: TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'New Price'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              double? newPrice = double.tryParse(priceController.text);
              if (newPrice != null) {
                cart.items[item['productId']]!.price = newPrice;
                cart.handleAttendantDecision(item['productId'], 'confirmed');
                await notificationService.sendNotification(
                  to: Provider.of<UserProvider>(context, listen: false).user.id ?? '',
                  title: 'Price Adjusted',
                  body: 'Item ${item['productId']} price adjusted to \$$newPrice due to notes "${item['notes']}".',
                  data: {'itemId': item['productId'], 'newPrice': newPrice.toString()},
                );
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context); // Add CartProvider
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
                      // Check for items with notes in the order
                      if (order.items.any((item) => item.notes?.isNotEmpty == true)) ...[
                        ElevatedButton(
                          onPressed: () async {
                            for (var item in order.items.where((i) => i.notes?.isNotEmpty == true)) {
                              await showAttendantConfirmationDialog(context, {
                                'productId': item.product,
                                'quantity': item.quantity,
                                'notes': item.notes,
                              }, cartProvider);
                            }
                          },
                          child: const Text('Review Items with Notes'),
                        ),
                      ],
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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grocerry/screens/meal_planing_screen.dart';
import 'package:grocerry/screens/order_details_screen.dart';
import 'package:grocerry/screens/subscription_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/order_provider.dart';
import 'package:flutter/services.dart'; // For copying to clipboard
import 'package:share/share.dart';
import 'package:grocerry/screens/health_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  get user => null;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    final List<String> userBadges = ["Moran", "Warrior", "Shujaa", "Mfalme"];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              displayBadges(userBadges),
              _buildProfileHeader(context, userProvider),
              const SizedBox(height: 20),
              _buildProfileUpdateSection(context, userProvider),
              const SizedBox(height: 10),
              _buildProfilePictureSection(context, userProvider),
              const SizedBox(height: 20),
              _buildReferralSection(
                  context, userProvider), // New Referral Section
              const SizedBox(height: 20),
              _buildOrdersSection(context, orderProvider),
              const SizedBox(height: 20),
              buildSubscriptionScreen(context),
              const SizedBox(height: 20),
              buildMealPlanScreen(context),
              const SizedBox(height: 20),
              buildHealthScreen(context),
              const SizedBox(height: 20),
              const RiderSection(),
              redeemPointsWidget(context, user, orderProvider),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProvider userProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${userProvider.name}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${userProvider.email}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Address: ${userProvider.address}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Phone: ${userProvider.contact}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (userProvider.lastLoginDate != null)
              Text(
                'Last Login: ${userProvider.lastLoginDate}',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 8),
            if (userProvider.profilePictureUrl.isNotEmpty)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(userProvider.profilePictureUrl),
              )
            else
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileUpdateSection(
      BuildContext context, UserProvider userProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () {
                _showUpdateProfileDialog(context, userProvider);
              },
              child: const Text('Update Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection(
      BuildContext context, UserProvider userProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () {
                userProvider.selectAndUploadProfilePicture(user);
              },
              child: const Text('Change Profile Picture'),
            ),
            const SizedBox(height: 10),
            if (userProvider.isUploadingProfilePicture)
              const CircularProgressIndicator()
            else if (userProvider.profilePictureUploadError.isNotEmpty)
              Text(
                'Error: ${userProvider.profilePictureUploadError}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection(
      BuildContext context, UserProvider userProvider) {
    final referralCode = userProvider.referralCode;
    final referralLink = 'https://yourapp.com/register?ref=$referralCode';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invite Friends',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (referralCode!.isNotEmpty) ...[
              Text(
                'Your Referral Code: $referralCode',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: referralLink));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Referral link copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Referral Link'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  _shareReferralLink(context, referralLink);
                },
                icon: const Icon(Icons.share),
                label: const Text('Share Referral Link'),
              ),
            ] else
              const Text(
                'You do not have a referral code yet.',
                style: TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersSection(
      BuildContext context, OrderProvider orderProvider) {
    final userProvider = Provider.of<UserProvider>(context);

    // Filter orders to only show those of the current user
    final userOrders = orderProvider.pendingOrders
        .where((order) =>
            order.user == userProvider.id && order.status == 'pending')
        .toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Orders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: userOrders.length,
              itemBuilder: (context, index) {
                final order = userOrders[index];
                return ListTile(
                  title: Text(order.orderId),
                  subtitle:
                      Text('Price: \$${order.totalAmount.toStringAsFixed(2)}'),
                  trailing: Text('Status: ${order.status}'),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(
                        orderId: order.orderId,
                      ),
                    ));
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHealthScreen(BuildContext context) {
    return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glassmorphism Card about Health
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color:
                        Colors.white.withOpacity(0.1), // Semi-transparent color
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  margin:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stay Healthy!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Manage your health effectively by keeping track of your diet and fitness.',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      // Button to navigate to health screen
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                const HealthDietInsightsPage(),
                          ));
                        },
                        child: const Text('Health Dashboard'),
                      ),
                    ],
                  ),
                ),
              ],
            )));
  }

  Widget buildMealPlanScreen(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple Card for Meal Plan
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white, // Solid white background
                border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1), // Subtle border
              ),
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meal Plans!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Black text color
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Explore our curated meal plans to suit your dietary needs.',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors
                            .black54), // Slightly faded black for subtitle
                  ),
                  const SizedBox(height: 10),
                  // Button to navigate to meal plan screen
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const MealPlanningScreen(),
                      ));
                    },
                    child: const Text('View Meal Plans'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget redeemPointsWidget(BuildContext context, String user, orderProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Redeem Your Points for Coupons'),
            ElevatedButton(
              onPressed: () =>
                  orderProvider.redeemPointsForCoupon(context, user, 100),
              child: const Text('Redeem 100 Points for Ksh.{500} Coupon'),
            ),
            ElevatedButton(
              onPressed: () =>
                  orderProvider.redeemPointsForCoupon(context, user, 200),
              child: const Text('Redeem 200 Points for Ksh.{1000} Coupon'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSubscriptionScreen(BuildContext context) {
    return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simple Card for Subscription
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white, // Solid white background
                    border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1), // Subtle border
                  ),
                  padding: const EdgeInsets.all(20),
                  margin:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscribe Now!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black, // Black text color
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Unlock premium features and get personalized plans.',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors
                                .black54), // Slightly faded black for subtitle
                      ),
                      const SizedBox(height: 10),
                      // Button to navigate to subscription screen
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                SubscriptionScreen(user: user),
                          ));
                        },
                        child: const Text('Go to Subscription'),
                      ),
                    ],
                  ),
                ),
              ],
            )));
  }

  void _showUpdateProfileDialog(
      BuildContext context, UserProvider userProvider) {
    final nameController = TextEditingController(text: userProvider.name);
    final emailController = TextEditingController(text: userProvider.email);
    final addressController = TextEditingController(text: userProvider.address);
    final contactController = TextEditingController(text: userProvider.contact);
    final pinLocationController =
        TextEditingController(text: userProvider.pinLocation);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Profile'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: pinLocationController,
                  decoration: const InputDecoration(labelText: 'Pin Location'),
                  onSubmitted: (pinLocation) {
                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);
                    userProvider.fetchpinLocation(pinLocation);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                userProvider.updateProfile(
                    name: '', email: '', contact: '', address: '');
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _shareReferralLink(BuildContext context, String referralLink) {
    Share.share('Join me on this app using my referral link: $referralLink');
  }
}

class RiderSection extends StatelessWidget {
  const RiderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    // Only show this widget if the user is a rider
    if (!userProvider.user.isRider) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rider Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('Available for Delivery'),
              value: userProvider.user.isAvailableForDelivery,
              onChanged: (bool value) {
                // Update user availability for delivery
                userProvider.updateUser(
                  userProvider.user.copyWith(isAvailableForDelivery: value),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(value
                          ? 'You are now available for delivery'
                          : 'You are now unavailable for delivery')),
                );
              },
            ),
            if (userProvider.user.liveLocation != null)
              ListTile(
                title: const Text('Current Location'),
                subtitle: Text(
                    'Lat: ${userProvider.user.liveLocation?.latitude}, Long: ${userProvider.user.liveLocation?.longitude}'),
                trailing: const Icon(Icons.location_on),
                onTap: () {
                  // Handle view location logic, e.g., open a map
                },
              ),
          ],
        ),
      ),
    );
  }
}

class BadgeIcons {
  // Map for badge icons
  static Map<String, IconData> badgeIconMap = {
    "Moran": Icons.shield, // Using shield icon for Moran
    "Warrior": Icons.shield, // Using shield icon for Warrior
    "Shujaa": Icons.shield, // Using shield icon for Shujaa
    "Mfalme": Icons.shield, // Using shield icon for Mfalme
  };

  // Map for badge colors
  static Map<String, Color> badgeColorMap = {
    "Moran": Colors.blue, // Color for Moran
    "Warrior": Colors.red, // Color for Warrior
    "Shujaa": Colors.green, // Color for Shujaa
    "Mfalme": Colors.purple, // Color for Mfalme
  };
}

Widget displayBadges(List<String> badges) {
  return Wrap(
    spacing: 10,
    children: badges.map((badge) {
      return Chip(
        backgroundColor: BadgeIcons
            .badgeColorMap[badge], // Set background color based on badge
        label: Row(
          children: [
            Icon(
              BadgeIcons
                  .badgeIconMap[badge], // Get the corresponding icon (shield)
              size: 18, // Adjust size as needed
              color: Colors.white, // Set icon color (optional)
            ),
            const SizedBox(width: 5), // Spacing between icon and text
            Text(
              badge,
              style: const TextStyle(
                  color: Colors.white), // Set text color (optional)
            ),
          ],
        ),
      );
    }).toList(),
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:grocerry/main.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/screens/group_buy_page.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:flutter_map/flutter_map.dart';
import 'package:grocerry/models/group_buy_model.dart';
import 'package:grocerry/providers/wallet_provider.dart';
import 'package:grocerry/screens/meal_planing_screen.dart';
import 'package:grocerry/screens/order_details_screen.dart';
import 'package:grocerry/screens/subscription_screen.dart';
import 'package:grocerry/screens/topup_form.dart';
import 'package:grocerry/services/groupbuy_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/order_provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:grocerry/screens/health_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Neomorphic Switch Widget
class NeomorphicSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;
  final Color activeColor;
  final Color inactiveColor;
  final Color backgroundColor;

  const NeomorphicSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 60.0,
    this.height = 30.0,
    this.activeColor = Colors.green,
    this.inactiveColor = Colors.grey,
    this.backgroundColor =
        const Color.fromARGB(255, 245, 245, 245), // Matches lightPrimaryColor
  });

  @override
  _NeomorphicSwitchState createState() => _NeomorphicSwitchState();
}

class _NeomorphicSwitchState extends State<NeomorphicSwitch> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onChanged(!widget.value);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade400.withOpacity(0.5),
              offset: const Offset(2, 2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              offset: const Offset(-2, -2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment:
                  widget.value ? Alignment.centerRight : Alignment.centerLeft,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Container(
                width: widget.height - 4,
                height: widget.height - 4,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      widget.value ? widget.activeColor : widget.inactiveColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final List<String> userBadges = ["Moran", "Warrior", "Shujaa", "Mfalme"];
  late UserProvider userProvider;
  late OrderProvider orderProvider;
  late WalletProvider walletProvider;
  late GroupBuyService groupBuyService;
  bool _isLightMode = true; // Default to light mode

  final Map<String, int> _sectionUsageCount = {
    '_buildProfileHeader': 10,
    '_buildProfileUpdateSection': 8,
    '_buildProfilePictureSection': 7,
    '_buildReferralSection': 6,
    '_buildOrdersSection': 9,
    'buildSubscriptionScreen': 5,
    'buildMealPlanScreen': 4,
    'buildHealthScreen': 3,
    'RiderSection': 2,
    'redeemPointsWidget': 5,
    'buildGroupBuyAccessWidget': 4,
    '_buildTopUpSection': 6,
    '_buildThemeToggle': 1, // New section for theme toggle
  };

  late Map<String, Function> _sectionWidgets;

  @override
  void initState() {
    super.initState();
    userProvider = Provider.of<UserProvider>(context, listen: false);
    orderProvider = Provider.of<OrderProvider>(context, listen: false);
    walletProvider = Provider.of<WalletProvider>(context, listen: false);
    groupBuyService = GroupBuyService(FirebaseFirestore.instance, null);
    _loadThemePreference();

    _sectionWidgets = {
      'displayBadges': (BuildContext context, List<String> userBadges) =>
          displayBadges(userBadges),
      '_buildProfileHeader':
          (BuildContext context, UserProvider userProvider) =>
              _buildProfileHeader(context, userProvider),
      '_buildProfileUpdateSection':
          (BuildContext context, UserProvider userProvider) =>
              _buildProfileUpdateSection(context, userProvider),
      '_buildProfilePictureSection':
          (BuildContext context, UserProvider userProvider) =>
              _buildProfilePictureSection(context, userProvider),
      '_buildReferralSection':
          (BuildContext context, UserProvider userProvider) =>
              _buildReferralSection(context, userProvider),
      '_buildOrdersSection':
          (BuildContext context, OrderProvider orderProvider) =>
              _buildOrdersSection(context, orderProvider),
      'buildSubscriptionScreen': (BuildContext context) =>
          buildSubscriptionScreen(context),
      'buildMealPlanScreen': (BuildContext context) =>
          buildMealPlanScreen(context),
      'buildHealthScreen': (BuildContext context) => buildHealthScreen(context),
      'RiderSection': (BuildContext context) => _buildRiderSection(context),
      'redeemPointsWidget':
          (BuildContext context, dynamic user, OrderProvider orderProvider) =>
              redeemPointsWidget(context, user, orderProvider),
      'buildGroupBuyAccessWidget': (BuildContext context,
              GroupBuyService groupBuyService,
              dynamic user,
              dynamic userLocation) =>
          buildGroupBuyAccessWidget(
              context, groupBuyService, user, userLocation),
      '_buildTopUpSection':
          (BuildContext context, WalletProvider walletProvider) =>
              _buildTopUpSection(context, walletProvider),
      '_buildThemeToggle': (BuildContext context) => _buildThemeToggle(context),
    };
  }

  // Load theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLightMode = prefs.getBool('isLightMode') ?? true;
    });
  }

  // Save theme preference to SharedPreferences
  Future<void> _saveThemePreference(bool isLightMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLightMode', isLightMode);
  }

  Widget _buildSectionWidget(String methodName, BuildContext context,
      [List<dynamic>? extraArgs]) {
    try {
      final Function? builder = _sectionWidgets[methodName];
      if (builder != null) {
        setState(() {
          _sectionUsageCount[methodName] =
              (_sectionUsageCount[methodName] ?? 0) + 1;
        });
        return Function.apply(builder, [context, ...?extraArgs]);
      }
    } catch (e) {
      debugPrint('Error invoking method $methodName: $e');
    }
    return const Text('Section not implemented');
  }

  Widget _buildFrequentlyUsedSection(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    final groupBuyService = GroupBuyService(FirebaseFirestore.instance, null);

    final sortedSections = _sectionUsageCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequently Used',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...sortedSections.map((entry) {
              final methodName = entry.key;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    _buildSectionWidget(
                      methodName,
                      context,
                      _getSectionArgs(methodName, userProvider, orderProvider,
                          walletProvider, groupBuyService),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getSectionArgs(
      String methodName,
      UserProvider userProvider,
      OrderProvider orderProvider,
      WalletProvider walletProvider,
      GroupBuyService groupBuyService) {
    switch (methodName) {
      case 'displayBadges':
        return [userBadges];
      case '_buildProfileHeader':
      case '_buildProfileUpdateSection':
      case '_buildProfilePictureSection':
      case '_buildReferralSection':
        return [userProvider];
      case '_buildOrdersSection':
        return [orderProvider];
      case 'redeemPointsWidget':
        return [userProvider.user, orderProvider];
      case 'buildGroupBuyAccessWidget':
        return [groupBuyService, userProvider.user, userProvider.pinLocation];
      case '_buildTopUpSection':
        return [walletProvider];
      default:
        return [];
    }
  }

  // Theme toggle section
  Widget _buildThemeToggle(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Light Mode',
              style: TextStyle(fontSize: 18),
            ),
            NeomorphicSwitch(
              value: _isLightMode,
              onChanged: (value) {
                setState(() {
                  _isLightMode = value;
                  _saveThemePreference(value);
                });
                // Trigger a rebuild of the app with the new theme
                // This requires the MaterialApp to listen to this change, which we'll handle in main.dart
                RestartWidget.restartApp(context);
              },
              activeColor: lightMainColor,
              inactiveColor: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSectionWidget('_buildFrequentlyUsedSection', context),
            const SizedBox(height: 20),
            _buildSectionWidget('displayBadges', context, [userBadges]),
            const SizedBox(height: 20),
            _buildSectionWidget('_buildProfileHeader', context, [userProvider]),
            const SizedBox(height: 20),
            _buildSectionWidget(
                '_buildProfileUpdateSection', context, [userProvider]),
            const SizedBox(height: 10),
            _buildSectionWidget(
                '_buildProfilePictureSection', context, [userProvider]),
            const SizedBox(height: 20),
            _buildSectionWidget(
                '_buildReferralSection', context, [userProvider]),
            const SizedBox(height: 20),
            _buildSectionWidget(
                '_buildOrdersSection', context, [orderProvider]),
            const SizedBox(height: 20),
            _buildSectionWidget('buildSubscriptionScreen', context),
            const SizedBox(height: 20),
            _buildSectionWidget('buildMealPlanScreen', context),
            const SizedBox(height: 20),
            _buildSectionWidget('buildHealthScreen', context),
            const SizedBox(height: 20),
            _buildSectionWidget('RiderSection', context),
            const SizedBox(height: 20),
            _buildSectionWidget('redeemPointsWidget', context,
                [userProvider.user, orderProvider]),
            const SizedBox(height: 20),
            _buildSectionWidget('buildGroupBuyAccessWidget', context,
                [groupBuyService, userProvider.user, userProvider.pinLocation]),
            const SizedBox(height: 20),
            _buildSectionWidget(
                '_buildTopUpSection', context, [walletProvider]),
            const SizedBox(height: 20),
            _buildSectionWidget('_buildThemeToggle', context),
          ],
        ),
      ),
    );
  }

  Widget buildGroupBuyAccessWidget(BuildContext context,
      GroupBuyService groupBuyService, User user, latLng.LatLng userLocation) {
    return StreamBuilder<List<GroupBuy>>(
      stream: groupBuyService.fetchActiveGroupBuys(),
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
            return _buildGroupBuyCard(
                context, groupBuy, groupBuyService, user, userLocation);
          },
        );
      },
    );
  }

  Widget _buildGroupBuyCard(BuildContext context, GroupBuy groupBuy,
      GroupBuyService groupBuyService, User user, latLng.LatLng userLocation) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
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
            ElevatedButton(
              onPressed: () {
                _navigateToGroupBuyPage(
                    context, groupBuy, groupBuyService, user, userLocation);
              },
              child: const Text('View Group Buy'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToGroupBuyPage(BuildContext context, GroupBuy groupBuy,
      GroupBuyService groupBuyService, User user, latLng.LatLng userLocation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupBuyPage(
          groupBuyService: groupBuyService,
          user: user,
          userLocation:
              gmaps.LatLng(userLocation.latitude, userLocation.longitude),
          groupBuyId: groupBuy
              .id, // Assuming you need this to fetch group details on the page
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
                userProvider.selectAndUploadProfilePicture();
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

  Widget _buildTopUpSection(
      BuildContext context, WalletProvider walletProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TopUpForm()),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Up Your Wallet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Add money to your wallet for easy purchases.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
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
            order.user == userProvider.user && order.status == 'pending')
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
                    color: Colors.blueAccent
                        .withOpacity(0.1), // Semi-transparent color
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.lightBlueAccent.withOpacity(0.2),
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

  // Updated RiderSection with Neomorphic Switch
  Widget _buildRiderSection(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available for Delivery',
                  style: TextStyle(fontSize: 18),
                ),
                NeomorphicSwitch(
                  value: userProvider.user.isAvailableForDelivery,
                  onChanged: (bool value) {
                    userProvider.updateUser(
                      userProvider.user.copyWith(isAvailableForDelivery: value),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'You are now available for delivery'
                            : 'You are now unavailable for delivery'),
                      ),
                    );
                  },
                  activeColor: lightMainColor, // Matches light theme
                  inactiveColor: Colors.grey.shade400,
                ),
              ],
            ),
            if (userProvider.user.liveLocation != null)
              ListTile(
                title: const Text('Current Location'),
                subtitle: Text(
                    'Lat: ${userProvider.user.liveLocation?.latitude}, Long: ${userProvider.user.liveLocation?.longitude}'),
                trailing: const Icon(Icons.location_on),
                onTap: () {
                  // Handle view location logic
                },
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
                                SubscriptionScreen(user: userProvider.user),
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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: userProvider.name);
    final emailController = TextEditingController(text: userProvider.email);
    final contactController = TextEditingController(text: userProvider.contact);

    final cityController =
        TextEditingController(text: userProvider.address?.city);
    final townController =
        TextEditingController(text: userProvider.address?.town);
    final estateController =
        TextEditingController(text: userProvider.address?.estate);
    final buildingController =
        TextEditingController(text: userProvider.address?.buildingName);
    final houseNumberController =
        TextEditingController(text: userProvider.address?.houseNumber);

    latLng.LatLng? selectedLocation = userProvider.address?.pinLocation != null
        ? latLng.LatLng(
            userProvider.address!.pinLocation!.latitude,
            userProvider.address!.pinLocation!.longitude,
          )
        : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Profile'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            value!.isEmpty ? 'Name is required' : null,
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) {
                          if (value!.isEmpty) return 'Email is required';
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: contactController,
                        decoration: const InputDecoration(labelText: 'Contact'),
                        validator: (value) =>
                            value!.isEmpty ? 'Contact is required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Address Details',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextFormField(
                        controller: cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: (value) =>
                            value!.isEmpty ? 'City is required' : null,
                      ),
                      TextFormField(
                        controller: townController,
                        decoration: const InputDecoration(labelText: 'Town'),
                      ),
                      TextFormField(
                        controller: estateController,
                        decoration: const InputDecoration(labelText: 'Estate'),
                      ),
                      TextFormField(
                        controller: buildingController,
                        decoration:
                            const InputDecoration(labelText: 'Building Name'),
                      ),
                      TextFormField(
                        controller: houseNumberController,
                        decoration:
                            const InputDecoration(labelText: 'House Number'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pin Location'),
                          ElevatedButton(
                            onPressed: () async {
                              final latLng.LatLng? result =
                                  await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapPickerScreen(
                                    initialPosition: selectedLocation ??
                                        latLng.LatLng(0.0, 0.0),
                                    onLocationSelected: (latLng, placemarks) {
                                      setState(() {
                                        selectedLocation = latLng;
                                        if (placemarks.isNotEmpty) {
                                          final placemark = placemarks.first;
                                          cityController.text =
                                              placemark.locality ?? '';
                                          townController.text =
                                              placemark.subLocality ?? '';
                                          estateController.text =
                                              placemark.subAdministrativeArea ??
                                                  '';
                                          houseNumberController.text =
                                              placemark.street ?? '';
                                        }
                                      });
                                    },
                                  ),
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  selectedLocation = result;
                                });
                              }
                            },
                            child: const Text('Select on Map'),
                          ),
                        ],
                      ),
                      if (selectedLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Selected: ${selectedLocation!.latitude}, ${selectedLocation!.longitude}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final newAddress = Address(
                        city: cityController.text,
                        town: townController.text,
                        estate: estateController.text,
                        buildingName: buildingController.text,
                        houseNumber: houseNumberController.text,
                        pinLocation: selectedLocation != null
                            ? gmaps.LatLng(selectedLocation!.latitude,
                                selectedLocation!.longitude)
                            : userProvider.address?.pinLocation,
                      );

                      userProvider.updateProfile(
                        name: nameController.text,
                        email: emailController.text,
                        contact: contactController.text,
                        address: newAddress,
                        pinLocation: gmaps.LatLng(
                          selectedLocation?.latitude ??
                              userProvider.address!.pinLocation!.latitude,
                          selectedLocation?.longitude ??
                              userProvider.address!.pinLocation!.longitude,
                        ),
                      );
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class MapPickerScreen extends StatefulWidget {
  final latLng.LatLng initialPosition;
  final Function(latLng.LatLng, List<Placemark>)? onLocationSelected;

  const MapPickerScreen({
    super.key,
    required this.initialPosition,
    this.onLocationSelected,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late latLng.LatLng _selectedPosition;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permissions are permanently denied')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _selectedPosition = latLng.LatLng(position.latitude, position.longitude);
    });
    _mapController.move(_selectedPosition, 15);
    _updateAddressFromLocation();
  }

  Future<void> _updateAddressFromLocation() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedPosition.latitude,
        _selectedPosition.longitude,
      );
      if (widget.onLocationSelected != null && placemarks.isNotEmpty) {
        widget.onLocationSelected!(_selectedPosition, placemarks);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: $e')),
      );
    }
  }

  Future<void> _searchLocation(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        setState(() {
          _selectedPosition = latLng.LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
        });
        _mapController.move(_selectedPosition, 15);
        _updateAddressFromLocation();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _updateAddressFromLocation();
              Navigator.pop(context, _selectedPosition);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              minZoom: 15,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPosition =
                      latLng.LatLng(point.latitude, point.longitude);
                });
                _updateAddressFromLocation();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: latLng.LatLng(_selectedPosition.latitude,
                        _selectedPosition.longitude),
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search location",
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _searchLocation(_searchController.text);
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _searchLocation(value);
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

void _shareReferralLink(BuildContext context, String referralLink) {
  Share.share('Join me on this app using my referral link: $referralLink');
}

// RestartWidget to rebuild the app when theme changes
class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/models/cart_item.dart';
import 'package:grocerry/models/product.dart';
import 'package:grocerry/models/user.dart';
import 'package:grocerry/providers/cart_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UserProvider with ChangeNotifier {
  // Profile-related fields
  String id; // Referring user ID
  String _name;
  String _email;
  final String _contact;
  String _address;
  String _pinLocation;
  String _profilePictureUrl;
  DateTime? _lastLoginDate;
  String? _referralCode;
  String? _referredBy;
  bool hasUsedReferral =
      false; // Indicates if this user has used a referral code

  final Map<String, String> _pinLocationCache = {};
  final Dio _dio = Dio();
  String addressCache = [] as String;
  // User-related fields
  late User _user;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cart provider
  late CartProvider _cartProvider;

  // Streams
  final _userStreamController = StreamController<User>.broadcast();
  final _cartStreamController =
      StreamController<Map<String, CartItem>>.broadcast();

  var isUploadingProfilePicture;
  var profilePictureUploadError;

  // Static method to generate a unique referral code
  static String generateStaticReferralCode() {
    return 'REF-${DateTime.now().millisecondsSinceEpoch}'; // Example format
  }

  // Constructor
  UserProvider({
    this.id = '',
    required String name,
    required String email,
    String contact = '',
    String address = '',
    String pinLocation = '',
    String profilePictureUrl = '',
    DateTime? lastLoginDate,
    User? user,
    String? referralCode,
    String? referredBy,
    bool? hasUsedReferral,
  })  : _name = name,
        _email = email,
        _contact = contact,
        _address = address,
        _pinLocation = pinLocation,
        _profilePictureUrl = profilePictureUrl,
        _lastLoginDate = lastLoginDate,
        _user = user ?? User.guest() {
    _referralCode = referralCode ?? UserProvider.generateStaticReferralCode();
    _referredBy = referredBy;
    if (hasUsedReferral != null) {
      this.hasUsedReferral = hasUsedReferral;
    }
  }

  // Apply a referral code to the user account
  Future<String> applyReferralCode(String code) async {
    if (isValidReferralCode(code)) {
      try {
        // Check Firestore for the referral code
        final referralCodeDoc =
            await _firestore.collection('referralCodes').doc(code).get();

        if (referralCodeDoc.exists) {
          final referralData = referralCodeDoc.data()!;

          // Check if the referral code has been used
          if (hasUsedReferral) {
            return 'You have already used a referral code.';
          }

          // Check max usage limit
          int usageCount = referralData['usageCount'] ?? 0;
          int maxUsage = referralData['maxUsage'] ?? 1;
          if (usageCount >= maxUsage) {
            return 'This referral code has reached its maximum usage limit.';
          }

          // Update referred user's document to set the referredBy field
          await _firestore.collection('users').doc(id).update({
            'referredBy': referralData['createdBy'],
            'hasUsedReferral': true,
          });

          // Update the usage count in the referral codes document
          await _firestore.collection('referralCodes').doc(code).update({
            'usageCount': FieldValue.increment(1),
            'usedBy':
                FieldValue.arrayUnion([id]), // Add this user to the usedBy list
          });

          // Update local fields
          _referredBy = referralData['createdBy'];
          hasUsedReferral = true;

          notifyListeners(); // Notify listeners about the change
          return 'Referral code applied successfully!';
        } else {
          return 'Referral code not found.';
        }
      } catch (e) {
        return 'Error applying referral code: $e';
      }
    } else {
      return 'Invalid referral code.';
    }
  }

  // Validate the referral code
  bool isValidReferralCode(String code) {
    if (code.isEmpty || code.length != 14) {
      return false;
    }
    final regex = RegExp(r'^[A-Z0-9-]+$');
    return code.startsWith('REF-') && regex.hasMatch(code);
  }

  // Getters
  String get name => _name;
  String get email => _email;
  String get contact => _contact;
  String get address => _address;
  String get pinLocation => _pinLocation;
  String get profilePictureUrl => _profilePictureUrl;
  DateTime? get lastLoginDate => _lastLoginDate;
  String? get referralCode => _referralCode;
  String? get referredBy => _referredBy;
  User get user => _user;

  Stream<User> get userStream => _userStreamController.stream;
  Stream<Map<String, CartItem>> get cartStream => _cartStreamController.stream;

  get currentUser => _user;

  // Methods to update profile data
  void updateProfile({
    required String name,
    required String email,
    String? profilePictureUrl,
    DateTime? lastLoginDate,
    required String contact,
    required String address,
    String? referralCode,
  }) {
    _name = name;
    _email = email;
    if (profilePictureUrl != null) _profilePictureUrl = profilePictureUrl;
    if (lastLoginDate != null) _lastLoginDate = lastLoginDate;
    if (referralCode != null) {
      _referralCode = referralCode;
    }
    _user = _user.copyWith(
      name: name,
      email: email,
      profilePictureUrl: profilePictureUrl,
      lastLoginDate: lastLoginDate,
    );
    _userStreamController.add(_user);
    notifyListeners();
  }

  void updateAddress(String newAddress) {
    _address = newAddress;
    addressCache = newAddress;
    _user = _user.copyWith(address: newAddress);
    _userStreamController.add(_user);
    notifyListeners();
  }

  void updatePinLocation(String newPinLocation) {
    _pinLocation = newPinLocation;
    _user =
        _user.copyWith(address: _pinLocationCache[newPinLocation] ?? _address);
    _userStreamController.add(_user);
    notifyListeners();
  }

  void updateProfilePictureUrl(String? newUrl) {
    if (newUrl != null) {
      _profilePictureUrl = newUrl;
      _user = _user.copyWith(profilePictureUrl: newUrl);
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  void updateLastLoginDate(DateTime? newDate) {
    if (newDate != null) {
      _lastLoginDate = newDate;
      _user = _user.copyWith(lastLoginDate: newDate);
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  // Methods to manage user data
  void updateUser(User newUser) {
    if (_user != newUser) {
      _user = newUser;
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  void updateUserField({
    String? id,
    String? email,
    String? token,
    String? name,
    String? contact,
    String? address,
    String? profilePictureUrl,
    List<String>? favoriteProductIds,
    List<String>? recentlyBoughtProductIds,
    DateTime? lastLoginDate,
    bool? isAdmin,
    bool? canManageUsers,
    bool? canManageProducts,
    bool? canViewReports,
    bool? canEditSettings,
    bool? isRider,
    bool? isAvailableForDelivery,
    LatLng? liveLocation,
    bool? isAttendant,
    bool? canConfirmPreparing,
    bool? canConfirmReadyForDelivery,
  }) {
    _user = _user.copyWith(
      id: id,
      email: email,
      token: token,
      name: name,
      contact: contact,
      address: address,
      profilePictureUrl: profilePictureUrl,
      favoriteProductIds: favoriteProductIds,
      recentlyBoughtProductIds: recentlyBoughtProductIds,
      lastLoginDate: lastLoginDate,
      isAdmin: isAdmin,
      canManageUsers: canManageUsers,
      canManageProducts: canManageProducts,
      canViewReports: canViewReports,
      canEditSettings: canEditSettings,
      isRider: isRider,
      isAvailableForDelivery: isAvailableForDelivery,
      liveLocation: liveLocation,
      isAttendant: isAttendant,
      canConfirmPreparing: canConfirmPreparing,
      canConfirmReadyForDelivery: canConfirmReadyForDelivery,
    );
    _userStreamController.add(_user);
    notifyListeners();
  }

  void clearFavorites() {
    _user = _user.copyWith(favoriteProductIds: []);
    _userStreamController.add(_user);
    notifyListeners();
  }

  void clearRecentlyBoughtProducts() {
    _user = _user.copyWith(recentlyBoughtProductIds: []);
    _userStreamController.add(_user);
    notifyListeners();
  }

  void addFavoriteProduct(String productId) {
    if (!_user.favoriteProductIds.contains(productId)) {
      _user = _user.copyWith(
          favoriteProductIds: [..._user.favoriteProductIds, productId]);
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  void removeFavoriteProduct(String productId) {
    _user = _user.copyWith(
        favoriteProductIds:
            _user.favoriteProductIds.where((id) => id != productId).toList());
    _userStreamController.add(_user);
    notifyListeners();
  }

  void addRecentlyBoughtProduct(String productId) {
    if (!_user.recentlyBoughtProductIds.contains(productId)) {
      _user = _user.copyWith(recentlyBoughtProductIds: [
        ..._user.recentlyBoughtProductIds,
        productId
      ]);
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  // Function to fetch the address
  Future<void> fetchpinLocation(String pinLocation) async {
    // Check if the address is already cached
    if (_pinLocationCache.containsKey(pinLocation)) {
      _pinLocation = _pinLocationCache[pinLocation]!;
      _pinLocation = pinLocation;
      _notifypinLocationChange();
      return;
    }

    const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

    // Handle missing API key
    if (apiKey.isEmpty) {
      _handleError('API key is missing');
      return;
    }

    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$pinLocation&key=$apiKey';

    try {
      final response = await _dio.get(url);

      // Handle successful response
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'];
        if (results.isNotEmpty && results[0]['formatted_address'] != null) {
          _address = results[0]['formatted_address'];
        } else {
          _address = 'Unknown Address'; // Handle case when no address is found
        }

        // Cache the result to avoid future API calls for the same location
        _pinLocationCache[pinLocation] = _address;
        _pinLocation = pinLocation;
        _notifypinLocationChange();
      } else {
        _handleError(
            'Failed to load address. Status: ${response.data['status']}');
      }
    } on DioException catch (e) {
      _handleError('Dio error: ${e.message}'); // Catch Dio-specific errors
    } catch (error) {
      _handleError(
          'Unexpected error: $error'); // Catch any other unexpected errors
    }
  }

  // Helper function to notify address changes
  void _notifypinLocationChange() {
    print('Pin Location updated: $_pinLocation');
  }

  // Private function to handle errors
  void _handleError(String error) {
    print('Error: $error');
    _address = 'Unknown Pin Location'; // Set fallback address in case of errors
    _notifypinLocationChange();
  }

  // Fetch methods
  Future<List<Product>> fetchFavorites() async {
    if (_user.favoriteProductIds.isEmpty) return [];

    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: _user.favoriteProductIds)
          .get();

      final favorites =
          querySnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();

      return favorites;
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }

  Future<List<Product>> fetchRecentlyBought() async {
    if (_user.recentlyBoughtProductIds.isEmpty) return [];

    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where(FieldPath.documentId, whereIn: _user.recentlyBoughtProductIds)
          .get();

      final recentlyBought =
          querySnapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();

      return recentlyBought;
    } catch (e) {
      print('Error fetching recently bought products: $e');
      return [];
    }
  }

  // Logout method
  void logout() {
    _user = User(
      id: '',
      email: '',
      token: '',
      name: '',
      address: '',
      profilePictureUrl: '',
      favoriteProductIds: [],
      recentlyBoughtProductIds: [],
      lastLoginDate: null,
      isAdmin: false,
      canManageUsers: false,
      canManageProducts: false,
      canViewReports: false,
      canEditSettings: false,
      isRider: false,
      isAvailableForDelivery: false,
      liveLocation: null,
      isAttendant: false,
      canConfirmPreparing: false,
      canConfirmReadyForDelivery: false,
      uid: '',
      contact: '',
      pinLocation: null,
    );
    _userStreamController.add(_user);
    notifyListeners();
  }

  // Token update and login status check
  void updateToken(String newToken) {
    _user = _user.copyWith(token: newToken);
    _userStreamController.add(_user);
    notifyListeners();
  }

  Stream<List<Product>> get favoritesStream {
    if (_user?.favoriteProductIds?.isEmpty ?? true) {
      return Stream.value(
          []); // Return an empty stream or null might be more appropriate depending on usage
    }

    return _firestore
        .collection('products')
        .where(FieldPath.documentId, whereIn: _user.favoriteProductIds)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .where((product) =>
                product != null) // Ensure no null products are included
            .toList());
  }

  // Getter for the stream of recently bought products
  Stream<List<Product>> get recentlyBoughtStream {
    if (_user?.recentlyBoughtProductIds?.isEmpty ?? true) {
      return Stream.value(
          []); // Return an empty stream or null might be more appropriate
    }

    return _firestore
        .collection('products')
        .where(FieldPath.documentId, whereIn: _user.recentlyBoughtProductIds)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .where((product) => product != null)
            .toList());
  }

  // Set CartProvider
  void setCartProvider(CartProvider cartProvider) {
    _cartProvider = cartProvider;
    _cartProvider.cartStream.listen((cartItems) {
      // Handle cart item changes
      print('Cart items updated: $cartItems');
      _cartStreamController.add(cartItems); // Add cart items to the stream
      // You can update user-related logic here based on cart changes
    });
  }

  bool isLoggedIn() {
    return _user.token!.isNotEmpty &&
        _user.email.isNotEmpty &&
        _user.email != 'Guest';
  }

  @override
  void dispose() {
    _userStreamController.close();
    _cartStreamController.close();
    super.dispose();
  }

  // Method for better handling of current user
  User? getCurrentUser() {
    return _user.email.isNotEmpty ? _user : null; // Ensure valid user data
  }

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

// Method to select and upload a profile picture
  Future<void> selectAndUploadProfilePicture(dynamic user) async {
    try {
      // Pick an image from the device
      final XFile? pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Convert the picked file to a File object
        final File imageFile = File(pickedFile.path);

        // Upload the image to Firebase Storage
        final ref =
            _storage.ref().child('user_profile_pictures/${user.id}.jpg');
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() {});

        // Get the download URL of the uploaded image
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        // Update the profile picture URL in the user data
        updateProfilePictureUrl(downloadUrl);
      }
    } catch (error) {
      print('Error selecting/uploading profile picture: $error');
    }
  }
}

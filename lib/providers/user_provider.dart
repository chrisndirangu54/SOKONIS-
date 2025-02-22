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
  final Map _pinLocationCache = {};
  final Dio _dio = Dio();
  List addressCache = []; //as Address?;

  // User-related fields
  late User _user;
  late String _referralCode;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cart provider
  late CartProvider _cartProvider;

  // Streams
  final _userStreamController = StreamController<User>.broadcast();
  final _cartStreamController = StreamController<Map<String, CartItem>>.broadcast();

  var isUploadingProfilePicture;
  var profilePictureUploadError;

  // Static method to generate a unique referral code
  static String generateStaticReferralCode() {
    return 'REF-${DateTime.now().millisecondsSinceEpoch}'; // Example format
  }

  // Constructor
  UserProvider({

    String contact = '',
    Address? address,
    LatLng? pinLocation = const LatLng(0, 0),
    String profilePictureUrl = '',
    DateTime? lastLoginDate,
    String? referralCode,
    String? referredBy,
    bool? hasUsedReferral,
  })  : hasUsedReferral = hasUsedReferral ?? false,
        super() {
    _referralCode = referralCode ?? UserProvider.generateStaticReferralCode();
    _referredBy = referredBy;
    if (hasUsedReferral != null) {
      this.hasUsedReferral = hasUsedReferral;
    }

    // Call this method to initialize or update the user asynchronously after construction
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _user = await User.guest();
    notifyListeners();
  }

  // Apply a referral code to the user account
  Future<String> applyReferralCode(String code) async {
    if (isValidReferralCode(code)) {
      try {
        // Check Firestore for the referral code
        final referralCodeDoc = await _firestore.collection('referralCodes').doc(code).get();

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
          await _firestore.collection('users').doc(_user.id).update({
            'referredBy': referralData['createdBy'],
            'hasUsedReferral': true,
          });

          // Update the usage count in the referral codes document
          await _firestore.collection('referralCodes').doc(code).update({
            'usageCount': FieldValue.increment(1),
            'usedBy': FieldValue.arrayUnion([_user.id]), // Add this user to the usedBy list
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
  String get name => _user.name;
  String get email => _user.email;
  String get contact => _user.contact;
  Address? get address => _user.address;
  LatLng? get pinLocation => _user.pinLocation;
  String get profilePictureUrl => _user.profilePictureUrl;
  DateTime? get lastLoginDate => _user.lastLoginDate;
  String? get referralCode => _user.referralCode;
  String? get referredBy => _user.referredBy;
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
    required Address address,
    String? referralCode,
    required LatLng pinLocation,
  }) {
    _user = _user.copyWith(
      name: name,
      email: email,
      profilePictureUrl: profilePictureUrl,
      lastLoginDate: lastLoginDate,
      contact: contact,
      address: address,
      referralCode: referralCode,
      pinLocation: pinLocation,
    );
    _userStreamController.add(_user);
    notifyListeners();
  }

  void updateAddress(Address? newAddress) {
    _user = _user.copyWith(address: newAddress);
    addressCache = newAddress as List;
    _userStreamController.add(_user);
    notifyListeners();
  }

  void updatePinLocation(LatLng newPinLocation) {
    _user = _user.copyWith(
        pinLocation: _pinLocationCache[newPinLocation] ?? newPinLocation);
    _userStreamController.add(_user);
    notifyListeners();
  }

  void updateProfilePictureUrl(String? newUrl) {
    if (newUrl != null) {
      _user = _user.copyWith(profilePictureUrl: newUrl);
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  void updateLastLoginDate(DateTime? newDate) {
    if (newDate != null) {
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
    Address? address,
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

  void addFavoriteProduct(Product product) {
    if (!_user.favoriteProductIds.contains(product.id)) {
      _user = _user.copyWith(
          favoriteProductIds: [..._user.favoriteProductIds, product.id]);
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  void removeFavoriteProduct(Product product) {
    _user = _user.copyWith(
        favoriteProductIds:
            _user.favoriteProductIds.where((id) => id != product.id).toList());
    _userStreamController.add(_user);
    notifyListeners();
  }

  void addRecentlyBoughtProduct(Product product) {
    if (!_user.recentlyBoughtProductIds.contains(product.id)) {
      _user = _user.copyWith(recentlyBoughtProductIds: [
        ..._user.recentlyBoughtProductIds,
        product.id
      ]);
      _userStreamController.add(_user);
      notifyListeners();
    }
  }

  // Function to fetch the address
  Future<void> fetchpinLocation(LatLng pinLocation) async {
    // Check if the address is already cached
    if (_pinLocationCache.containsKey(pinLocation)) {
      _user = _user.copyWith(pinLocation: _pinLocationCache[pinLocation]!);
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
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pinLocation.latitude},${pinLocation.longitude}&key=$apiKey';

    try {
      final response = await _dio.get(url);

      // Handle successful response
      if (response.statusCode == 200 && response.data['status'] == 'OK') {
        final results = response.data['results'];
        if (results.isNotEmpty &&
            results[0]['formatted_address'] != null) {
          _user = _user.copyWith(pinLocation: LatLng(results[0]['geometry']['location']['lat'], results[0]['geometry']['location']['lng']));
        } else {
          _user = _user.copyWith(pinLocation: null); // Handle case when no address is found
        }

        // Cache the result to avoid future API calls for the same location
        _pinLocationCache[pinLocation] = _user.pinLocation;
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
    print('Address updated: ${_user.pinLocation}');
  }

  // Private function to handle errors
  void _handleError(String error) {
    print('Error: $error');
    _user = _user.copyWith(pinLocation: null); // Set fallback address in case of errors
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

      final favorites = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc: doc))
          .toList();

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

      final recentlyBought = querySnapshot.docs
          .map((doc) => Product.fromFirestore(doc: doc))
          .toList();

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
      address: null,
      pinLocation: null,
      profilePictureUrl: '',
      favoriteProductIds: [],
      recentlyBoughtProductIds: [],
      lastLoginDate: null,
      contact: '',
      referralCode: null,
      referredBy: null,
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
    if (_user.favoriteProductIds.isEmpty ?? true) {
      return Stream.value([]);
    }

    return _firestore
        .collection('products')
        .where(FieldPath.documentId, whereIn: _user.favoriteProductIds)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Product.fromFirestore(doc: doc))
            .where((product) => product != null)
            .toList());
  }

  // Getter for the stream of recently bought products
  Stream<List<Product>> get recentlyBoughtStream {
    if (_user.recentlyBoughtProductIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('products')
        .where(FieldPath.documentId, whereIn: _user.recentlyBoughtProductIds)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => Product.fromFirestore(doc: doc))
            .where((product) => product != null)
            .toList());
  }

  // Set CartProvider
  void setCartProvider(CartProvider cartProvider) {
    _cartProvider = cartProvider;
    _cartProvider.cartStream.listen((cartItem) {
      // Handle cart item changes
      print('Cart items updated: $cartItem');
      _cartStreamController.add(cartItem); // Add cart items to the stream
      // You can update user-related logic here based on cart changes
    });
  }

  bool isLoggedIn() {
    return _user.token?.isNotEmpty == true &&
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

  static var addressList;
  
  String? _referredBy;
  
  bool hasUsedReferral;

  // Method to select and upload a profile picture
  Future<void> selectAndUploadProfilePicture() async {
    try {
      // Pick an image from the device
      final XFile? pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Convert the picked file to a File object
        final File imageFile = File(pickedFile.path);

        // Upload the image to Firebase Storage
        final ref =
            _storage.ref().child('user_profile_pictures/${_user.id}.jpg');
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
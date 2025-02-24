import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grocerry/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

// Define PaymentMethod enum
enum PaymentMethod { Mpesa, CreditCard, Wallet }

class WalletProvider with ChangeNotifier {
  double balance = 0.0;
  bool isProcessingPayment = false;
  String paymentError = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  WalletProvider() {
    _loadBalance();
  }

  // Load balance from local storage initially
  Future<void> _loadBalance() async {
    final prefs = await SharedPreferences.getInstance();
    balance = prefs.getDouble('walletBalance') ?? 0.0;
    notifyListeners();
  }

  // Update balance and persist it
  void updateBalance(double amount) {
    balance += amount;
    _saveBalance();
    notifyListeners();
  }

  // Persist balance to local storage
  Future<void> _saveBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('walletBalance', balance);
  }

  // Method to add money to wallet with payment method selection
  Future<void> topUpWallet(
      double amount, PaymentMethod paymentMethod, BuildContext context) async {
    if (amount <= 0) {
      print('Amount must be positive');
      paymentError = 'Amount must be positive';
      notifyListeners();
      return;
    }

    isProcessingPayment = true;
    paymentError = '';
    notifyListeners();

    try {
      bool paymentSuccessful = false;
      switch (paymentMethod) {
        case PaymentMethod.Mpesa:
          paymentSuccessful = await _processMpesaPayment(amount, context);
          break;
        case PaymentMethod.CreditCard:
          paymentSuccessful = await _processStripePayment(amount, context);
          break;
        case PaymentMethod.Wallet:
          throw Exception('Cannot top up wallet using wallet');
      }

      if (paymentSuccessful) {
        updateBalance(amount);
        print('Top up successful for $amount via $paymentMethod');
        await _logTransaction(amount, paymentMethod, 'success', context);
      } else {
        print(
            'Payment failed for $amount via $paymentMethod. Top up canceled.');
        paymentError = 'Payment failed';
        notifyListeners();
      }
    } catch (e) {
      print('An error occurred during top-up with $paymentMethod: $e');
      paymentError = 'Error occurred: $e';
      notifyListeners();
    } finally {
      isProcessingPayment = false;
      notifyListeners();
    }
  }

  // Process M-Pesa payment with phone number input dialog
  Future<bool> _processMpesaPayment(double amount, BuildContext context) async {
    final TextEditingController phoneController = TextEditingController();
    List<String> previousPhoneNumbers = await _loadPreviousPhoneNumbers();

    if (previousPhoneNumbers.isNotEmpty) {
      phoneController.text =
          previousPhoneNumbers.first; // Pre-fill with the most recent number
    }

    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enter M-Pesa Phone Number'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'e.g., 2547XXXXXXXX',
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (previousPhoneNumbers.isNotEmpty)
                    DropdownButton<String>(
                      value: phoneController.text.isNotEmpty &&
                              previousPhoneNumbers
                                  .contains(phoneController.text)
                          ? phoneController.text
                          : null,
                      hint: const Text('Select previous number'),
                      isExpanded: true,
                      items: previousPhoneNumbers.map((String number) {
                        return DropdownMenuItem<String>(
                          value: number,
                          child: Text(number),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          phoneController.text = newValue ?? '';
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final number = phoneController.text.trim();
                    if (number.isNotEmpty &&
                        number.startsWith('254') &&
                        number.length == 12) {
                      Navigator.pop(dialogContext, number);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please enter a valid phone number (e.g., 2547XXXXXXXX)'),
                        ),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payment canceled: No phone number provided')),
      );
      return false;
    }

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('initiateMpesaPayment');
      final response = await callable.call({
        'amount': amount,
        'phoneNumber': phoneNumber,
        'paybillNumber': '123456', // Your paybill number
        'accountNumber': 'YourAccountNumber',
      });

      final success = response.data['status'] == 'success';
      if (success) {
        await _savePhoneNumber(phoneNumber);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('M-Pesa payment initiated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('M-Pesa payment failed')),
        );
      }
      return success;
    } catch (e) {
      print('M-Pesa payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('M-Pesa payment error: $e')),
      );
      return false;
    }
  }

  // Load previous phone numbers from SharedPreferences
  Future<List<String>> _loadPreviousPhoneNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('mpesaPhoneNumbers') ?? [];
  }

  // Save a new phone number to SharedPreferences
  Future<void> _savePhoneNumber(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> previousNumbers = await _loadPreviousPhoneNumbers();
    if (!previousNumbers.contains(phoneNumber)) {
      previousNumbers.insert(0, phoneNumber); // Add to the start of the list
      if (previousNumbers.length > 5) {
        previousNumbers = previousNumbers.sublist(0, 5); // Limit to 5 numbers
      }
      await prefs.setStringList('mpesaPhoneNumbers', previousNumbers);
    }
  }

  // Process Stripe (Visa/MasterCard) payment
  Future<bool> _processStripePayment(
      double amount, BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      final paymentRef = await _firestore
          .collection('customers')
          .doc(user.id)
          .collection('payments')
          .add({
        'amount': (amount * 100).toInt(), // Convert to cents
        'currency': 'usd',
        'status': 'pending',
      });

      final paymentId = paymentRef.id;
      final paymentSnapshot = await paymentRef.get();
      final clientSecret = paymentSnapshot.data()?['client_secret'];

      if (clientSecret == null) {
        throw Exception('Failed to retrieve client secret');
      }

      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Grocerry',
        ),
      );

      await stripe.Stripe.instance.presentPaymentSheet();
      return true;
    } catch (e) {
      print('Stripe payment error: $e');
      return false;
    }
  }

  // Process Wallet payment (for using wallet balance elsewhere, not topping up)
  Future<bool> _processWalletPayment(double amount) async {
    if (balance >= amount) {
      updateBalance(-amount);
      return true;
    } else {
      paymentError = 'Insufficient wallet balance';
      notifyListeners();
      return false;
    }
  }

  // Log transaction to Firestore
  Future<void> _logTransaction(double amount, PaymentMethod paymentMethod,
      String status, BuildContext context) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      await _firestore.collection('transactions').add({
        'userId': user.id,
        'amount': amount,
        'paymentMethod': paymentMethod.toString().split('.').last,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print(
          'Transaction logged: User ${user.id} added $amount via $paymentMethod with status $status');
    } catch (e) {
      print('Error logging transaction: $e');
    }
  }
}

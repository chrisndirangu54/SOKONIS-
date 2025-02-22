import 'package:flutter/material.dart';
import 'package:grocerry/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
// Assuming you have this file
class TopUpForm extends StatefulWidget {
  const TopUpForm({super.key});
  
@override

  _TopUpFormState createState() => _TopUpFormState();
}
class _TopUpFormState extends State<TopUpForm> {
  final _formKey = GlobalKey<FormState>();
  double _amount = 0.0;
  PaymentMethod _selectedMethod = PaymentMethod.Mpesa;
  
@override

  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              return null;
            },
            onSaved: (value) => _amount = double.parse(value!),
          ),
          DropdownButtonFormField<PaymentMethod>(
            value: _selectedMethod,
            onChanged: (PaymentMethod? newValue) {
              setState(() {
                _selectedMethod = newValue!;
              });
            },
            items: PaymentMethod.values.map((PaymentMethod method) {
              return DropdownMenuItem<PaymentMethod>(
                value: method,
                child: Text(method.toString().split('.').last),
              );
            }).toList(),
            decoration: const InputDecoration(labelText: 'Payment Method'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                await walletProvider.topUpWallet(_amount, _selectedMethod, context);
                // Handle UI feedback, perhaps show a success or error dialog
              }
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }
}

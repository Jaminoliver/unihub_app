import 'package:flutter/material.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unihub/main.dart'; // Import to access global paystackPlugin

/// Payment Service - Handles Paystack payment integration
class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Process payment with Paystack
  /// Returns Map with reference and transaction_id if successful, null if failed
  Future<Map<String, dynamic>?> processPayment({
    required BuildContext context,
    required String email,
    required double amount,
    required String currency,
    String? reference,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Convert amount to kobo (Paystack uses smallest currency unit)
      final amountInKobo = (amount * 100).toInt();

      // Generate reference if not provided
      final paymentReference = reference ?? _generateReference();

      // Create charge
      final charge = Charge()
        ..amount = amountInKobo
        ..email = email
        ..currency = currency
        ..reference = paymentReference;

      // Add metadata using putMetaData or putCustomField
      if (metadata != null) {
        metadata.forEach((key, value) {
          charge.putCustomField(key, value.toString());
        });
      }

      // Process payment using global paystackPlugin
      final response = await paystackPlugin.checkout(
        context,
        method: CheckoutMethod.card,
        charge: charge,
      );

      // Check if payment was successful
      if (response.status && response.reference != null) {
        // Verify payment on backend
        final verificationData = await verifyPayment(response.reference!);
        
        if (verificationData != null && verificationData['success'] == true) {
          return {
            'reference': response.reference!,
            'transaction_id': verificationData['data']['id'], // Paystack transaction ID
            'amount': verificationData['amount'],
          };
        } else {
          print('Payment verification failed');
          return null;
        }
      } else {
        print('Payment failed: ${response.message}');
        return null;
      }
    } catch (e) {
      print('Error processing payment: $e');
      return null;
    }
  }

  /// Verify payment with Paystack backend via Edge Function
  /// Returns full verification data
  Future<Map<String, dynamic>?> verifyPayment(String reference) async {
    try {
      // Call Supabase Edge Function
      final response = await _supabase.functions.invoke(
        'verify-payment',
        body: {
          'reference': reference,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        print('Payment verified: ${response.data}');
        return response.data; // Return full verification data
      } else {
        print('Payment verification failed: ${response.data}');
        return null;
      }
    } catch (e) {
      print('Error verifying payment: $e');
      return null;
    }
  }

  /// Calculate escrow amount based on payment method
  double calculateEscrowAmount(double totalAmount, String paymentMethod) {
    switch (paymentMethod) {
      case 'full':
        return totalAmount;
      case 'half':
        return totalAmount / 2;
      case 'pay_on_delivery':
        return 0;
      default:
        return 0;
    }
  }

  /// Calculate platform commission (5%)
  double calculateCommission(double totalAmount) {
    return totalAmount * 0.05;
  }

  /// Calculate seller payout (95% of total)
  double calculateSellerPayout(double totalAmount) {
    return totalAmount * 0.95;
  }

  /// Generate unique payment reference
  String _generateReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'UNI_$timestamp';
  }

  /// Format amount for display
  String formatAmount(double amount) {
    return '₦${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  /// Get payment method display name
  String getPaymentMethodName(String paymentMethod) {
    switch (paymentMethod) {
      case 'full':
        return 'Full Payment';
      case 'half':
        return 'Half Payment';
      case 'pay_on_delivery':
        return 'Pay on Delivery';
      default:
        return 'Unknown';
    }
  }

  /// Get payment method description
  String getPaymentMethodDescription(String paymentMethod, double amount) {
    switch (paymentMethod) {
      case 'full':
        return 'Pay ${formatAmount(amount)} now via card';
      case 'half':
        final halfAmount = amount / 2;
        return 'Pay ${formatAmount(halfAmount)} now, ${formatAmount(halfAmount)} on delivery';
      case 'pay_on_delivery':
        return 'Pay ${formatAmount(amount)} when you receive your item';
      default:
        return '';
    }
  }

  /// Check if payment method requires online payment
  bool requiresOnlinePayment(String paymentMethod) {
    return paymentMethod == 'full' || paymentMethod == 'half';
  }

  /// Get valid payment methods based on product price (PRD Section 7)
  List<String> getValidPaymentMethods(double price) {
    if (price >= 35000) {
      return ['full', 'half']; // Only full or half payment
    } else if (price >= 20000) {
      return ['full', 'half', 'pay_on_delivery']; // All options
    } else {
      return ['full', 'pay_on_delivery']; // Only full or POD
    }
  }

  /// Validate payment method for product price
  bool isPaymentMethodValid(double price, String paymentMethod) {
    final validMethods = getValidPaymentMethods(price);
    return validMethods.contains(paymentMethod);
  }

  /// Process refund (to be implemented with backend)
  Future<bool> processRefund({
    required String orderId,
    required String paymentReference,
    required double amount,
    String? reason,
  }) async {
    try {
      // Call your backend/edge function to process refund
      final response = await _supabase.rpc('process_paystack_refund', params: {
        'order_id': orderId,
        'payment_reference': paymentReference,
        'amount': amount,
        'reason': reason,
      });

      return response['success'] == true;
    } catch (e) {
      print('Error processing refund: $e');
      return false;
    }
  }

  /// Show payment success dialog
  void showPaymentSuccessDialog(BuildContext context, String reference) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Reference: $reference',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show payment failed dialog
  void showPaymentFailedDialog(BuildContext context, String? message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 60,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Payment Failed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
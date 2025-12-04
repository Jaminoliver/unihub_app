import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dispute_model.dart';
import 'dart:typed_data';

class DisputeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new dispute
  Future<DisputeModel> createDispute({
    required String orderId,
    required String raisedByUserId,
    required String raisedByType, // 'buyer' or 'seller'
    required String disputeReason,
    required String description,
    List<String>? evidenceUrls,
  }) async {
    try {
      final response = await _supabase
          .from('disputes')
          .insert({
            'order_id': orderId,
            'raised_by_user_id': raisedByUserId,
            'raised_by_type': raisedByType,
            'dispute_reason': disputeReason,
            'description': description,
            'evidence_urls': evidenceUrls,
            'status': 'open',
            'priority': 'medium',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('''
            *,
            order:orders!disputes_order_id_fkey(
              order_number,
              total_amount,
              product:products(name, image_urls)
            )
          ''')
          .single();

      return DisputeModel.fromJson(response);
    } catch (e) {
      print('Error creating dispute: $e');
      rethrow;
    }
  }

  /// Get dispute by order ID
  Future<DisputeModel?> getDisputeByOrderId(String orderId) async {
    try {
      final response = await _supabase
          .from('disputes')
          .select('''
            *,
            order:orders!disputes_order_id_fkey(
              order_number,
              total_amount,
              order_status,
              payment_method,
              product:products(name, image_urls)
            )
          ''')
          .eq('order_id', orderId)
          .maybeSingle();

      return response != null ? DisputeModel.fromJson(response) : null;
    } catch (e) {
      print('Error fetching dispute by order: $e');
      return null;
    }
  }

  /// Get all disputes raised by a user (buyer or seller)
  Future<List<DisputeModel>> getUserDisputes(String userId) async {
    try {
      final response = await _supabase
          .from('disputes')
          .select('''
            *,
            order:orders!disputes_order_id_fkey(
              order_number,
              total_amount,
              order_status,
              product:products(name, image_urls)
            )
          ''')
          .eq('raised_by_user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DisputeModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user disputes: $e');
      rethrow;
    }
  }

  /// Get dispute by ID with full details
  Future<DisputeModel?> getDisputeById(String disputeId) async {
    try {
      final response = await _supabase
          .from('disputes')
          .select('''
            *,
            order:orders!disputes_order_id_fkey(
              id,
              order_number,
              total_amount,
              order_status,
              payment_method,
              escrow_amount,
              buyer:profiles!orders_buyer_id_fkey(full_name, email),
              seller:sellers!orders_seller_id_fkey(business_name, full_name, email),
              product:products(name, image_urls),
              delivery_address:delivery_addresses(address_line, city, state)
            )
          ''')
          .eq('id', disputeId)
          .single();

      return DisputeModel.fromJson(response);
    } catch (e) {
      print('Error fetching dispute details: $e');
      return null;
    }
  }

  /// Check if order has an active dispute
  Future<bool> hasActiveDispute(String orderId) async {
    try {
      final response = await _supabase
          .from('disputes')
          .select('id, status')
          .eq('order_id', orderId)
          .or('status.eq.open,status.eq.under_review')
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking active dispute: $e');
      return false;
    }
  }

  /// Upload evidence image to Supabase Storage
  /// Accepts Uint8List (bytes) and fileName
  Future<String?> uploadEvidenceImage(String disputeId, Uint8List fileBytes, String fileName) async {
    try {
      final storagePath = 'dispute_$disputeId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await _supabase.storage
          .from('dispute-evidence')
          .uploadBinary(storagePath, fileBytes);

      final publicUrl = _supabase.storage
          .from('dispute-evidence')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading evidence: $e');
      return null;
    }
  }

  /// Get available dispute reasons
  List<Map<String, String>> getDisputeReasons() {
    return [
      {
        'value': 'product_not_received',
        'label': 'Product Not Received',
        'description': 'I haven\'t received my order'
      },
      {
        'value': 'wrong_item_received',
        'label': 'Wrong Item Received',
        'description': 'Received different item than ordered'
      },
      {
        'value': 'damaged_item',
        'label': 'Damaged/Defective Item',
        'description': 'Product is damaged or not working'
      },
      {
        'value': 'fake_counterfeit',
        'label': 'Fake/Counterfeit Product',
        'description': 'Product appears to be fake'
      },
      {
        'value': 'seller_not_shipping',
        'label': 'Seller Not Shipping',
        'description': 'Seller hasn\'t shipped my order'
      },
      {
        'value': 'payment_issue',
        'label': 'Payment Issue',
        'description': 'Problem with payment or charges'
      },
      {
        'value': 'refund_not_received',
        'label': 'Refund Not Received',
        'description': 'Haven\'t received my refund'
      },
      {
        'value': 'other',
        'label': 'Other Issue',
        'description': 'Other problem not listed above'
      },
    ];
  }
}
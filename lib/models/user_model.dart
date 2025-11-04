/// User Model - CRASH-PROOF VERSION
/// Matches 'profiles' table in Supabase
class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String universityId;
  final String? universityName;
  final String? state;
  final String? deliveryAddress;
  final String? campusLocation;
  final bool isVerified;
  final bool isSeller;
  final double? sellerRating;
  final int totalSales;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.profileImageUrl,
    required this.universityId,
    this.universityName,
    this.state,
    this.deliveryAddress,
    this.campusLocation,
    this.isVerified = false,
    this.isSeller = false,
    this.sellerRating,
    this.totalSales = 0,
    required this.createdAt,
  });

  /// ✅ CRASH-PROOF: From JSON (Supabase response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      fullName: (json['full_name'] as String? ?? 'User').trim(),
      email: json['email'] as String? ?? 'no-email@example.com',
      phoneNumber: json['phone_number'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      universityId: json['university_id'] as String? ?? '',
      universityName: json['university_name'] as String?,
      state: json['state'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      campusLocation: json['campus_location'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isSeller: json['is_seller'] as bool? ?? false,
      sellerRating: json['seller_rating'] != null
          ? (json['seller_rating'] as num).toDouble()
          : null,
      totalSales: json['total_sales'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'profile_image_url': profileImageUrl,
      'university_id': universityId,
      'state': state,
      'delivery_address': deliveryAddress,
      'campus_location': campusLocation,
      'is_verified': isVerified,
      'is_seller': isSeller,
      'seller_rating': sellerRating,
      'total_sales': totalSales,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    String? universityId,
    String? universityName,
    String? state,
    String? deliveryAddress,
    String? campusLocation,
    bool? isVerified,
    bool? isSeller,
    double? sellerRating,
    int? totalSales,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      universityId: universityId ?? this.universityId,
      universityName: universityName ?? this.universityName,
      state: state ?? this.state,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      campusLocation: campusLocation ?? this.campusLocation,
      isVerified: isVerified ?? this.isVerified,
      isSeller: isSeller ?? this.isSeller,
      sellerRating: sellerRating ?? this.sellerRating,
      totalSales: totalSales ?? this.totalSales,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// ✅ CRASH-PROOF: Display name (first name only)
  String get firstName {
    if (fullName.trim().isEmpty) {
      return 'User';
    }

    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) {
      return 'User';
    }

    return parts.first.trim();
  }

  /// ✅ CRASH-PROOF: Last name (if exists)
  String? get lastName {
    if (fullName.trim().isEmpty) {
      return null;
    }

    final parts = fullName.trim().split(' ');
    if (parts.length < 2) {
      return null;
    }

    return parts.sublist(1).join(' ').trim();
  }

  /// Is buyer (not seller)
  bool get isBuyer => !isSeller;

  /// Has complete profile
  bool get hasCompleteProfile {
    return fullName.trim().isNotEmpty &&
        email.isNotEmpty &&
        universityId.isNotEmpty &&
        state != null &&
        state!.isNotEmpty;
  }
}

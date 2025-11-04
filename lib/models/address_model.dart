/// Delivery Address Model - Matches 'delivery_addresses' table
class DeliveryAddressModel {
  final String id;
  final String userId;
  final String addressLine;
  final String city;
  final String state;
  final String? landmark;
  final String? phoneNumber;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeliveryAddressModel({
    required this.id,
    required this.userId,
    required this.addressLine,
    required this.city,
    required this.state,
    this.landmark,
    this.phoneNumber,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeliveryAddressModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      addressLine: json['address_line'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      landmark: json['landmark'] as String?,
      phoneNumber: json['phone_number'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'address_line': addressLine,
      'city': city,
      'state': state,
      'landmark': landmark,
      'phone_number': phoneNumber,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Full address as single string
  String get fullAddress {
    final parts = [
      addressLine,
      if (landmark != null && landmark!.isNotEmpty) 'Near $landmark',
      city,
      state,
    ];
    return parts.join(', ');
  }

  // Short address (first line + city)
  String get shortAddress {
    return '$addressLine, $city';
  }

  DeliveryAddressModel copyWith({
    String? id,
    String? userId,
    String? addressLine,
    String? city,
    String? state,
    String? landmark,
    String? phoneNumber,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryAddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      state: state ?? this.state,
      landmark: landmark ?? this.landmark,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

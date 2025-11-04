/// University Model - Matches 'universities' table
class UniversityModel {
  final String id;
  final String name;
  final String shortName;
  final String? logoUrl;
  final String country;
  final String state;
  final String city;
  final bool isActive;
  final int productCount;
  final DateTime createdAt;

  UniversityModel({
    required this.id,
    required this.name,
    required this.shortName,
    this.logoUrl,
    required this.country,
    required this.state,
    required this.city,
    this.isActive = true,
    this.productCount = 0,
    required this.createdAt,
  });

  factory UniversityModel.fromJson(Map<String, dynamic> json) {
    return UniversityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String,
      logoUrl: json['logo_url'] as String?,
      country: json['country'] as String? ?? 'Nigeria',
      state: json['state'] as String,
      city: json['city'] as String,
      isActive: json['is_active'] as bool? ?? true,
      productCount: json['product_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'short_name': shortName,
      'logo_url': logoUrl,
      'country': country,
      'state': state,
      'city': city,
      'is_active': isActive,
      'product_count': productCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Category Model - Matches 'categories' table
class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? iconName;
  final String? iconUrl;
  final int productCount;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.iconName,
    this.iconUrl,
    this.productCount = 0,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconName: json['icon_name'] as String?,
      iconUrl: json['icon_url'] as String?,
      productCount: json['product_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'icon_url': iconUrl,
      'product_count': productCount,
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

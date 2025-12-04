/// Simplified product model for AI chat display
class AiProductCardModel {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String universityName;
  final double? rating;
  final bool isAvailable;
  final String? condition;

  AiProductCardModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.universityName,
    this.rating,
    this.isAvailable = true,
    this.condition,
  });

  String get formattedPrice {
    return '₦${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'university_name': universityName,
      'rating': rating,
      'is_available': isAvailable,
      'condition': condition,
    };
  }

  factory AiProductCardModel.fromJson(Map<String, dynamic> json) {
    return AiProductCardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String,
      universityName: json['university_name'] as String,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      isAvailable: json['is_available'] as bool? ?? true,
      condition: json['condition'] as String?,
    );
  }
}
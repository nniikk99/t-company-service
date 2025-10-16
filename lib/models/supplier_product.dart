class SupplierProduct {
  final String id;
  final String supplierId;
  
  // Основная информация
  final String name;
  final String? description;
  final String category; // 'equipment', 'parts', 'service_package'
  final String? subcategory;
  
  // Для оборудования
  final String? manufacturer;
  final String? model;
  final Map<String, dynamic>? specifications;
  
  // Для запчастей
  final String? sku;
  final String? partNumber;
  final List<String>? compatibleModels;
  
  // Цены и наличие
  final double basePrice;
  final String currency;
  final bool inStock;
  final int? stockQuantity;
  final int minOrderQuantity;
  
  // Медиа
  final List<String>? images;
  final List<String>? videos;
  final List<String>? documents;
  
  // SEO и маркетинг
  final List<String>? tags;
  final bool isFeatured;
  final bool isBestseller;
  final double discountPercent;
  
  // Статистика
  final int viewsCount;
  final int ordersCount;
  final double rating;
  final int reviewsCount;
  
  // Статус
  final String status; // 'draft', 'active', 'inactive', 'archived'
  final DateTime? publishedAt;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  SupplierProduct({
    required this.id,
    required this.supplierId,
    required this.name,
    this.description,
    required this.category,
    this.subcategory,
    this.manufacturer,
    this.model,
    this.specifications,
    this.sku,
    this.partNumber,
    this.compatibleModels,
    required this.basePrice,
    this.currency = 'RUB',
    this.inStock = true,
    this.stockQuantity,
    this.minOrderQuantity = 1,
    this.images,
    this.videos,
    this.documents,
    this.tags,
    this.isFeatured = false,
    this.isBestseller = false,
    this.discountPercent = 0.0,
    this.viewsCount = 0,
    this.ordersCount = 0,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.status = 'draft',
    this.publishedAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupplierProduct.fromJson(Map<String, dynamic> json) {
    return SupplierProduct(
      id: json['id'],
      supplierId: json['supplier_id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      subcategory: json['subcategory'],
      manufacturer: json['manufacturer'],
      model: json['model'],
      specifications: json['specifications'],
      sku: json['sku'],
      partNumber: json['part_number'],
      compatibleModels: json['compatible_models'] != null 
          ? List<String>.from(json['compatible_models'])
          : null,
      basePrice: (json['base_price'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'RUB',
      inStock: json['in_stock'] ?? true,
      stockQuantity: json['stock_quantity'],
      minOrderQuantity: json['min_order_quantity'] ?? 1,
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      videos: json['videos'] != null ? List<String>.from(json['videos']) : null,
      documents: json['documents'] != null ? List<String>.from(json['documents']) : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      isFeatured: json['is_featured'] ?? false,
      isBestseller: json['is_bestseller'] ?? false,
      discountPercent: (json['discount_percent'] ?? 0.0).toDouble(),
      viewsCount: json['views_count'] ?? 0,
      ordersCount: json['orders_count'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewsCount: json['reviews_count'] ?? 0,
      status: json['status'] ?? 'draft',
      publishedAt: json['published_at'] != null ? DateTime.parse(json['published_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'name': name,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'manufacturer': manufacturer,
      'model': model,
      'specifications': specifications,
      'sku': sku,
      'part_number': partNumber,
      'compatible_models': compatibleModels,
      'base_price': basePrice,
      'currency': currency,
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'min_order_quantity': minOrderQuantity,
      'images': images,
      'videos': videos,
      'documents': documents,
      'tags': tags,
      'is_featured': isFeatured,
      'is_bestseller': isBestseller,
      'discount_percent': discountPercent,
      'views_count': viewsCount,
      'orders_count': ordersCount,
      'rating': rating,
      'reviews_count': reviewsCount,
      'status': status,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Вычисляемая цена с учетом скидки
  double get finalPrice => basePrice * (1 - discountPercent / 100);

  // Проверка доступности
  bool get isAvailable => inStock && status == 'active';

  SupplierProduct copyWith({
    String? id,
    String? supplierId,
    String? name,
    String? description,
    String? category,
    String? subcategory,
    String? manufacturer,
    String? model,
    Map<String, dynamic>? specifications,
    String? sku,
    String? partNumber,
    List<String>? compatibleModels,
    double? basePrice,
    String? currency,
    bool? inStock,
    int? stockQuantity,
    int? minOrderQuantity,
    List<String>? images,
    List<String>? videos,
    List<String>? documents,
    List<String>? tags,
    bool? isFeatured,
    bool? isBestseller,
    double? discountPercent,
    int? viewsCount,
    int? ordersCount,
    double? rating,
    int? reviewsCount,
    String? status,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierProduct(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      specifications: specifications ?? this.specifications,
      sku: sku ?? this.sku,
      partNumber: partNumber ?? this.partNumber,
      compatibleModels: compatibleModels ?? this.compatibleModels,
      basePrice: basePrice ?? this.basePrice,
      currency: currency ?? this.currency,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      documents: documents ?? this.documents,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      isBestseller: isBestseller ?? this.isBestseller,
      discountPercent: discountPercent ?? this.discountPercent,
      viewsCount: viewsCount ?? this.viewsCount,
      ordersCount: ordersCount ?? this.ordersCount,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

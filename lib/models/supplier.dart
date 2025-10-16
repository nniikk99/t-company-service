class Supplier {
  final String id;
  final String userId;
  final String companyName;
  final String? companyInn;
  final String? companyDescription;
  final String? logoUrl;
  final String? website;
  final double rating;
  final int reviewsCount;
  final bool isVerified;
  final bool isActive;
  
  // Контактная информация
  final String? contactEmail;
  final String? contactPhone;
  final String? supportEmail;
  final String? supportPhone;
  
  // Адрес и реквизиты
  final String? legalAddress;
  final String? actualAddress;
  final Map<String, dynamic>? bankDetails;
  
  // Документы верификации
  final Map<String, dynamic>? documents;
  final String verificationStatus; // 'pending', 'approved', 'rejected'
  final DateTime? verifiedAt;
  final String? verifiedBy;
  
  // Настройки маркетплейса
  final double commissionRate;
  final String? paymentTerms;
  final String? deliveryTerms;
  final String? warrantyPolicy;
  final String? returnPolicy;
  
  // Статистика
  final double totalSales;
  final int totalOrders;
  final int activeProducts;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  Supplier({
    required this.id,
    required this.userId,
    required this.companyName,
    this.companyInn,
    this.companyDescription,
    this.logoUrl,
    this.website,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.isVerified = false,
    this.isActive = true,
    this.contactEmail,
    this.contactPhone,
    this.supportEmail,
    this.supportPhone,
    this.legalAddress,
    this.actualAddress,
    this.bankDetails,
    this.documents,
    this.verificationStatus = 'pending',
    this.verifiedAt,
    this.verifiedBy,
    this.commissionRate = 5.0,
    this.paymentTerms,
    this.deliveryTerms,
    this.warrantyPolicy,
    this.returnPolicy,
    this.totalSales = 0.0,
    this.totalOrders = 0,
    this.activeProducts = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      userId: json['user_id'],
      companyName: json['company_name'],
      companyInn: json['company_inn'],
      companyDescription: json['company_description'],
      logoUrl: json['logo_url'],
      website: json['website'],
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewsCount: json['reviews_count'] ?? 0,
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      contactEmail: json['contact_email'],
      contactPhone: json['contact_phone'],
      supportEmail: json['support_email'],
      supportPhone: json['support_phone'],
      legalAddress: json['legal_address'],
      actualAddress: json['actual_address'],
      bankDetails: json['bank_details'],
      documents: json['documents'],
      verificationStatus: json['verification_status'] ?? 'pending',
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at']) : null,
      verifiedBy: json['verified_by'],
      commissionRate: (json['commission_rate'] ?? 5.0).toDouble(),
      paymentTerms: json['payment_terms'],
      deliveryTerms: json['delivery_terms'],
      warrantyPolicy: json['warranty_policy'],
      returnPolicy: json['return_policy'],
      totalSales: (json['total_sales'] ?? 0.0).toDouble(),
      totalOrders: json['total_orders'] ?? 0,
      activeProducts: json['active_products'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_name': companyName,
      'company_inn': companyInn,
      'company_description': companyDescription,
      'logo_url': logoUrl,
      'website': website,
      'rating': rating,
      'reviews_count': reviewsCount,
      'is_verified': isVerified,
      'is_active': isActive,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'support_email': supportEmail,
      'support_phone': supportPhone,
      'legal_address': legalAddress,
      'actual_address': actualAddress,
      'bank_details': bankDetails,
      'documents': documents,
      'verification_status': verificationStatus,
      'verified_at': verifiedAt?.toIso8601String(),
      'verified_by': verifiedBy,
      'commission_rate': commissionRate,
      'payment_terms': paymentTerms,
      'delivery_terms': deliveryTerms,
      'warranty_policy': warrantyPolicy,
      'return_policy': returnPolicy,
      'total_sales': totalSales,
      'total_orders': totalOrders,
      'active_products': activeProducts,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Supplier copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? companyInn,
    String? companyDescription,
    String? logoUrl,
    String? website,
    double? rating,
    int? reviewsCount,
    bool? isVerified,
    bool? isActive,
    String? contactEmail,
    String? contactPhone,
    String? supportEmail,
    String? supportPhone,
    String? legalAddress,
    String? actualAddress,
    Map<String, dynamic>? bankDetails,
    Map<String, dynamic>? documents,
    String? verificationStatus,
    DateTime? verifiedAt,
    String? verifiedBy,
    double? commissionRate,
    String? paymentTerms,
    String? deliveryTerms,
    String? warrantyPolicy,
    String? returnPolicy,
    double? totalSales,
    int? totalOrders,
    int? activeProducts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      companyInn: companyInn ?? this.companyInn,
      companyDescription: companyDescription ?? this.companyDescription,
      logoUrl: logoUrl ?? this.logoUrl,
      website: website ?? this.website,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      legalAddress: legalAddress ?? this.legalAddress,
      actualAddress: actualAddress ?? this.actualAddress,
      bankDetails: bankDetails ?? this.bankDetails,
      documents: documents ?? this.documents,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      commissionRate: commissionRate ?? this.commissionRate,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      deliveryTerms: deliveryTerms ?? this.deliveryTerms,
      warrantyPolicy: warrantyPolicy ?? this.warrantyPolicy,
      returnPolicy: returnPolicy ?? this.returnPolicy,
      totalSales: totalSales ?? this.totalSales,
      totalOrders: totalOrders ?? this.totalOrders,
      activeProducts: activeProducts ?? this.activeProducts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

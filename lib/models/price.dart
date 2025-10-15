class Price {
  final String id;
  final String clientId;               // Для обратной совместимости
  final String? companyId;             // Новое поле для Supabase
  final String itemName;
  final String description;
  final double cost;
  final String unit;

  Price({
    required this.id,
    required this.clientId,
    this.companyId,
    required this.itemName,
    required this.description,
    required this.cost,
    required this.unit,
  });

  factory Price.fromJson(Map<String, dynamic> json) {
    return Price(
      id: json['id'],
      clientId: json['client_id'] ?? json['company_id'] ?? '',
      companyId: json['company_id'],
      itemName: json['item_name'],
      description: json['description'],
      cost: (json['cost'] as num).toDouble(),
      unit: json['unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'company_id': companyId,
      'item_name': itemName,
      'description': description,
      'cost': cost,
      'unit': unit,
    };
  }
}

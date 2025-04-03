class Drink {
  final int id;
  final String name;
  final int stock;
  final String category;
  final int? manufacturerId;
  final String? manufacturerName; // This will be used for display only, not storage

  Drink({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    this.manufacturerId,
    this.manufacturerName,
  });

  // Modified toMap to exclude manufacturer_name
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'stock': stock,
      'category': category,
      'manufacturer_id': manufacturerId,
      // Remove manufacturer_name as it's not in the database
    };
  }

  factory Drink.fromMap(Map<String, dynamic> map) {
    return Drink(
      id: map['id'] ?? 0,
      name: map['name'] ?? "Unknown",
      category: map['category'] ?? "Uncategorized",
      stock: map['stock'] ?? 0,
      manufacturerId: map['manufacturer_id'],
      manufacturerName: map['manufacturer_name'], // Keep this for JOIN queries
    );
  }

  Drink copyWith({
    int? id,
    String? name,
    int? stock,
    String? category,
    int? manufacturerId,
    String? manufacturerName,
  }) {
    return Drink(
      id: id ?? this.id,
      name: name ?? this.name,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      manufacturerName: manufacturerName ?? this.manufacturerName,
    );
  }

  // Usage:
  // Drink cola = Drink(id: 1, name: "Cola", category: "Soft Drink", stock: 10);
  // Drink updatedCola = cola.copyWith(stock: 15); 

}

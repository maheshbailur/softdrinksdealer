class Drink {
  final int id;
  final String name;
  final int stock; // Current stock
  final String category;
  final int? manufacturerId; // Foreign key to Manufacturers table
  final String? manufacturerName;

  Drink({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    this.manufacturerId,
    this.manufacturerName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'stock': stock,
      'category': category,
      'manufacturer_id': manufacturerId,
      'manufacturer_name': manufacturerName,
    };
  }

  factory Drink.fromMap(Map<String, dynamic> map) {
    return Drink(
      id: map['id'] ?? 0, // Ensure 'id' is not null
      name: map['name'] ?? "Unknown", // ✅ Prevent null string issue
      category: map['category'] ?? "Uncategorized", // ✅ Default category
      stock: map['stock'] ?? 0, // ✅ Default stock to 0
      manufacturerId: map['manufacturer_id'], // Nullable, so no default needed
      manufacturerName: map['manufacturer_name'] ?? "Unknown Manufacturer",
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

class Transaction {
  final int id;
  final int drinkId;
  final int quantity;
  final double price;
  final int? manufacturerId; // For IN transactions
  final int? purchaserId; // For OUT transactions
  final String transactionType; // "in" or "out"
  final DateTime transactionDate;

  Transaction({
    required this.id,
    required this.drinkId,
    required this.quantity,
    required this.price,
    this.manufacturerId, // Optional for OUT transactions
    this.purchaserId, // Optional for IN transactions
    required this.transactionType,
    required this.transactionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'drink_id': drinkId,
      'quantity': quantity,
      'price': price,
      'manufacturer_id': manufacturerId,
      'purchaser_id': purchaserId,
      'transaction_type': transactionType,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      drinkId: map['drink_id'],
      quantity: map['quantity'],
      price: map['price'],
      manufacturerId: map['manufacturer_id'],
      purchaserId: map['purchaser_id'],
      transactionType: map['transaction_type'],
      transactionDate: DateTime.parse(map['transaction_date']),
    );
  }

  Transaction copyWith({
    int? id,
    int? drinkId,
    int? quantity,
    double? price,
    int? manufacturerId,
    int? purchaserId,
    String? transactionType,
    DateTime? transactionDate,
  }) {
    return Transaction(
      id: id ?? this.id,
      drinkId: drinkId ?? this.drinkId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      purchaserId: purchaserId ?? this.purchaserId,
      transactionType: transactionType ?? this.transactionType,
      transactionDate: transactionDate ?? this.transactionDate,
    );
  }
}

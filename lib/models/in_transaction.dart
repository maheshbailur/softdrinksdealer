class InTransaction {
  final int id;
  final int drinkId;
  final int quantity;
  final double price;
  final DateTime transactionDate;
  final String? drinkName;
  final String? manufacturerName;

  InTransaction({
    required this.id,
    required this.drinkId,
    required this.quantity,
    required this.price,
    required this.transactionDate,
    this.drinkName,
    this.manufacturerName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'drink_id': drinkId,
      'quantity': quantity,
      'price': price,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }

  factory InTransaction.fromMap(Map<String, dynamic> map) {
    return InTransaction(
      id: map['id'],
      drinkId: map['drink_id'],
      quantity: map['quantity'],
      price: map['price'],
      transactionDate: DateTime.parse(map['transaction_date']),
      drinkName: map['drink_name'],
      manufacturerName: map['manufacturer_name'],
    );
  }
}

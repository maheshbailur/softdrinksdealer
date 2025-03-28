class OutTransaction {
  final int id;
  final int drinkId;
  final int quantity;
  final double price;
  final int purchaserId;
  final DateTime transactionDate;

  OutTransaction({
    required this.id,
    required this.drinkId,
    required this.quantity,
    required this.price,
    required this.purchaserId,
    required this.transactionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'drink_id': drinkId,
      'quantity': quantity,
      'price': price,
      'purchaser_id': purchaserId,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }

  factory OutTransaction.fromMap(Map<String, dynamic> map) {
    return OutTransaction(
      id: map['id'],
      drinkId: map['drink_id'],
      quantity: map['quantity'],
      price: map['price'],
      purchaserId: map['purchaser_id'],
      transactionDate: DateTime.parse(map['transaction_date']),
    );
  }
}

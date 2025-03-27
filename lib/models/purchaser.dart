class Purchaser {
  final int id;
  final String name;
  final String contactInfo;

  Purchaser({
    required this.id,
    required this.name,
    required this.contactInfo,
  });

  // Convert a Purchaser object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_info': contactInfo,
    };
  }

  // Create a Purchaser object from a Map
  factory Purchaser.fromMap(Map<String, dynamic> map) {
    return Purchaser(
      id: map['id'],
      name: map['name'],
      contactInfo: map['contact_info'],
    );
  }

  // Create a copy of Purchaser with modified values
  Purchaser copyWith({
    int? id,
    String? name,
    String? contactInfo,
  }) {
    return Purchaser(
      id: id ?? this.id,
      name: name ?? this.name,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }
}

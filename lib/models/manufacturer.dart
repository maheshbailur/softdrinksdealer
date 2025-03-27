class Manufacturer {
  final int id;
  final String name;

  Manufacturer({required this.id, required this.name});

  factory Manufacturer.fromMap(Map<String, dynamic> map) {
    return Manufacturer(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}

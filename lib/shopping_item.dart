class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.notes = '',
    this.purchased = false,
    this.favourite = false,
    this.category = 'Other',
    this.assignee = '',
    this.unit = 'items',
  });

  final int id;
  final String name;
  final int quantity;
  final String notes;
  final bool purchased;
  final bool favourite;
  final String category;
  final String assignee;
  final String unit;

  ShoppingItem withPurchased(bool value) => copyWith(purchased: value);
  ShoppingItem copyWith({
    int? id,
    bool? purchased,
    bool? favourite,
    String? assignee,
  }) => ShoppingItem(
    id: id ?? this.id,
    name: name,
    quantity: quantity,
    notes: notes,
    purchased: purchased ?? this.purchased,
    favourite: favourite ?? this.favourite,
    category: category,
    assignee: assignee ?? this.assignee,
    unit: unit,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'notes': notes,
    'purchased': purchased,
    'favourite': favourite,
    'category': category,
    'assignee': assignee,
    'unit': unit,
  };
  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id: j['id'] as int,
    name: j['name'] as String,
    quantity: j['quantity'] as int,
    notes: j['notes'] as String,
    purchased: j['purchased'] as bool,
    favourite: j['favourite'] as bool,
    category: j['category'] as String,
    assignee: j['assignee'] as String,
    unit: j['unit'] as String,
  );
}

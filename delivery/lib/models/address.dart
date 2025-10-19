class Address {
  final String id;             // <-- doc id
  final String label;
  final String addressText;
  final double latitude;
  final double longitude;
  final bool isDefault;

  Address({
    required this.id,
    required this.label,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
        'Uaid': id,
        'label': label,
        'addressText': addressText,
        'Latitude': latitude,
        'Longitude': longitude,
        'isDefault': isDefault,
      };

  factory Address.fromMap(String id, Map<String, dynamic> m) => Address(
        id: id,
        label: (m['label'] ?? '') as String,
        addressText: (m['addressText'] ?? '') as String,
        latitude: (m['Latitude'] as num).toDouble(),
        longitude: (m['Longitude'] as num).toDouble(),
        isDefault: (m['isDefault'] ?? false) as bool,
      );
}

class Address {
  final String label;
  final String addressText;
  final double latitude;
  final double longitude;
  final bool isDefault;

  Address({
    required this.label,
    required this.addressText,
    required this.latitude,
    required this.longitude,
    this.isDefault = true,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'addressText': addressText,
        'Latitude': latitude,
        'Longitude': longitude,
        'isDefault': isDefault,
      };
}

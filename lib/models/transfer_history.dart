class TransferHistory {
  final String id;
  final String driverId;
  final String? driverName;
  final String? plate;
  final String fromMadiya;
  final String toMadiya;
  final String transferredBy;
  final DateTime transferredAt;

  TransferHistory({
    required this.id,
    required this.driverId,
    this.driverName,
    this.plate,
    required this.fromMadiya,
    required this.toMadiya,
    required this.transferredBy,
    required this.transferredAt,
  });

  factory TransferHistory.fromJson(Map<String, dynamic> json) {
    return TransferHistory(
      id: json['id'].toString(),
      driverId: json['driver_id'],
      driverName: json['driver_name'],
      plate: json['plate'],
      fromMadiya: json['from_madiya'],
      toMadiya: json['to_madiya'],
      transferredBy: json['transferred_by'],
      transferredAt: DateTime.parse(json['transferred_at']),
    );
  }
}

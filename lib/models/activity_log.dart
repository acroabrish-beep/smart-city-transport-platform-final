class ActivityLog {
  final String? id;
  final String actionType; // 'Transfer', 'Check-in', 'Booking', 'Status Update'
  final String performedBy;
  final String? stationId;
  final String vehiclePlate;
  final String details;
  final DateTime? createdAt;

  ActivityLog({
    this.id,
    required this.actionType,
    required this.performedBy,
    this.stationId,
    required this.vehiclePlate,
    required this.details,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'action_type': actionType,
      'performed_by': performedBy,
      'station_id': stationId,
      'vehicle_plate': vehiclePlate,
      'details': details,
    };
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'].toString(),
      actionType: json['action_type'],
      performedBy: json['performed_by'],
      stationId: json['station_id'],
      vehiclePlate: json['vehicle_plate'],
      details: json['details'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

class Driver {
  final String id;
  final String name;
  final String phone;
  final String fayda;
  final String plate;
  final String type;
  final String? fuelType;
  final String madiya;
  final String status;
  final String day;
  final String timeSlot;
  final String liveStatus;
  final DateTime createdAt;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.fayda,
    required this.plate,
    required this.type,
    this.fuelType,
    required this.madiya,
    required this.status,
    required this.day,
    required this.timeSlot,
    required this.liveStatus,
    required this.createdAt,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      fayda: json['fayda'],
      plate: json['plate'],
      type: json['type'],
      fuelType: json['fuel_type'],
      madiya: json['madiya'],
      status: json['status'],
      day: json['day'],
      timeSlot: json['time_slot'],
      liveStatus: json['live_status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'fayda': fayda,
      'plate': plate,
      'type': type,
      'fuel_type': fuelType,
      'madiya': madiya,
      'status': status,
      'day': day,
      'time_slot': timeSlot,
      'live_status': liveStatus,
    };
  }

  Driver copyWith({
    String? status,
    String? day,
    String? timeSlot,
    String? liveStatus,
    String? madiya,
  }) {
    return Driver(
      id: id,
      name: name,
      phone: phone,
      fayda: fayda,
      plate: plate,
      type: type,
      fuelType: fuelType,
      madiya: madiya ?? this.madiya,
      status: status ?? this.status,
      day: day ?? this.day,
      timeSlot: timeSlot ?? this.timeSlot,
      liveStatus: liveStatus ?? this.liveStatus,
      createdAt: createdAt,
    );
  }
}

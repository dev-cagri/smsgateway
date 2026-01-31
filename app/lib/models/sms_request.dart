class SmsRequest {
  final int id;
  final String phoneNumber;
  final String message;
  final int priority;
  final String? scheduledAt;

  SmsRequest({
    required this.id,
    required this.phoneNumber,
    required this.message,
    required this.priority,
    this.scheduledAt,
  });

  factory SmsRequest.fromJson(Map<String, dynamic> json) {
    return SmsRequest(
      id: json['id'] as int,
      phoneNumber: json['phone_number'] as String,
      message: json['message'] as String,
      priority: json['priority'] as int? ?? 5,
      scheduledAt: json['scheduled_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'message': message,
      'priority': priority,
      'scheduled_at': scheduledAt,
    };
  }
}

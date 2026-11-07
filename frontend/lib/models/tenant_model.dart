class Tenant {
  final int id;
  final String email;
  final String businessName;
  final String businessLogo;
  final String contactNumber;
  final String schemaName;
  final String validFrom;
  final String validTo;
  final String status;
  final int daysRemaining;
  final bool isActive;
  final String createdAt;

  Tenant({
    required this.id,
    required this.email,
    this.businessName = 'ProGold Business',
    this.businessLogo = '',
    required this.contactNumber,
    required this.schemaName,
    required this.validFrom,
    required this.validTo,
    required this.status,
    this.daysRemaining = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      email: json['email'] ?? '',
      businessName: json['business_name']?.toString().isNotEmpty == true
          ? json['business_name']
          : 'ProGold Business',
      businessLogo: json['business_logo'] ?? '',
      contactNumber: json['contact_number'] ?? '',
      schemaName: json['schema_name'] ?? '',
      validFrom: json['valid_from'] ?? '',
      validTo: json['valid_to'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      daysRemaining: json['days_remaining'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'business_name': businessName,
      'business_logo': businessLogo,
      'contact_number': contactNumber,
      'schema_name': schemaName,
      'valid_from': validFrom,
      'valid_to': validTo,
      'status': status,
      'days_remaining': daysRemaining,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }

  Tenant copyWith({
    String? businessName,
    String? businessLogo,
    String? contactNumber,
  }) {
    return Tenant(
      id: id,
      email: email,
      businessName: businessName ?? this.businessName,
      businessLogo: businessLogo ?? this.businessLogo,
      contactNumber: contactNumber ?? this.contactNumber,
      schemaName: schemaName,
      validFrom: validFrom,
      validTo: validTo,
      status: status,
      daysRemaining: daysRemaining,
      isActive: isActive,
      createdAt: createdAt,
    );
  }
}

class DatabaseTestResult {
  final bool success;
  final String message;
  final int latencyMs;

  DatabaseTestResult({
    required this.success,
    required this.message,
    this.latencyMs = 0,
  });

  factory DatabaseTestResult.fromJson(Map<String, dynamic> json) {
    return DatabaseTestResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      latencyMs: json['latencyMs'] ?? 0,
    );
  }
}

class TableOverview {
  final String name;
  final String type;
  final String sql;
  final int rowCount;

  TableOverview({
    required this.name,
    required this.type,
    required this.sql,
    required this.rowCount,
  });

  factory TableOverview.fromJson(Map<String, dynamic> json) {
    return TableOverview(
      name: json['name'] ?? '',
      type: json['type'] ?? 'table',
      sql: json['sql'] ?? '',
      rowCount: json['rowCount'] ?? 0,
    );
  }
}

class QueryResult {
  final bool success;
  final List<String> columns;
  final List<dynamic> rows;
  final int rowsAffected;
  final int executionTimeMs;
  final String? message;

  QueryResult({
    required this.success,
    this.columns = const [],
    this.rows = const [],
    this.rowsAffected = 0,
    this.executionTimeMs = 0,
    this.message,
  });

  factory QueryResult.fromJson(Map<String, dynamic> json) {
    List<String> cols = [];
    if (json['columns'] is List) {
      cols = (json['columns'] as List).map((e) => e.toString()).toList();
    }

    return QueryResult(
      success: json['success'] ?? false,
      columns: cols,
      rows: json['rows'] is List ? json['rows'] : [],
      rowsAffected: json['rowsAffected'] ?? 0,
      executionTimeMs: json['executionTimeMs'] ?? 0,
      message: json['message'],
    );
  }
}

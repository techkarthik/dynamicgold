class SystemControlRecord {
  final int? sno;
  final String ctlid;
  final String ctlname;
  final String ctlvalue;
  final String module; // 'MASTER', 'STOCK', 'POS', 'REPORTS', 'DIGIGOLD', 'CRM', 'SETTINGS', 'GENERAL'
  final String branchId; // 'ALL' or specific branchid
  final String? branchname;
  final String? branchcode;
  final String? createdAt;
  final String? updatedAt;

  SystemControlRecord({
    this.sno,
    required this.ctlid,
    required this.ctlname,
    required this.ctlvalue,
    this.module = 'GENERAL',
    this.branchId = 'ALL',
    this.branchname,
    this.branchcode,
    this.createdAt,
    this.updatedAt,
  });

  factory SystemControlRecord.fromJson(Map<String, dynamic> json) {
    return SystemControlRecord(
      sno: json['sno'] != null ? int.tryParse(json['sno'].toString()) : null,
      ctlid: json['ctlid']?.toString() ?? '',
      ctlname: json['ctlname']?.toString() ?? '',
      ctlvalue: json['ctlvalue']?.toString() ?? '',
      module: json['module']?.toString() ?? 'GENERAL',
      branchId: json['branch_id']?.toString() ?? 'ALL',
      branchname: json['branchname']?.toString(),
      branchcode: json['branchcode']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (sno != null) 'sno': sno,
      'ctlid': ctlid,
      'ctlname': ctlname,
      'ctlvalue': ctlvalue,
      'module': module,
      'branch_id': branchId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  SystemControlRecord copyWith({
    int? sno,
    String? ctlid,
    String? ctlname,
    String? ctlvalue,
    String? module,
    String? branchId,
    String? branchname,
    String? branchcode,
    String? createdAt,
    String? updatedAt,
  }) {
    return SystemControlRecord(
      sno: sno ?? this.sno,
      ctlid: ctlid ?? this.ctlid,
      ctlname: ctlname ?? this.ctlname,
      ctlvalue: ctlvalue ?? this.ctlvalue,
      module: module ?? this.module,
      branchId: branchId ?? this.branchId,
      branchname: branchname ?? this.branchname,
      branchcode: branchcode ?? this.branchcode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

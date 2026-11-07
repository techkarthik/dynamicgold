class TaxRecord {
  final int? taxid;
  final String taxcode;
  final String taxname;
  final double sgstPer;
  final String sgstacname;
  final double cgstPer;
  final String cgstacname;
  final double igstPer;
  final String igstacname;
  final String? createdAt;
  final String? updatedAt;

  TaxRecord({
    this.taxid,
    required this.taxcode,
    required this.taxname,
    this.sgstPer = 0.0,
    this.sgstacname = '',
    this.cgstPer = 0.0,
    this.cgstacname = '',
    this.igstPer = 0.0,
    this.igstacname = '',
    this.createdAt,
    this.updatedAt,
  });

  factory TaxRecord.fromJson(Map<String, dynamic> json) {
    return TaxRecord(
      taxid: json['taxid'] != null ? int.tryParse(json['taxid'].toString()) : null,
      taxcode: json['taxcode']?.toString() ?? '',
      taxname: json['taxname']?.toString() ?? '',
      sgstPer: json['sgst_per'] != null ? double.tryParse(json['sgst_per'].toString()) ?? 0.0 : 0.0,
      sgstacname: json['sgstacname']?.toString() ?? '',
      cgstPer: json['cgst_per'] != null ? double.tryParse(json['cgst_per'].toString()) ?? 0.0 : 0.0,
      cgstacname: json['cgstacname']?.toString() ?? '',
      igstPer: json['igst_per'] != null ? double.tryParse(json['igst_per'].toString()) ?? 0.0 : 0.0,
      igstacname: json['igstacname']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (taxid != null) 'taxid': taxid,
      'taxcode': taxcode,
      'taxname': taxname,
      'sgst_per': sgstPer,
      'sgstacname': sgstacname,
      'cgst_per': cgstPer,
      'cgstacname': cgstacname,
      'igst_per': igstPer,
      'igstacname': igstacname,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  TaxRecord copyWith({
    int? taxid,
    String? taxcode,
    String? taxname,
    double? sgstPer,
    String? sgstacname,
    double? cgstPer,
    String? cgstacname,
    double? igstPer,
    String? igstacname,
    String? createdAt,
    String? updatedAt,
  }) {
    return TaxRecord(
      taxid: taxid ?? this.taxid,
      taxcode: taxcode ?? this.taxcode,
      taxname: taxname ?? this.taxname,
      sgstPer: sgstPer ?? this.sgstPer,
      sgstacname: sgstacname ?? this.sgstacname,
      cgstPer: cgstPer ?? this.cgstPer,
      cgstacname: cgstacname ?? this.cgstacname,
      igstPer: igstPer ?? this.igstPer,
      igstacname: igstacname ?? this.igstacname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EmployeeRecord {
  final int? empid;
  final String empname;
  final String branchid;
  final String branchname;
  final String dateofjoin;
  final bool active;
  final String bloodgroup;
  final String mobile;
  final String email;
  final String address;
  final String image;
  final String? createdAt;
  final String? updatedAt;

  EmployeeRecord({
    this.empid,
    required this.empname,
    required this.branchid,
    this.branchname = '',
    this.dateofjoin = '',
    this.active = true,
    this.bloodgroup = '',
    this.mobile = '',
    this.email = '',
    this.address = '',
    this.image = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => active;

  factory EmployeeRecord.fromJson(Map<String, dynamic> json) {
    final rawActive = json['active'] ?? json['is_active'];
    final bool activeBool = rawActive is bool
        ? rawActive
        : (rawActive == 1 || rawActive == '1' || rawActive == 'true');

    return EmployeeRecord(
      empid: json['empid'] != null ? int.tryParse(json['empid'].toString()) : null,
      empname: json['empname']?.toString() ?? '',
      branchid: json['branchid']?.toString().trim().toUpperCase() ?? '',
      branchname: json['branchname']?.toString() ?? '',
      dateofjoin: json['dateofjoin']?.toString() ?? '',
      active: activeBool,
      bloodgroup: json['bloodgroup']?.toString().trim().toUpperCase() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (empid != null) 'empid': empid,
      'empname': empname,
      'branchid': branchid,
      'dateofjoin': dateofjoin,
      'active': active ? 1 : 0,
      'bloodgroup': bloodgroup,
      'mobile': mobile,
      'email': email,
      'address': address,
      'image': image,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  EmployeeRecord copyWith({
    int? empid,
    String? empname,
    String? branchid,
    String? branchname,
    String? dateofjoin,
    bool? active,
    String? bloodgroup,
    String? mobile,
    String? email,
    String? address,
    String? image,
    String? createdAt,
    String? updatedAt,
  }) {
    return EmployeeRecord(
      empid: empid ?? this.empid,
      empname: empname ?? this.empname,
      branchid: branchid ?? this.branchid,
      branchname: branchname ?? this.branchname,
      dateofjoin: dateofjoin ?? this.dateofjoin,
      active: active ?? this.active,
      bloodgroup: bloodgroup ?? this.bloodgroup,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      image: image ?? this.image,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

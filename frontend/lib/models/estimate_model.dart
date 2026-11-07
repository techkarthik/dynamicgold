import 'dart:convert';

class EstimateItem {
  final String skuCode;
  final String productName;
  final String subProductName;
  final String purityName;
  final double grossWeight;
  final double netWeight;
  final int stonePcs;
  final double stoneWeight;
  final double stoneSellingPrice;
  final int diamondPcs;
  final double diamondWeight;
  final double diamondSellingPrice;
  final double vaPercent;
  final double mc;
  final double boardRate;
  final double gstRate;
  final double gstAmount;
  final double totalAmount;

  EstimateItem({
    required this.skuCode,
    required this.productName,
    this.subProductName = '',
    this.purityName = '22K Gold (916)',
    required this.grossWeight,
    required this.netWeight,
    this.stonePcs = 0,
    this.stoneWeight = 0.0,
    this.stoneSellingPrice = 0.0,
    this.diamondPcs = 0,
    this.diamondWeight = 0.0,
    this.diamondSellingPrice = 0.0,
    this.vaPercent = 0.0,
    this.mc = 0.0,
    required this.boardRate,
    this.gstRate = 3.0,
    this.gstAmount = 0.0,
    required this.totalAmount,
  });

  /// Computed Metal Value: Net Weight * Board Rate
  double get metalValue => netWeight * boardRate;

  /// Computed VA Value: Metal Value * (VA% / 100)
  double get vaCharges => metalValue * (vaPercent / 100.0);

  /// Computed Taxable Subtotal before GST
  double get taxableSubtotal => metalValue + vaCharges + mc + stoneSellingPrice + diamondSellingPrice;

  factory EstimateItem.fromJson(Map<String, dynamic> json) {
    return EstimateItem(
      skuCode: json['sku_code']?.toString() ?? json['barcode']?.toString() ?? '',
      productName: json['productname']?.toString() ?? json['product_name']?.toString() ?? json['item_name']?.toString() ?? 'Jewellery Item',
      subProductName: json['subproductname']?.toString() ?? json['subproduct_name']?.toString() ?? '',
      purityName: json['purityname']?.toString() ?? json['purity_name']?.toString() ?? '22K Gold (916)',
      grossWeight: (json['gross_weight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['net_weight'] as num?)?.toDouble() ?? 0.0,
      stonePcs: int.tryParse(json['stone_pcs']?.toString() ?? '0') ?? 0,
      stoneWeight: (json['stone_weight'] as num?)?.toDouble() ?? 0.0,
      stoneSellingPrice: (json['stone_selling_price'] as num?)?.toDouble() ?? (json['stone_amt'] as num?)?.toDouble() ?? (json['stone_charges'] as num?)?.toDouble() ?? 0.0,
      diamondPcs: int.tryParse(json['diamond_pcs']?.toString() ?? '0') ?? 0,
      diamondWeight: (json['diamond_weight'] as num?)?.toDouble() ?? 0.0,
      diamondSellingPrice: (json['diamond_selling_price'] as num?)?.toDouble() ?? (json['diamond_amt'] as num?)?.toDouble() ?? (json['diamond_charges'] as num?)?.toDouble() ?? 0.0,
      vaPercent: (json['va_percent'] as num?)?.toDouble() ?? (json['sales_va_percent'] as num?)?.toDouble() ?? (json['wastage_percent'] as num?)?.toDouble() ?? 0.0,
      mc: (json['mc'] as num?)?.toDouble() ?? (json['making_charges'] as num?)?.toDouble() ?? (json['sales_m_charge'] as num?)?.toDouble() ?? 0.0,
      boardRate: (json['board_rate'] as num?)?.toDouble() ?? (json['rate_per_gram'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 3.0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku_code': skuCode,
      'productname': productName,
      'subproductname': subProductName,
      'purityname': purityName,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'stone_pcs': stonePcs,
      'stone_weight': stoneWeight,
      'stone_selling_price': stoneSellingPrice,
      'diamond_pcs': diamondPcs,
      'diamond_weight': diamondWeight,
      'diamond_selling_price': diamondSellingPrice,
      'va_percent': vaPercent,
      'mc': mc,
      'board_rate': boardRate,
      'gst_rate': gstRate,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
    };
  }
}

class EstimateRecord {
  final int? estimateId;
  final String estimateNo;
  final String customerName;
  final String customerMobile;
  final String customerAddress;
  final int? employeeId;
  final String? employeeCode;
  final String? employeeName;
  final double grossWeight;
  final double netWeight;
  final double totalMetalValue;
  final double totalMakingCharges;
  final double totalStoneCharges;
  final double totalDiamondCharges;
  final double totalVaCharges;
  final double taxableAmount;
  final double gstRate;
  final double taxAmount;
  final double netAmount;
  final String status; // 'OPEN', 'CONVERTED', 'CANCELLED'
  final List<EstimateItem> items;
  final String notes;
  final String? createdAt;
  final String? updatedAt;

  EstimateRecord({
    this.estimateId,
    required this.estimateNo,
    required this.customerName,
    this.customerMobile = '',
    this.customerAddress = '',
    this.employeeId,
    this.employeeCode,
    this.employeeName,
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
    this.totalMetalValue = 0.0,
    this.totalMakingCharges = 0.0,
    this.totalStoneCharges = 0.0,
    this.totalDiamondCharges = 0.0,
    this.totalVaCharges = 0.0,
    this.taxableAmount = 0.0,
    this.gstRate = 3.0,
    this.taxAmount = 0.0,
    this.netAmount = 0.0,
    this.status = 'OPEN',
    this.items = const [],
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory EstimateRecord.fromJson(Map<String, dynamic> json) {
    List<EstimateItem> parsedItems = [];
    final rawItems = json['items_json'];
    if (rawItems is List) {
      parsedItems = rawItems.map((e) => EstimateItem.fromJson(e as Map<String, dynamic>)).toList();
    } else if (rawItems is String && rawItems.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          parsedItems = decoded.map((e) => EstimateItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {
        parsedItems = [];
      }
    }

    return EstimateRecord(
      estimateId: json['estimate_id'] != null ? int.tryParse(json['estimate_id'].toString()) : null,
      estimateNo: json['estimate_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      customerMobile: json['customer_mobile']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      employeeId: json['employee_id'] != null ? int.tryParse(json['employee_id'].toString()) : null,
      employeeCode: json['employee_code']?.toString(),
      employeeName: json['employee_name']?.toString() ?? json['ref_employee_name']?.toString(),
      grossWeight: (json['gross_weight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['net_weight'] as num?)?.toDouble() ?? 0.0,
      totalMetalValue: (json['total_metal_value'] as num?)?.toDouble() ?? 0.0,
      totalMakingCharges: (json['total_making_charges'] as num?)?.toDouble() ?? 0.0,
      totalStoneCharges: (json['total_stone_charges'] as num?)?.toDouble() ?? 0.0,
      totalDiamondCharges: (json['total_diamond_charges'] as num?)?.toDouble() ?? 0.0,
      totalVaCharges: (json['total_va_charges'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxable_amount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 3.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString().toUpperCase() ?? 'OPEN',
      items: parsedItems,
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (estimateId != null) 'estimate_id': estimateId,
      'estimate_no': estimateNo,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'customer_address': customerAddress,
      if (employeeId != null) 'employee_id': employeeId,
      if (employeeCode != null) 'employee_code': employeeCode,
      if (employeeName != null) 'employee_name': employeeName,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'total_metal_value': totalMetalValue,
      'total_making_charges': totalMakingCharges,
      'total_stone_charges': totalStoneCharges,
      'total_diamond_charges': totalDiamondCharges,
      'total_va_charges': totalVaCharges,
      'taxable_amount': taxableAmount,
      'gst_rate': gstRate,
      'tax_amount': taxAmount,
      'net_amount': netAmount,
      'status': status,
      'items_json': jsonEncode(items.map((i) => i.toJson()).toList()),
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

import 'dart:convert';

/// Represents a single customizable visual/textual element on a barcode label.
class BarcodeElement {
  final String id;
  final String type; // 'text' | 'barcode_1d' | 'barcode_2d'
  final String fieldKey; // 'sku' | 'gross_weight' | 'net_weight' | 'stone_info' | 'diamond_info' | 'purity' | 'product_name' | 'company_name' | 'board_rate' | 'sales_va_percent' | 'sales_mc' | 'sales_total_amt' | 'lot_number' | 'huid' | 'custom'
  final String labelPrefix; // e.g. 'GRSWT: ', 'S: ', 'D: ', 'BIS 916'
  final String formatTemplate; // e.g. '{gross_weight}g', 'S: {stone_pcs}/{stone_weight}g/{stone_amt}', '{diamond_pcs}/{diamond_weight}ct'
  final double xMm;
  final double yMm;
  final double widthMm;
  final double heightMm;
  final double fontSize;
  final String fontWeight; // 'normal' | 'bold'
  final String alignment; // 'left' | 'center' | 'right'
  final bool isBold;
  final bool isVisible;

  BarcodeElement({
    required this.id,
    required this.type,
    required this.fieldKey,
    this.labelPrefix = '',
    this.formatTemplate = '',
    this.xMm = 0.0,
    this.yMm = 0.0,
    this.widthMm = 30.0,
    this.heightMm = 4.0,
    this.fontSize = 7.0,
    this.fontWeight = 'normal',
    this.alignment = 'left',
    this.isBold = false,
    this.isVisible = true,
  });

  factory BarcodeElement.fromJson(Map<String, dynamic> json) {
    return BarcodeElement(
      id: json['id']?.toString() ?? 'elem_${DateTime.now().millisecondsSinceEpoch}',
      type: json['type']?.toString() ?? 'text',
      fieldKey: json['field_key']?.toString() ?? 'custom',
      labelPrefix: json['label_prefix']?.toString() ?? '',
      formatTemplate: json['format_template']?.toString() ?? '',
      xMm: (json['x_mm'] as num?)?.toDouble() ?? 0.0,
      yMm: (json['y_mm'] as num?)?.toDouble() ?? 0.0,
      widthMm: (json['width_mm'] as num?)?.toDouble() ?? 30.0,
      heightMm: (json['height_mm'] as num?)?.toDouble() ?? 4.0,
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 7.0,
      fontWeight: json['font_weight']?.toString() ?? 'normal',
      alignment: json['alignment']?.toString() ?? 'left',
      isBold: json['is_bold'] == true || json['font_weight'] == 'bold',
      isVisible: json['is_visible'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'field_key': fieldKey,
      'label_prefix': labelPrefix,
      'format_template': formatTemplate,
      'x_mm': xMm,
      'y_mm': yMm,
      'width_mm': widthMm,
      'height_mm': heightMm,
      'font_size': fontSize,
      'font_weight': isBold ? 'bold' : fontWeight,
      'alignment': alignment,
      'is_bold': isBold,
      'is_visible': isVisible,
    };
  }

  BarcodeElement copyWith({
    String? id,
    String? type,
    String? fieldKey,
    String? labelPrefix,
    String? formatTemplate,
    double? xMm,
    double? yMm,
    double? widthMm,
    double? heightMm,
    double? fontSize,
    String? fontWeight,
    String? alignment,
    bool? isBold,
    bool? isVisible,
  }) {
    return BarcodeElement(
      id: id ?? this.id,
      type: type ?? this.type,
      fieldKey: fieldKey ?? this.fieldKey,
      labelPrefix: labelPrefix ?? this.labelPrefix,
      formatTemplate: formatTemplate ?? this.formatTemplate,
      xMm: xMm ?? this.xMm,
      yMm: yMm ?? this.yMm,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      alignment: alignment ?? this.alignment,
      isBold: isBold ?? this.isBold,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

/// Represents a dynamic Barcode Label Template.
class BarcodeTemplate {
  final int? templateId;
  final String companyId;
  final String name;
  final double widthMm;
  final double heightMm;
  final String unit; // 'mm' | 'inch' | 'cm'
  final int labelsPerRow; // 1 or 2
  final double gapMm;
  final double marginTopMm;
  final double marginLeftMm;
  final String tagStyle; // 'RECTANGLE' | 'JEWELRY_BUTTERFLY' | 'JEWELRY_DUMBBELL'
  final bool isDefault;
  final List<BarcodeElement> elements;
  final String? createdAt;
  final String? updatedAt;

  BarcodeTemplate({
    this.templateId,
    this.companyId = '',
    required this.name,
    this.widthMm = 80.0,
    this.heightMm = 13.0,
    this.unit = 'mm',
    this.labelsPerRow = 2,
    this.gapMm = 2.0,
    this.marginTopMm = 1.0,
    this.marginLeftMm = 1.0,
    this.tagStyle = 'JEWELRY_BUTTERFLY',
    this.isDefault = false,
    required this.elements,
    this.createdAt,
    this.updatedAt,
  });

  /// Width in millimeters regardless of user-selected input unit
  double get effectiveWidthMm {
    if (unit == 'inch') return widthMm * 25.4;
    if (unit == 'cm') return widthMm * 10.0;
    return widthMm;
  }

  /// Height in millimeters regardless of user-selected input unit
  double get effectiveHeightMm {
    if (unit == 'inch') return heightMm * 25.4;
    if (unit == 'cm') return heightMm * 10.0;
    return heightMm;
  }

  factory BarcodeTemplate.fromJson(Map<String, dynamic> json) {
    List<BarcodeElement> elems = [];
    if (json['elements'] is List) {
      elems = (json['elements'] as List)
          .map((e) => BarcodeElement.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['elements_json'] is String) {
      try {
        final decoded = jsonDecode(json['elements_json']);
        if (decoded is List) {
          elems = decoded.map((e) => BarcodeElement.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    return BarcodeTemplate(
      templateId: (json['template_id'] as num?)?.toInt(),
      companyId: json['companyid']?.toString() ?? '',
      name: json['name']?.toString() ?? 'New Template',
      widthMm: (json['width_mm'] as num?)?.toDouble() ?? 80.0,
      heightMm: (json['height_mm'] as num?)?.toDouble() ?? 13.0,
      unit: json['unit']?.toString() ?? 'mm',
      labelsPerRow: (json['labels_per_row'] as num?)?.toInt() ?? 1,
      gapMm: (json['gap_mm'] as num?)?.toDouble() ?? 2.0,
      marginTopMm: (json['margin_top_mm'] as num?)?.toDouble() ?? 1.0,
      marginLeftMm: (json['margin_left_mm'] as num?)?.toDouble() ?? 1.0,
      tagStyle: json['tag_style']?.toString() ?? 'RECTANGLE',
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      elements: elems,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (templateId != null) 'template_id': templateId,
      'companyid': companyId,
      'name': name,
      'width_mm': widthMm,
      'height_mm': heightMm,
      'unit': unit,
      'labels_per_row': labelsPerRow,
      'gap_mm': gapMm,
      'margin_top_mm': marginTopMm,
      'margin_left_mm': marginLeftMm,
      'tag_style': tagStyle,
      'is_default': isDefault,
      'elements': elements.map((e) => e.toJson()).toList(),
    };
  }

  BarcodeTemplate copyWith({
    int? templateId,
    String? companyId,
    String? name,
    double? widthMm,
    double? heightMm,
    String? unit,
    int? labelsPerRow,
    double? gapMm,
    double? marginTopMm,
    double? marginLeftMm,
    String? tagStyle,
    bool? isDefault,
    List<BarcodeElement>? elements,
  }) {
    return BarcodeTemplate(
      templateId: templateId ?? this.templateId,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      unit: unit ?? this.unit,
      labelsPerRow: labelsPerRow ?? this.labelsPerRow,
      gapMm: gapMm ?? this.gapMm,
      marginTopMm: marginTopMm ?? this.marginTopMm,
      marginLeftMm: marginLeftMm ?? this.marginLeftMm,
      tagStyle: tagStyle ?? this.tagStyle,
      isDefault: isDefault ?? this.isDefault,
      elements: elements ?? this.elements,
    );
  }
}

/// Metadata description for available dynamic database fields
class BarcodeFieldDefinition {
  final String key;
  final String label;
  final String sampleValue;
  final String defaultFormat;
  final String category; // 'Core' | 'Weights' | 'Stones/Diamonds' | 'Pricing' | 'Company'

  const BarcodeFieldDefinition({
    required this.key,
    required this.label,
    required this.sampleValue,
    required this.defaultFormat,
    this.category = 'Core',
  });

  static const List<BarcodeFieldDefinition> registry = [
    BarcodeFieldDefinition(
      key: 'sku',
      label: 'SKU / Barcode Number',
      sampleValue: '27A001',
      defaultFormat: '{sku}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'gross_weight',
      label: 'Gross Weight (g)',
      sampleValue: '125.000',
      defaultFormat: 'GRSWT: {gross_weight}g',
      category: 'Weights',
    ),
    BarcodeFieldDefinition(
      key: 'net_weight',
      label: 'Net Gold Weight (g)',
      sampleValue: '120.500',
      defaultFormat: 'NET: {net_weight}g',
      category: 'Weights',
    ),
    BarcodeFieldDefinition(
      key: 'stone_info',
      label: 'Stone Info (S:Pcs/Wt/Amt)',
      sampleValue: 'S: 4 / 0.850g / 1,200',
      defaultFormat: 'S: {stone_pcs}/{stone_weight}g/{stone_amt}',
      category: 'Stones/Diamonds',
    ),
    BarcodeFieldDefinition(
      key: 'diamond_info',
      label: 'Diamond Info (D:Pcs/Wt/Amt)',
      sampleValue: 'D: 12 / 1.25ct / 45,000',
      defaultFormat: 'D: {diamond_pcs}/{diamond_weight}ct/{diamond_amt}',
      category: 'Stones/Diamonds',
    ),
    BarcodeFieldDefinition(
      key: 'style',
      label: 'Style / Model Name',
      sampleValue: 'BOMBAY PLAIN',
      defaultFormat: '{style}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'size',
      label: 'Item Size',
      sampleValue: '2.4',
      defaultFormat: 'SIZE: {size}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'purity',
      label: 'Ornament Purity / Karat',
      sampleValue: '22KT (916)',
      defaultFormat: '{purity}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'product_name',
      label: 'Item / Product Name',
      sampleValue: 'GOLD RING CASTING',
      defaultFormat: '{product_name}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'subproduct_name',
      label: 'Sub-product Name',
      sampleValue: 'CASTING FLOWER',
      defaultFormat: '{subproduct_name}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'company_name',
      label: 'Company / Shop Name',
      sampleValue: 'PROGOLD JEWELLERY',
      defaultFormat: '{company_name}',
      category: 'Company',
    ),
    BarcodeFieldDefinition(
      key: 'designer_name',
      label: 'Smith / Designer Name',
      sampleValue: 'NATARAJAN SMITH',
      defaultFormat: 'SMITH: {designer_name}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'board_rate',
      label: 'Gold Board Rate (/g)',
      sampleValue: '7,500',
      defaultFormat: 'RATE: {board_rate}',
      category: 'Pricing',
    ),
    BarcodeFieldDefinition(
      key: 'sales_va_percent',
      label: 'Value Addition (VA %)',
      sampleValue: '12%',
      defaultFormat: 'VA: {sales_va_percent}%',
      category: 'Pricing',
    ),
    BarcodeFieldDefinition(
      key: 'sales_mc',
      label: 'Making Charge (MC)',
      sampleValue: '450.00',
      defaultFormat: 'MC: {sales_mc}',
      category: 'Pricing',
    ),
    BarcodeFieldDefinition(
      key: 'sales_total_amt',
      label: 'Estimated Sale Price / MRP',
      sampleValue: '98,500',
      defaultFormat: 'MRP: Rs. {sales_total_amt}',
      category: 'Pricing',
    ),
    BarcodeFieldDefinition(
      key: 'lot_number',
      label: 'Source Lot Number',
      sampleValue: '2627-1',
      defaultFormat: 'LOT: {lot_number}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'huid',
      label: 'HUID (Hallmark Unique ID)',
      sampleValue: 'HUID-916ABC',
      defaultFormat: 'HUID: {huid}',
      category: 'Core',
    ),
    BarcodeFieldDefinition(
      key: 'custom',
      label: 'Custom Text / Static Label',
      sampleValue: 'BIS 916 HALLMARK',
      defaultFormat: 'BIS 916 HALLMARK',
      category: 'Company',
    ),
  ];
}

/// Represents an individual tagged SKU item in the inventory stock.
class StockTaggedItem {
  final int itemId;
  final String skuCode;
  final int lotId;
  final String lotNumber;
  final String companyId;
  final String branchId;
  final int designerId;
  final String designerName;
  final String designerAccode;
  final int productId;
  final String productName;
  final int? subproductId;
  final String subproductName;
  final int? styleId;
  final String styleName;
  final int? sizeId;
  final String sizeName;
  final int purityId;
  final String purityName;
  final double purity;
  final int pcs;
  final double grossWeight;
  final double netWeight;
  
  final int stonePcs;
  final double stoneWeight;
  final double stoneAmt;
  final List<dynamic> stoneDetails;
  
  final int diamondPcs;
  final double diamondWeight;
  final double diamondAmt;
  final List<dynamic> diamondDetails;

  // Sales Pricing
  final double boardRate;
  final double salesVaPercent;
  final double salesWastage;
  final double salesMcPerGram;
  final double salesMCharge;
  final double salesTotalAmt;

  // Purchase Costing (Smith Inward)
  final double purchaseTouchPct;
  final double purchaseGoldRate;
  final double purchaseMc;
  final double purchaseStoneCost;
  final double purchaseDiamondCost;
  final double purchaseTotalCost;

  final String huid;
  final String status;
  final int tagPrintedCount;
  final String? tagLastPrintedAt;
  final String remarks;
  final String? createdAt;
  final String? updatedAt;
  final String branchName;
  final String companyName;

  StockTaggedItem({
    required this.itemId,
    required this.skuCode,
    required this.lotId,
    required this.lotNumber,
    required this.companyId,
    required this.branchId,
    required this.designerId,
    this.designerName = '',
    this.designerAccode = '',
    required this.productId,
    this.productName = '',
    this.subproductId,
    this.subproductName = '',
    this.styleId,
    this.styleName = '',
    this.sizeId,
    this.sizeName = '',
    required this.purityId,
    this.purityName = '',
    this.purity = 0.0,
    this.pcs = 1,
    this.grossWeight = 0.0,
    this.netWeight = 0.0,
    this.stonePcs = 0,
    this.stoneWeight = 0.0,
    this.stoneAmt = 0.0,
    this.stoneDetails = const [],
    this.diamondPcs = 0,
    this.diamondWeight = 0.0,
    this.diamondAmt = 0.0,
    this.diamondDetails = const [],
    this.boardRate = 0.0,
    this.salesVaPercent = 0.0,
    this.salesWastage = 0.0,
    this.salesMcPerGram = 0.0,
    this.salesMCharge = 0.0,
    this.salesTotalAmt = 0.0,
    this.purchaseTouchPct = 0.0,
    this.purchaseGoldRate = 0.0,
    this.purchaseMc = 0.0,
    this.purchaseStoneCost = 0.0,
    this.purchaseDiamondCost = 0.0,
    this.purchaseTotalCost = 0.0,
    this.huid = '',
    this.status = 'IN_STOCK',
    this.tagPrintedCount = 0,
    this.tagLastPrintedAt,
    this.remarks = '',
    this.createdAt,
    this.updatedAt,
    this.branchName = '',
    this.companyName = '',
  });

  factory StockTaggedItem.fromJson(Map<String, dynamic> json) {
    return StockTaggedItem(
      itemId: (json['item_id'] as num?)?.toInt() ?? 0,
      skuCode: json['sku_code']?.toString() ?? '',
      lotId: (json['lot_id'] as num?)?.toInt() ?? 0,
      lotNumber: json['lot_number']?.toString() ?? '',
      companyId: json['companyid']?.toString() ?? '',
      branchId: json['branchid']?.toString() ?? '',
      designerId: (json['designerid'] as num?)?.toInt() ?? 0,
      designerName: json['designername']?.toString() ?? '',
      designerAccode: json['designer_accode']?.toString() ?? '',
      productId: (json['productid'] as num?)?.toInt() ?? 0,
      productName: json['productname']?.toString() ?? '',
      subproductId: (json['subproductid'] as num?)?.toInt(),
      subproductName: json['subproductname']?.toString() ?? '',
      styleId: (json['styleid'] as num?)?.toInt(),
      styleName: json['stylename']?.toString() ?? '',
      sizeId: (json['sizeid'] as num?)?.toInt(),
      sizeName: json['sizename']?.toString() ?? '',
      purityId: (json['purityid'] as num?)?.toInt() ?? 0,
      purityName: json['purityname']?.toString() ?? '',
      purity: (json['purity'] as num?)?.toDouble() ?? 0.0,
      pcs: (json['pcs'] as num?)?.toInt() ?? 1,
      grossWeight: (json['gross_weight'] as num?)?.toDouble() ?? 0.0,
      netWeight: (json['net_weight'] as num?)?.toDouble() ?? 0.0,
      stonePcs: (json['stone_pcs'] as num?)?.toInt() ?? 0,
      stoneWeight: (json['stone_weight'] as num?)?.toDouble() ?? 0.0,
      stoneAmt: (json['stone_amt'] as num?)?.toDouble() ?? 0.0,
      stoneDetails: json['stone_details'] is List ? json['stone_details'] : [],
      diamondPcs: (json['diamond_pcs'] as num?)?.toInt() ?? 0,
      diamondWeight: (json['diamond_weight'] as num?)?.toDouble() ?? 0.0,
      diamondAmt: (json['diamond_amt'] as num?)?.toDouble() ?? 0.0,
      diamondDetails: json['diamond_details'] is List ? json['diamond_details'] : [],
      boardRate: (json['board_rate'] as num?)?.toDouble() ?? 0.0,
      salesVaPercent: (json['sales_va_percent'] as num?)?.toDouble() ?? 0.0,
      salesWastage: (json['sales_wastage'] as num?)?.toDouble() ?? 0.0,
      salesMcPerGram: (json['sales_mc_per_gram'] as num?)?.toDouble() ?? 0.0,
      salesMCharge: (json['sales_m_charge'] as num?)?.toDouble() ?? 0.0,
      salesTotalAmt: (json['sales_total_amt'] as num?)?.toDouble() ?? 0.0,
      purchaseTouchPct: (json['purchase_touch_pct'] as num?)?.toDouble() ?? 0.0,
      purchaseGoldRate: (json['purchase_gold_rate'] as num?)?.toDouble() ?? 0.0,
      purchaseMc: (json['purchase_mc'] as num?)?.toDouble() ?? 0.0,
      purchaseStoneCost: (json['purchase_stone_cost'] as num?)?.toDouble() ?? 0.0,
      purchaseDiamondCost: (json['purchase_diamond_cost'] as num?)?.toDouble() ?? 0.0,
      purchaseTotalCost: (json['purchase_total_cost'] as num?)?.toDouble() ?? 0.0,
      huid: json['huid']?.toString() ?? '',
      status: json['status']?.toString() ?? 'IN_STOCK',
      tagPrintedCount: (json['tag_printed_count'] as num?)?.toInt() ?? 0,
      tagLastPrintedAt: json['tag_last_printed_at']?.toString(),
      remarks: json['remarks']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      branchName: json['branchname']?.toString() ?? '',
      companyName: json['companyname']?.toString() ?? '',
    );
  }

  List<TagStoneItem> get parsedStoneItems {
    return stoneDetails
        .whereType<Map<String, dynamic>>()
        .map((m) => TagStoneItem.fromJson(m))
        .toList();
  }

  List<TagDiamondItem> get parsedDiamondItems {
    return diamondDetails
        .whereType<Map<String, dynamic>>()
        .map((m) => TagDiamondItem.fromJson(m))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'sku_code': skuCode,
      'lot_id': lotId,
      'lot_number': lotNumber,
      'companyid': companyId,
      'branchid': branchId,
      'designerid': designerId,
      'designername': designerName,
      'productid': productId,
      'productname': productName,
      'subproductid': subproductId,
      'subproductname': subproductName,
      'styleid': styleId,
      'stylename': styleName,
      'sizeid': sizeId,
      'sizename': sizeName,
      'purityid': purityId,
      'purityname': purityName,
      'purity': purity,
      'pcs': pcs,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'stone_pcs': stonePcs,
      'stone_weight': stoneWeight,
      'stone_amt': stoneAmt,
      'stone_details': stoneDetails,
      'diamond_pcs': diamondPcs,
      'diamond_weight': diamondWeight,
      'diamond_amt': diamondAmt,
      'diamond_details': diamondDetails,
      'board_rate': boardRate,
      'sales_va_percent': salesVaPercent,
      'sales_wastage': salesWastage,
      'sales_mc_per_gram': salesMcPerGram,
      'sales_m_charge': salesMCharge,
      'sales_total_amt': salesTotalAmt,
      'purchase_touch_pct': purchaseTouchPct,
      'purchase_gold_rate': purchaseGoldRate,
      'purchase_mc': purchaseMc,
      'purchase_stone_cost': purchaseStoneCost,
      'purchase_diamond_cost': purchaseDiamondCost,
      'purchase_total_cost': purchaseTotalCost,
      'huid': huid,
      'status': status,
      'remarks': remarks,
    };
  }
}

/// Dynamic Stone line-item for Stock Tagging & Barcode generation
class TagStoneItem {
  int? productId;
  String? productName;
  int? subProductId;
  String? subProductName;
  String unit; // 'G' (Gram), 'C' (Carat), 'cent'
  int pcs;
  double weight;
  double purRate; // Purchase Rate (Rs/unit)
  double purAmount; // Purchase Amount (Rs)
  double rate; // Sales Rate (Rs/unit)
  double amount; // Sales Amount (Rs)

  TagStoneItem({
    this.productId,
    this.productName,
    this.subProductId,
    this.subProductName,
    this.unit = 'G',
    this.pcs = 0,
    this.weight = 0.0,
    this.purRate = 0.0,
    this.purAmount = 0.0,
    this.rate = 0.0,
    this.amount = 0.0,
  });

  double get weightInGrams {
    final u = unit.toLowerCase();
    if (u == 'c' || u == 'ct') return weight * 0.200;
    if (u == 'cent') return weight * 0.002;
    return weight;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (subProductId != null) 'subproduct_id': subProductId,
      if (subProductName != null) 'subproduct_name': subProductName,
      'unit': unit,
      'pcs': pcs,
      'weight': weight,
      'pur_rate': purRate,
      'pur_amount': purAmount,
      'purrate': purRate,
      'puramt': purAmount,
      'rate': rate,
      'amount': amount,
      'less_weight_grams': weightInGrams,
    };
  }

  factory TagStoneItem.fromJson(Map<String, dynamic> json) {
    final w = double.tryParse(json['weight']?.toString() ?? json['total_stone_weight']?.toString() ?? '0') ?? 0.0;
    final pr = double.tryParse(json['pur_rate']?.toString() ?? json['purrate']?.toString() ?? '0') ?? 0.0;
    final pa = double.tryParse(json['pur_amount']?.toString() ?? json['puramt']?.toString() ?? '0') ?? (w * pr);
    final r = double.tryParse(json['rate']?.toString() ?? json['sales_rate']?.toString() ?? '0') ?? 0.0;
    final a = double.tryParse(json['amount']?.toString() ?? json['stone_amt']?.toString() ?? json['sales_amt']?.toString() ?? '0') ?? (w * r);
    return TagStoneItem(
      productId: json['product_id'] != null
          ? int.tryParse(json['product_id'].toString())
          : (json['stone_productid'] != null ? int.tryParse(json['stone_productid'].toString()) : null),
      productName: json['product_name']?.toString() ?? json['stone_productname']?.toString(),
      subProductId: json['subproduct_id'] != null
          ? int.tryParse(json['subproduct_id'].toString())
          : (json['stone_subproductid'] != null ? int.tryParse(json['stone_subproductid'].toString()) : null),
      subProductName: json['subproduct_name']?.toString() ?? json['stone_subproductname']?.toString(),
      unit: json['unit']?.toString() ?? json['stone_unit']?.toString() ?? 'G',
      pcs: int.tryParse(json['pcs']?.toString() ?? json['total_stone_pcs']?.toString() ?? '0') ?? 0,
      weight: w,
      purRate: pr > 0 ? pr : r,
      purAmount: pa > 0 ? pa : (pr > 0 ? w * pr : a),
      rate: r,
      amount: a,
    );
  }
}

/// Dynamic Diamond line-item for Stock Tagging & Barcode generation
class TagDiamondItem {
  int? productId;
  String? productName;
  int? subProductId;
  String? subProductName;
  String unit; // 'C' (Carat), 'cent', 'G' (Gram)
  int pcs;
  double weight;
  double purRate; // Purchase Rate (Rs/unit)
  double purAmount; // Purchase Amount (Rs)
  double rate; // Sales Rate (Rs/unit)
  double amount; // Sales Amount (Rs)

  TagDiamondItem({
    this.productId,
    this.productName,
    this.subProductId,
    this.subProductName,
    this.unit = 'C',
    this.pcs = 0,
    this.weight = 0.0,
    this.purRate = 0.0,
    this.purAmount = 0.0,
    this.rate = 0.0,
    this.amount = 0.0,
  });

  double get weightInGrams {
    final u = unit.toLowerCase();
    if (u == 'c' || u == 'ct') return weight * 0.200;
    if (u == 'cent') return weight * 0.002;
    return weight;
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (subProductId != null) 'subproduct_id': subProductId,
      if (subProductName != null) 'subproduct_name': subProductName,
      'unit': unit,
      'pcs': pcs,
      'weight': weight,
      'pur_rate': purRate,
      'pur_amount': purAmount,
      'purrate': purRate,
      'puramt': purAmount,
      'rate': rate,
      'amount': amount,
      'less_weight_grams': weightInGrams,
    };
  }

  factory TagDiamondItem.fromJson(Map<String, dynamic> json) {
    final w = double.tryParse(json['weight']?.toString() ?? json['total_diamond_weight']?.toString() ?? '0') ?? 0.0;
    final pr = double.tryParse(json['pur_rate']?.toString() ?? json['purrate']?.toString() ?? '0') ?? 0.0;
    final pa = double.tryParse(json['pur_amount']?.toString() ?? json['puramt']?.toString() ?? '0') ?? (w * pr);
    final r = double.tryParse(json['rate']?.toString() ?? json['sales_rate']?.toString() ?? '0') ?? 0.0;
    final a = double.tryParse(json['amount']?.toString() ?? json['diamond_amt']?.toString() ?? json['sales_amt']?.toString() ?? '0') ?? (w * r);
    return TagDiamondItem(
      productId: json['product_id'] != null
          ? int.tryParse(json['product_id'].toString())
          : (json['diamond_productid'] != null ? int.tryParse(json['diamond_productid'].toString()) : null),
      productName: json['product_name']?.toString() ?? json['diamond_productname']?.toString(),
      subProductId: json['subproduct_id'] != null
          ? int.tryParse(json['subproduct_id'].toString())
          : (json['diamond_subproductid'] != null ? int.tryParse(json['diamond_subproductid'].toString()) : null),
      subProductName: json['subproduct_name']?.toString() ?? json['diamond_subproductname']?.toString(),
      unit: json['unit']?.toString() ?? json['diamond_unit']?.toString() ?? 'C',
      pcs: int.tryParse(json['pcs']?.toString() ?? json['total_diamond_pcs']?.toString() ?? '0') ?? 0,
      weight: w,
      purRate: pr > 0 ? pr : r,
      purAmount: pa > 0 ? pa : (pr > 0 ? w * pr : a),
      rate: r,
      amount: a,
    );
  }
}


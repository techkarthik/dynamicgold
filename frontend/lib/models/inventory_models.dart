class Metal {
  final String metalid;
  final String metalname;
  final String? createdAt;
  final String? updatedAt;

  Metal({
    required this.metalid,
    required this.metalname,
    this.createdAt,
    this.updatedAt,
  });

  factory Metal.fromJson(Map<String, dynamic> json) {
    return Metal(
      metalid: json['metalid']?.toString() ?? '',
      metalname: json['metalname']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'metalid': metalid,
      'metalname': metalname,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

class Purity {
  final int? purityid;
  final String metalid;
  final String purityname;
  final String purityshortname;
  final double purity;
  final String type; // 'ORNAMENT' or 'METAL'
  final String? metalname;
  final String? createdAt;
  final String? updatedAt;

  Purity({
    this.purityid,
    required this.metalid,
    required this.purityname,
    required this.purityshortname,
    required this.purity,
    required this.type,
    this.metalname,
    this.createdAt,
    this.updatedAt,
  });

  factory Purity.fromJson(Map<String, dynamic> json) {
    return Purity(
      purityid: json['purityid'] != null ? int.tryParse(json['purityid'].toString()) : null,
      metalid: json['metalid']?.toString() ?? '',
      purityname: json['purityname']?.toString() ?? '',
      purityshortname: json['purityshortname']?.toString() ?? '',
      purity: json['purity'] != null ? double.tryParse(json['purity'].toString()) ?? 0.0 : 0.0,
      type: json['type']?.toString() ?? 'ORNAMENT',
      metalname: json['metalname']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (purityid != null) 'purityid': purityid,
      'metalid': metalid,
      'purityname': purityname,
      'purityshortname': purityshortname,
      'purity': purity,
      'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }
}

class CategoryRecord {
  final int? id;
  final String metalid;
  final int? purityid;
  final String catcode;
  final String catname;
  final String categorytype; // 'METAL' or 'ORNAMENTS/STONE'
  final double sgstPer;
  final double cgstPer;
  final double igstPer;
  final String salesAccode;
  final String purchaseAccode;
  final String sgstAccode;
  final String cgstAccode;
  final String igstAccode;
  final String salesacname;
  final String purchaseacname;
  final String sgstacname;
  final String cgstacname;
  final String igstacname;
  final String? metalname;
  final String? purityname;
  final String? purityshortname;
  final String? createdAt;
  final String? updatedAt;

  CategoryRecord({
    this.id,
    required this.metalid,
    this.purityid,
    required this.catcode,
    required this.catname,
    required this.categorytype,
    this.sgstPer = 0.0,
    this.cgstPer = 0.0,
    this.igstPer = 0.0,
    this.salesAccode = '',
    this.purchaseAccode = '',
    this.sgstAccode = '',
    this.cgstAccode = '',
    this.igstAccode = '',
    this.salesacname = '',
    this.purchaseacname = '',
    this.sgstacname = '',
    this.cgstacname = '',
    this.igstacname = '',
    this.metalname,
    this.purityname,
    this.purityshortname,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryRecord.fromJson(Map<String, dynamic> json) {
    return CategoryRecord(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      metalid: json['metalid']?.toString() ?? '',
      purityid: json['purityid'] != null ? int.tryParse(json['purityid'].toString()) : null,
      catcode: json['catcode']?.toString() ?? '',
      catname: json['catname']?.toString() ?? '',
      categorytype: json['categorytype']?.toString() ?? 'ORNAMENTS/STONE',
      sgstPer: json['sgst_per'] != null ? double.tryParse(json['sgst_per'].toString()) ?? 0.0 : 0.0,
      cgstPer: json['cgst_per'] != null ? double.tryParse(json['cgst_per'].toString()) ?? 0.0 : 0.0,
      igstPer: json['igst_per'] != null ? double.tryParse(json['igst_per'].toString()) ?? 0.0 : 0.0,
      salesAccode: (json['sales_accode'] ?? json['salesaccode'])?.toString() ?? '',
      purchaseAccode: (json['purchase_accode'] ?? json['purchaseaccode'])?.toString() ?? '',
      sgstAccode: (json['sgst_accode'] ?? json['sgstaccode'])?.toString() ?? '',
      cgstAccode: (json['cgst_accode'] ?? json['cgstaccode'])?.toString() ?? '',
      igstAccode: (json['igst_accode'] ?? json['igstaccode'])?.toString() ?? '',
      salesacname: json['salesacname']?.toString() ?? '',
      purchaseacname: json['purchaseacname']?.toString() ?? '',
      sgstacname: json['sgstacname']?.toString() ?? '',
      cgstacname: json['cgstacname']?.toString() ?? '',
      igstacname: json['igstacname']?.toString() ?? '',
      metalname: json['metalname']?.toString(),
      purityname: json['purityname']?.toString(),
      purityshortname: json['purityshortname']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'metalid': metalid,
      if (purityid != null) 'purityid': purityid,
      'catcode': catcode,
      'catname': catname,
      'categorytype': categorytype,
      'sgst_per': sgstPer,
      'cgst_per': cgstPer,
      'igst_per': igstPer,
      'sales_accode': salesAccode,
      'purchase_accode': purchaseAccode,
      'sgst_accode': sgstAccode,
      'cgst_accode': cgstAccode,
      'igst_accode': igstAccode,
      'salesacname': salesacname,
      'purchaseacname': purchaseacname,
      'sgstacname': sgstacname,
      'cgstacname': cgstacname,
      'igstacname': igstacname,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  CategoryRecord copyWith({
    int? id,
    String? metalid,
    int? purityid,
    String? catcode,
    String? catname,
    String? categorytype,
    double? sgstPer,
    double? cgstPer,
    double? igstPer,
    String? salesAccode,
    String? purchaseAccode,
    String? sgstAccode,
    String? cgstAccode,
    String? igstAccode,
    String? salesacname,
    String? purchaseacname,
    String? sgstacname,
    String? cgstacname,
    String? igstacname,
    String? metalname,
    String? purityname,
    String? purityshortname,
    String? createdAt,
    String? updatedAt,
  }) {
    return CategoryRecord(
      id: id ?? this.id,
      metalid: metalid ?? this.metalid,
      purityid: purityid ?? this.purityid,
      catcode: catcode ?? this.catcode,
      catname: catname ?? this.catname,
      categorytype: categorytype ?? this.categorytype,
      sgstPer: sgstPer ?? this.sgstPer,
      cgstPer: cgstPer ?? this.cgstPer,
      igstPer: igstPer ?? this.igstPer,
      salesAccode: salesAccode ?? this.salesAccode,
      purchaseAccode: purchaseAccode ?? this.purchaseAccode,
      sgstAccode: sgstAccode ?? this.sgstAccode,
      cgstAccode: cgstAccode ?? this.cgstAccode,
      igstAccode: igstAccode ?? this.igstAccode,
      salesacname: salesacname ?? this.salesacname,
      purchaseacname: purchaseacname ?? this.purchaseacname,
      sgstacname: sgstacname ?? this.sgstacname,
      cgstacname: cgstacname ?? this.cgstacname,
      igstacname: igstacname ?? this.igstacname,
      metalname: metalname ?? this.metalname,
      purityname: purityname ?? this.purityname,
      purityshortname: purityshortname ?? this.purityshortname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProductRecord {
  final int? productid;
  final int categoryid;
  final String productname;
  final String calctype; // 'WEIGHT', 'RATE', 'METAL', 'FIXED'
  final String stocktype; // 'SKU', 'OPEN'
  final String havestoneDiamond; // 'YES', 'NO'
  final String havesubproduct; // 'YES', 'NO'
  final String studded; // 'Y' or 'N'
  final String diastone; // 'D' (Diamond), 'S' (Stone), 'P' (Precious), or ''
  final String hsncode; // HSN / SAC Code
  final String stoneunit; // 'CARAT' or 'GRAM' or ''
  final String? catname;
  final String? catcode;
  final String? categorytype;
  final String? metalid;
  final String? metalname;
  final String? createdAt;
  final String? updatedAt;

  ProductRecord({
    this.productid,
    required this.categoryid,
    required this.productname,
    this.calctype = 'WEIGHT',
    this.stocktype = 'SKU',
    this.havestoneDiamond = 'NO',
    this.havesubproduct = 'NO',
    this.studded = 'N',
    this.diastone = '',
    this.hsncode = '',
    this.stoneunit = '',
    this.catname,
    this.catcode,
    this.categorytype,
    this.metalid,
    this.metalname,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductRecord.fromJson(Map<String, dynamic> json) {
    return ProductRecord(
      productid: json['productid'] != null ? int.tryParse(json['productid'].toString()) : null,
      categoryid: int.tryParse(json['categoryid']?.toString() ?? '0') ?? 0,
      productname: json['productname']?.toString() ?? '',
      calctype: json['calctype']?.toString() ?? 'WEIGHT',
      stocktype: json['stocktype']?.toString() ?? 'SKU',
      havestoneDiamond: json['havestone_diamond']?.toString() ?? 'NO',
      havesubproduct: json['havesubproduct']?.toString() ?? 'NO',
      studded: json['studded']?.toString().toUpperCase() == 'Y' ? 'Y' : (json['havestone_diamond']?.toString().toUpperCase() == 'YES' ? 'Y' : 'N'),
      diastone: json['diastone']?.toString().toUpperCase() ?? '',
      hsncode: json['hsncode']?.toString() ?? '',
      stoneunit: json['stoneunit']?.toString().toUpperCase() ?? '',
      catname: json['catname']?.toString(),
      catcode: json['catcode']?.toString(),
      categorytype: json['categorytype']?.toString(),
      metalid: json['metalid']?.toString(),
      metalname: json['metalname']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (productid != null) 'productid': productid,
      'categoryid': categoryid,
      'productname': productname,
      'calctype': calctype,
      'stocktype': stocktype,
      'havestone_diamond': havestoneDiamond,
      'havesubproduct': havesubproduct,
      'studded': studded,
      'diastone': diastone,
      'hsncode': hsncode,
      'stoneunit': stoneunit,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  ProductRecord copyWith({
    int? productid,
    int? categoryid,
    String? productname,
    String? calctype,
    String? stocktype,
    String? havestoneDiamond,
    String? havesubproduct,
    String? studded,
    String? diastone,
    String? hsncode,
    String? stoneunit,
    String? catname,
    String? catcode,
    String? categorytype,
    String? metalid,
    String? metalname,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductRecord(
      productid: productid ?? this.productid,
      categoryid: categoryid ?? this.categoryid,
      productname: productname ?? this.productname,
      calctype: calctype ?? this.calctype,
      stocktype: stocktype ?? this.stocktype,
      havestoneDiamond: havestoneDiamond ?? this.havestoneDiamond,
      havesubproduct: havesubproduct ?? this.havesubproduct,
      studded: studded ?? this.studded,
      diastone: diastone ?? this.diastone,
      hsncode: hsncode ?? this.hsncode,
      stoneunit: stoneunit ?? this.stoneunit,
      catname: catname ?? this.catname,
      catcode: catcode ?? this.catcode,
      categorytype: categorytype ?? this.categorytype,
      metalid: metalid ?? this.metalid,
      metalname: metalname ?? this.metalname,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SubProductRecord {
  final int? subproductid;
  final int productid;
  final String subproductname;
  final String havestoneDiamond; // 'YES', 'NO'
  final String? productname;
  final String? catname;
  final String? catcode;
  final String? metalname;
  final String? metalid;
  final String? createdAt;
  final String? updatedAt;

  SubProductRecord({
    this.subproductid,
    required this.productid,
    required this.subproductname,
    this.havestoneDiamond = 'NO',
    this.productname,
    this.catname,
    this.catcode,
    this.metalname,
    this.metalid,
    this.createdAt,
    this.updatedAt,
  });

  factory SubProductRecord.fromJson(Map<String, dynamic> json) {
    return SubProductRecord(
      subproductid: json['subproductid'] != null ? int.tryParse(json['subproductid'].toString()) : null,
      productid: int.tryParse(json['productid']?.toString() ?? '0') ?? 0,
      subproductname: json['subproductname']?.toString() ?? '',
      havestoneDiamond: json['havestone_diamond']?.toString() ?? 'NO',
      productname: json['productname']?.toString(),
      catname: json['catname']?.toString(),
      catcode: json['catcode']?.toString(),
      metalname: json['metalname']?.toString(),
      metalid: json['metalid']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (subproductid != null) 'subproductid': subproductid,
      'productid': productid,
      'subproductname': subproductname,
      'havestone_diamond': havestoneDiamond,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  SubProductRecord copyWith({
    int? subproductid,
    int? productid,
    String? subproductname,
    String? havestoneDiamond,
    String? productname,
    String? catname,
    String? catcode,
    String? metalname,
    String? metalid,
    String? createdAt,
    String? updatedAt,
  }) {
    return SubProductRecord(
      subproductid: subproductid ?? this.subproductid,
      productid: productid ?? this.productid,
      subproductname: subproductname ?? this.subproductname,
      havestoneDiamond: havestoneDiamond ?? this.havestoneDiamond,
      productname: productname ?? this.productname,
      catname: catname ?? this.catname,
      catcode: catcode ?? this.catcode,
      metalname: metalname ?? this.metalname,
      metalid: metalid ?? this.metalid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StyleRecord {
  final int? styleid;
  final int productid;
  final String stylename;
  final String? productname;
  final String? catname;
  final String? catcode;
  final String? metalname;
  final String? metalid;
  final String? createdAt;
  final String? updatedAt;

  StyleRecord({
    this.styleid,
    required this.productid,
    required this.stylename,
    this.productname,
    this.catname,
    this.catcode,
    this.metalname,
    this.metalid,
    this.createdAt,
    this.updatedAt,
  });

  factory StyleRecord.fromJson(Map<String, dynamic> json) {
    return StyleRecord(
      styleid: json['styleid'] != null ? int.tryParse(json['styleid'].toString()) : null,
      productid: int.tryParse(json['productid']?.toString() ?? '0') ?? 0,
      stylename: json['stylename']?.toString() ?? '',
      productname: json['productname']?.toString(),
      catname: json['catname']?.toString(),
      catcode: json['catcode']?.toString(),
      metalname: json['metalname']?.toString(),
      metalid: json['metalid']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (styleid != null) 'styleid': styleid,
      'productid': productid,
      'stylename': stylename,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  StyleRecord copyWith({
    int? styleid,
    int? productid,
    String? stylename,
    String? productname,
    String? catname,
    String? catcode,
    String? metalname,
    String? metalid,
    String? createdAt,
    String? updatedAt,
  }) {
    return StyleRecord(
      styleid: styleid ?? this.styleid,
      productid: productid ?? this.productid,
      stylename: stylename ?? this.stylename,
      productname: productname ?? this.productname,
      catname: catname ?? this.catname,
      catcode: catcode ?? this.catcode,
      metalname: metalname ?? this.metalname,
      metalid: metalid ?? this.metalid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SizeRecord {
  final int? sizeid;
  final int productid;
  final String sizename;
  final String? productname;
  final String? catname;
  final String? catcode;
  final String? metalname;
  final String? metalid;
  final String? createdAt;
  final String? updatedAt;

  SizeRecord({
    this.sizeid,
    required this.productid,
    required this.sizename,
    this.productname,
    this.catname,
    this.catcode,
    this.metalname,
    this.metalid,
    this.createdAt,
    this.updatedAt,
  });

  factory SizeRecord.fromJson(Map<String, dynamic> json) {
    return SizeRecord(
      sizeid: json['sizeid'] != null ? int.tryParse(json['sizeid'].toString()) : null,
      productid: int.tryParse(json['productid']?.toString() ?? '0') ?? 0,
      sizename: json['sizename']?.toString() ?? '',
      productname: json['productname']?.toString(),
      catname: json['catname']?.toString(),
      catcode: json['catcode']?.toString(),
      metalname: json['metalname']?.toString(),
      metalid: json['metalid']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (sizeid != null) 'sizeid': sizeid,
      'productid': productid,
      'sizename': sizename,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  SizeRecord copyWith({
    int? sizeid,
    int? productid,
    String? sizename,
    String? productname,
    String? catname,
    String? catcode,
    String? metalname,
    String? metalid,
    String? createdAt,
    String? updatedAt,
  }) {
    return SizeRecord(
      sizeid: sizeid ?? this.sizeid,
      productid: productid ?? this.productid,
      sizename: sizename ?? this.sizename,
      productname: productname ?? this.productname,
      catname: catname ?? this.catname,
      catcode: catcode ?? this.catcode,
      metalname: metalname ?? this.metalname,
      metalid: metalid ?? this.metalid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PriceSettingRecord {
  final int? id;
  final String? companyid;
  final String? branchid;
  final String? branchname;
  final int productid;
  final String? productname;
  final int? subproductid;
  final String? subproductname;
  final String accode;
  final String? dealername;
  final String? accounttype;
  final double weightFrom;
  final double weightTo;
  final double vaPercent;
  final double wastage;
  final double mcPerGram;
  final double mCharge;
  final String? createdAt;
  final String? updatedAt;

  PriceSettingRecord({
    this.id,
    this.companyid = '',
    this.branchid = '',
    this.branchname,
    required this.productid,
    this.productname,
    this.subproductid,
    this.subproductname,
    required this.accode,
    this.dealername,
    this.accounttype,
    required this.weightFrom,
    required this.weightTo,
    this.vaPercent = 0.0,
    this.wastage = 0.0,
    this.mcPerGram = 0.0,
    this.mCharge = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  factory PriceSettingRecord.fromJson(Map<String, dynamic> json) {
    return PriceSettingRecord(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      companyid: json['companyid']?.toString() ?? '',
      branchid: json['branchid']?.toString() ?? '',
      branchname: json['branchname']?.toString() ?? '',
      productid: int.tryParse(json['productid']?.toString() ?? '0') ?? 0,
      productname: json['productname']?.toString(),
      subproductid: json['subproductid'] != null && json['subproductid'].toString().isNotEmpty && json['subproductid'].toString() != '0'
          ? int.tryParse(json['subproductid'].toString())
          : null,
      subproductname: json['subproductname']?.toString(),
      accode: json['accode']?.toString() ?? '',
      dealername: json['dealername']?.toString(),
      accounttype: json['accounttype']?.toString(),
      weightFrom: json['weight_from'] != null ? double.tryParse(json['weight_from'].toString()) ?? 0.0 : 0.0,
      weightTo: json['weight_to'] != null ? double.tryParse(json['weight_to'].toString()) ?? 0.0 : 0.0,
      vaPercent: json['va_percent'] != null ? double.tryParse(json['va_percent'].toString()) ?? 0.0 : 0.0,
      wastage: json['wastage'] != null ? double.tryParse(json['wastage'].toString()) ?? 0.0 : 0.0,
      mcPerGram: json['mc_per_gram'] != null ? double.tryParse(json['mc_per_gram'].toString()) ?? 0.0 : 0.0,
      mCharge: json['m_charge'] != null ? double.tryParse(json['m_charge'].toString()) ?? 0.0 : 0.0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'companyid': companyid ?? '',
      'branchid': branchid ?? '',
      'productid': productid,
      'subproductid': subproductid,
      'accode': accode,
      'weight_from': weightFrom,
      'weight_to': weightTo,
      'va_percent': vaPercent,
      'wastage': wastage,
      'mc_per_gram': mcPerGram,
      'm_charge': mCharge,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  PriceSettingRecord copyWith({
    int? id,
    String? companyid,
    String? branchid,
    String? branchname,
    int? productid,
    String? productname,
    int? subproductid,
    String? subproductname,
    String? accode,
    String? dealername,
    String? accounttype,
    double? weightFrom,
    double? weightTo,
    double? vaPercent,
    double? wastage,
    double? mcPerGram,
    double? mCharge,
    String? createdAt,
    String? updatedAt,
  }) {
    return PriceSettingRecord(
      id: id ?? this.id,
      companyid: companyid ?? this.companyid,
      branchid: branchid ?? this.branchid,
      branchname: branchname ?? this.branchname,
      productid: productid ?? this.productid,
      productname: productname ?? this.productname,
      subproductid: subproductid ?? this.subproductid,
      subproductname: subproductname ?? this.subproductname,
      accode: accode ?? this.accode,
      dealername: dealername ?? this.dealername,
      accounttype: accounttype ?? this.accounttype,
      weightFrom: weightFrom ?? this.weightFrom,
      weightTo: weightTo ?? this.weightTo,
      vaPercent: vaPercent ?? this.vaPercent,
      wastage: wastage ?? this.wastage,
      mcPerGram: mcPerGram ?? this.mcPerGram,
      mCharge: mCharge ?? this.mCharge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DiamondPriceSettingRecord {
  final int? id;
  final String? companyid;
  final String? branchid;
  final String? branchname;
  final int productid;
  final String? productname;
  final int? subproductid;
  final String? subproductname;
  final String accode;
  final String? dealername;
  final String? accounttype;
  final double fromCent;
  final double toCent;
  final double centRate;
  final String? createdAt;
  final String? updatedAt;

  DiamondPriceSettingRecord({
    this.id,
    this.companyid = '',
    this.branchid = '',
    this.branchname,
    required this.productid,
    this.productname,
    this.subproductid,
    this.subproductname,
    required this.accode,
    this.dealername,
    this.accounttype,
    required this.fromCent,
    required this.toCent,
    required this.centRate,
    this.createdAt,
    this.updatedAt,
  });

  factory DiamondPriceSettingRecord.fromJson(Map<String, dynamic> json) {
    return DiamondPriceSettingRecord(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      companyid: json['companyid']?.toString() ?? '',
      branchid: json['branchid']?.toString() ?? '',
      branchname: json['branchname']?.toString(),
      productid: int.tryParse(json['productid']?.toString() ?? '0') ?? 0,
      productname: json['productname']?.toString(),
      subproductid: json['subproductid'] != null && json['subproductid'].toString() != '0'
          ? int.tryParse(json['subproductid'].toString())
          : null,
      subproductname: json['subproductname']?.toString(),
      accode: json['accode']?.toString() ?? '',
      dealername: json['dealername']?.toString(),
      accounttype: json['accounttype']?.toString(),
      fromCent: double.tryParse(json['from_cent']?.toString() ?? json['fromcent']?.toString() ?? '0') ?? 0.0,
      toCent: double.tryParse(json['to_cent']?.toString() ?? json['tocent']?.toString() ?? '0') ?? 0.0,
      centRate: double.tryParse(json['cent_rate']?.toString() ?? json['centrate']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'companyid': companyid ?? '',
      'branchid': branchid ?? '',
      'productid': productid,
      'subproductid': subproductid,
      'accode': accode,
      'from_cent': fromCent,
      'to_cent': toCent,
      'cent_rate': centRate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  DiamondPriceSettingRecord copyWith({
    int? id,
    String? companyid,
    String? branchid,
    String? branchname,
    int? productid,
    String? productname,
    int? subproductid,
    String? subproductname,
    String? accode,
    String? dealername,
    String? accounttype,
    double? fromCent,
    double? toCent,
    double? centRate,
    String? createdAt,
    String? updatedAt,
  }) {
    return DiamondPriceSettingRecord(
      id: id ?? this.id,
      companyid: companyid ?? this.companyid,
      branchid: branchid ?? this.branchid,
      branchname: branchname ?? this.branchname,
      productid: productid ?? this.productid,
      productname: productname ?? this.productname,
      subproductid: subproductid ?? this.subproductid,
      subproductname: subproductname ?? this.subproductname,
      accode: accode ?? this.accode,
      dealername: dealername ?? this.dealername,
      accounttype: accounttype ?? this.accounttype,
      fromCent: fromCent ?? this.fromCent,
      toCent: toCent ?? this.toCent,
      centRate: centRate ?? this.centRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DesignerRecord {
  final int? designerid;
  final String accode;
  final String designername;
  final String designershortname;
  final String? accountname;
  final String? accounttype;
  final String? createdAt;
  final String? updatedAt;

  DesignerRecord({
    this.designerid,
    required this.accode,
    required this.designername,
    this.designershortname = '',
    this.accountname,
    this.accounttype,
    this.createdAt,
    this.updatedAt,
  });

  factory DesignerRecord.fromJson(Map<String, dynamic> json) {
    return DesignerRecord(
      designerid: json['designerid'] != null ? int.tryParse(json['designerid'].toString()) : null,
      accode: json['accode']?.toString() ?? '',
      designername: json['designername']?.toString() ?? '',
      designershortname: json['designershortname']?.toString() ?? '',
      accountname: json['accountname']?.toString(),
      accounttype: json['accounttype']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (designerid != null) 'designerid': designerid,
      'accode': accode,
      'designername': designername,
      'designershortname': designershortname,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  DesignerRecord copyWith({
    int? designerid,
    String? accode,
    String? designername,
    String? designershortname,
    String? accountname,
    String? accounttype,
    String? createdAt,
    String? updatedAt,
  }) {
    return DesignerRecord(
      designerid: designerid ?? this.designerid,
      accode: accode ?? this.accode,
      designername: designername ?? this.designername,
      designershortname: designershortname ?? this.designershortname,
      accountname: accountname ?? this.accountname,
      accounttype: accounttype ?? this.accounttype,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SkuLotStoneItem {
  int? stoneProductId;
  String? stoneProductName;
  int? stoneSubProductId;
  String? stoneSubProductName;
  String stoneUnit; // 'G' for Gram, 'C' for Carat
  int pcs;
  double weight;
  double rate; // Per Carat Rate (if 'C') or Per Gram Rate (if 'G')
  double amount; // Total Purchase Amount

  SkuLotStoneItem({
    this.stoneProductId,
    this.stoneProductName,
    this.stoneSubProductId,
    this.stoneSubProductName,
    this.stoneUnit = 'G',
    this.pcs = 0,
    this.weight = 0.0,
    this.rate = 0.0,
    this.amount = 0.0,
  });

  double get weightInGrams {
    if (stoneUnit.toUpperCase() == 'C') {
      return weight * 0.20;
    }
    return weight;
  }

  double get calculatedAmount {
    if (amount > 0) return amount;
    return weight * rate;
  }

  Map<String, dynamic> toJson() {
    return {
      'stone_productid': stoneProductId,
      if (stoneProductName != null) 'stone_productname': stoneProductName,
      if (stoneSubProductId != null) 'stone_subproductid': stoneSubProductId,
      if (stoneSubProductName != null) 'stone_subproductname': stoneSubProductName,
      'stone_unit': stoneUnit,
      'pcs': pcs,
      'weight': weight,
      'rate': rate,
      'amount': amount > 0 ? amount : calculatedAmount,
    };
  }

  factory SkuLotStoneItem.fromJson(Map<String, dynamic> json) {
    final wt = double.tryParse(json['weight']?.toString() ?? json['total_stone_weight']?.toString() ?? '0') ?? 0.0;
    final r = double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0;
    final amt = double.tryParse(json['amount']?.toString() ?? json['total_stone_amount']?.toString() ?? '0') ?? (wt * r);

    return SkuLotStoneItem(
      stoneProductId: json['stone_productid'] != null ? int.tryParse(json['stone_productid'].toString()) : null,
      stoneProductName: json['stone_productname']?.toString(),
      stoneSubProductId: json['stone_subproductid'] != null ? int.tryParse(json['stone_subproductid'].toString()) : null,
      stoneSubProductName: json['stone_subproductname']?.toString(),
      stoneUnit: (json['stone_unit']?.toString().toUpperCase() == 'C') ? 'C' : 'G',
      pcs: int.tryParse(json['pcs']?.toString() ?? json['total_stone_pcs']?.toString() ?? '0') ?? 0,
      weight: wt,
      rate: r,
      amount: amt,
    );
  }
}

class SkuLotDiamondItem {
  int? diamondProductId;
  String? diamondProductName;
  int? diamondSubProductId;
  String? diamondSubProductName;
  String diamondUnit; // 'C' for Carat, 'G' for Gram
  int pcs;
  double weight;
  double rate; // Per Carat Rate
  double amount; // Total Purchase Cost

  SkuLotDiamondItem({
    this.diamondProductId,
    this.diamondProductName,
    this.diamondSubProductId,
    this.diamondSubProductName,
    this.diamondUnit = 'C',
    this.pcs = 0,
    this.weight = 0.0,
    this.rate = 0.0,
    this.amount = 0.0,
  });

  double get weightInGrams {
    if (diamondUnit.toUpperCase() == 'C') {
      return weight * 0.20;
    }
    return weight;
  }

  double get calculatedAmount {
    if (amount > 0) return amount;
    return weight * rate;
  }

  Map<String, dynamic> toJson() {
    return {
      'diamond_productid': diamondProductId,
      if (diamondProductName != null) 'diamond_productname': diamondProductName,
      if (diamondSubProductId != null) 'diamond_subproductid': diamondSubProductId,
      if (diamondSubProductName != null) 'diamond_subproductname': diamondSubProductName,
      'diamond_unit': diamondUnit,
      'pcs': pcs,
      'weight': weight,
      'rate': rate,
      'amount': amount > 0 ? amount : calculatedAmount,
    };
  }

  factory SkuLotDiamondItem.fromJson(Map<String, dynamic> json) {
    final wt = double.tryParse(json['weight']?.toString() ?? json['total_diamond_weight']?.toString() ?? '0') ?? 0.0;
    final r = double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0;
    final amt = double.tryParse(json['amount']?.toString() ?? json['total_diamond_amount']?.toString() ?? '0') ?? (wt * r);

    return SkuLotDiamondItem(
      diamondProductId: json['diamond_productid'] != null ? int.tryParse(json['diamond_productid'].toString()) : null,
      diamondProductName: json['diamond_productname']?.toString(),
      diamondSubProductId: json['diamond_subproductid'] != null ? int.tryParse(json['diamond_subproductid'].toString()) : null,
      diamondSubProductName: json['diamond_subproductname']?.toString(),
      diamondUnit: (json['diamond_unit']?.toString().toUpperCase() == 'G') ? 'G' : 'C',
      pcs: int.tryParse(json['pcs']?.toString() ?? json['total_diamond_pcs']?.toString() ?? '0') ?? 0,
      weight: wt,
      rate: r,
      amount: amt,
    );
  }
}

class PrepareSkuLotRecord {
  final int? lotId;
  final String lotNumber;
  final String companyid;
  final String branchid;
  final int designerid;
  final int productid;
  final int? subproductid;
  final int purityid;
  final double rate;
  final String isAssorted;
  final int totalPcs;
  final double totalGrossWeight;
  final double totalNetWeight;
  final int? stoneProductid;
  final int? stoneSubproductid;
  final String stoneUnit;
  final int totalStonePcs;
  final double totalStoneWeight;
  final double totalStoneAmount;
  final List<SkuLotStoneItem> stoneItems;
  final int? diamondProductid;
  final int? diamondSubproductid;
  final String diamondUnit;
  final int totalDiamondPcs;
  final double totalDiamondWeight;
  final double totalDiamondAmount;
  final List<SkuLotDiamondItem> diamondItems;
  final bool isActive;
  final String status;
  final String remarks;
  final String? createdAt;
  final String? updatedAt;

  // Joined presentation labels
  final String? designername;
  final String? designershortname;
  final String? designerAccode;
  final String? productname;
  final String? calctype;
  final String? stocktype;
  final String? diastone;
  final String? subproductname;
  final String? purityname;
  final String? purityshortname;
  final double? purity;
  final String? purityType;
  final String? branchname;
  final String? companyname;
  final String? stoneProductname;
  final String? stoneSubproductname;
  final String? diamondProductname;
  final String? diamondSubproductname;

  PrepareSkuLotRecord({
    this.lotId,
    this.lotNumber = '',
    required this.companyid,
    required this.branchid,
    required this.designerid,
    required this.productid,
    this.subproductid,
    required this.purityid,
    this.rate = 0.0,
    this.isAssorted = 'NO',
    this.totalPcs = 1,
    this.totalGrossWeight = 0.0,
    this.totalNetWeight = 0.0,
    this.stoneProductid,
    this.stoneSubproductid,
    this.stoneUnit = 'G',
    this.totalStonePcs = 0,
    this.totalStoneWeight = 0.0,
    this.totalStoneAmount = 0.0,
    this.stoneItems = const [],
    this.diamondProductid,
    this.diamondSubproductid,
    this.diamondUnit = 'C',
    this.totalDiamondPcs = 0,
    this.totalDiamondWeight = 0.0,
    this.totalDiamondAmount = 0.0,
    this.diamondItems = const [],
    this.isActive = true,
    this.status = 'PENDING_SKU',
    this.remarks = '',
    this.createdAt,
    this.updatedAt,
    this.designername,
    this.designershortname,
    this.designerAccode,
    this.productname,
    this.calctype,
    this.stocktype,
    this.diastone,
    this.subproductname,
    this.purityname,
    this.purityshortname,
    this.purity,
    this.purityType,
    this.branchname,
    this.companyname,
    this.stoneProductname,
    this.stoneSubproductname,
    this.diamondProductname,
    this.diamondSubproductname,
  });

  factory PrepareSkuLotRecord.fromJson(Map<String, dynamic> json) {
    List<SkuLotStoneItem> parsedStones = [];
    if (json['stone_items'] is List) {
      parsedStones = (json['stone_items'] as List).map((i) => SkuLotStoneItem.fromJson(i)).toList();
    }

    List<SkuLotDiamondItem> parsedDiamonds = [];
    if (json['diamond_items'] is List) {
      parsedDiamonds = (json['diamond_items'] as List).map((i) => SkuLotDiamondItem.fromJson(i)).toList();
    }

    final rawIsActive = json['is_active'];
    final bool isActive = (rawIsActive == null)
        ? (json['status']?.toString().toUpperCase() != 'DISABLED')
        : (rawIsActive == true || rawIsActive == 1 || rawIsActive.toString() == '1' || rawIsActive.toString().toLowerCase() == 'true');

    return PrepareSkuLotRecord(
      lotId: json['lot_id'] != null ? int.tryParse(json['lot_id'].toString()) : null,
      lotNumber: json['lot_number']?.toString() ?? '',
      companyid: json['companyid']?.toString() ?? '',
      branchid: json['branchid']?.toString() ?? '',
      designerid: json['designerid'] != null ? int.tryParse(json['designerid'].toString()) ?? 0 : 0,
      productid: json['productid'] != null ? int.tryParse(json['productid'].toString()) ?? 0 : 0,
      subproductid: json['subproductid'] != null ? int.tryParse(json['subproductid'].toString()) : null,
      purityid: json['purityid'] != null ? int.tryParse(json['purityid'].toString()) ?? 0 : 0,
      rate: json['rate'] != null ? (double.tryParse(json['rate'].toString()) ?? 0.0) : 0.0,
      isAssorted: json['is_assorted']?.toString().toUpperCase() == 'YES' ? 'YES' : 'NO',
      totalPcs: json['total_pcs'] != null ? (int.tryParse(json['total_pcs'].toString()) ?? 1) : 1,
      totalGrossWeight: json['total_gross_weight'] != null ? (double.tryParse(json['total_gross_weight'].toString()) ?? 0.0) : 0.0,
      totalNetWeight: json['total_net_weight'] != null ? (double.tryParse(json['total_net_weight'].toString()) ?? 0.0) : 0.0,
      stoneProductid: json['stone_productid'] != null ? int.tryParse(json['stone_productid'].toString()) : null,
      stoneSubproductid: json['stone_subproductid'] != null ? int.tryParse(json['stone_subproductid'].toString()) : null,
      stoneUnit: (json['stone_unit']?.toString().toUpperCase() == 'C') ? 'C' : 'G',
      totalStonePcs: json['total_stone_pcs'] != null ? (int.tryParse(json['total_stone_pcs'].toString()) ?? 0) : 0,
      totalStoneWeight: json['total_stone_weight'] != null ? (double.tryParse(json['total_stone_weight'].toString()) ?? 0.0) : 0.0,
      totalStoneAmount: json['total_stone_amount'] != null ? (double.tryParse(json['total_stone_amount'].toString()) ?? 0.0) : 0.0,
      stoneItems: parsedStones,
      diamondProductid: json['diamond_productid'] != null ? int.tryParse(json['diamond_productid'].toString()) : null,
      diamondSubproductid: json['diamond_subproductid'] != null ? int.tryParse(json['diamond_subproductid'].toString()) : null,
      diamondUnit: (json['diamond_unit']?.toString().toUpperCase() == 'G') ? 'G' : 'C',
      totalDiamondPcs: json['total_diamond_pcs'] != null ? (int.tryParse(json['total_diamond_pcs'].toString()) ?? 0) : 0,
      totalDiamondWeight: json['total_diamond_weight'] != null ? (double.tryParse(json['total_diamond_weight'].toString()) ?? 0.0) : 0.0,
      totalDiamondAmount: json['total_diamond_amount'] != null ? (double.tryParse(json['total_diamond_amount'].toString()) ?? 0.0) : 0.0,
      diamondItems: parsedDiamonds,
      isActive: isActive,
      status: json['status']?.toString() ?? (isActive ? 'PENDING_SKU' : 'DISABLED'),
      remarks: json['remarks']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      designername: json['designername']?.toString(),
      designershortname: json['designershortname']?.toString(),
      designerAccode: json['designer_accode']?.toString(),
      productname: json['productname']?.toString(),
      calctype: json['calctype']?.toString(),
      stocktype: json['stocktype']?.toString(),
      diastone: json['diastone']?.toString(),
      subproductname: json['subproductname']?.toString(),
      purityname: json['purityname']?.toString(),
      purityshortname: json['purityshortname']?.toString(),
      purity: json['purity'] != null ? double.tryParse(json['purity'].toString()) : null,
      purityType: json['purity_type']?.toString(),
      branchname: json['branchname']?.toString(),
      companyname: json['companyname']?.toString(),
      stoneProductname: json['stone_productname']?.toString(),
      stoneSubproductname: json['stone_subproductname']?.toString(),
      diamondProductname: json['diamond_productname']?.toString(),
      diamondSubproductname: json['diamond_subproductname']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (lotId != null) 'lot_id': lotId,
      if (lotNumber.isNotEmpty) 'lot_number': lotNumber,
      'companyid': companyid,
      'branchid': branchid,
      'designerid': designerid,
      'productid': productid,
      if (subproductid != null) 'subproductid': subproductid,
      'purityid': purityid,
      'rate': rate,
      'is_assorted': isAssorted,
      'total_pcs': totalPcs,
      'total_gross_weight': totalGrossWeight,
      'total_net_weight': totalNetWeight,
      if (stoneProductid != null) 'stone_productid': stoneProductid,
      if (stoneSubproductid != null) 'stone_subproductid': stoneSubproductid,
      'stone_unit': stoneUnit,
      'total_stone_pcs': totalStonePcs,
      'total_stone_weight': totalStoneWeight,
      'total_stone_amount': totalStoneAmount,
      'stone_items': stoneItems.map((s) => s.toJson()).toList(),
      if (diamondProductid != null) 'diamond_productid': diamondProductid,
      if (diamondSubproductid != null) 'diamond_subproductid': diamondSubproductid,
      'diamond_unit': diamondUnit,
      'total_diamond_pcs': totalDiamondPcs,
      'total_diamond_weight': totalDiamondWeight,
      'total_diamond_amount': totalDiamondAmount,
      'diamond_items': diamondItems.map((d) => d.toJson()).toList(),
      'is_active': isActive ? 1 : 0,
      'status': status,
      'remarks': remarks,
    };
  }

  PrepareSkuLotRecord copyWith({
    int? lotId,
    String? lotNumber,
    String? companyid,
    String? branchid,
    int? designerid,
    int? productid,
    int? subproductid,
    int? purityid,
    double? rate,
    String? isAssorted,
    int? totalPcs,
    double? totalGrossWeight,
    double? totalNetWeight,
    int? stoneProductid,
    int? stoneSubproductid,
    String? stoneUnit,
    int? totalStonePcs,
    double? totalStoneWeight,
    double? totalStoneAmount,
    List<SkuLotStoneItem>? stoneItems,
    int? diamondProductid,
    int? diamondSubproductid,
    String? diamondUnit,
    int? totalDiamondPcs,
    double? totalDiamondWeight,
    double? totalDiamondAmount,
    List<SkuLotDiamondItem>? diamondItems,
    bool? isActive,
    String? status,
    String? remarks,
    String? createdAt,
    String? updatedAt,
    String? designername,
    String? designershortname,
    String? designerAccode,
    String? productname,
    String? calctype,
    String? stocktype,
    String? diastone,
    String? subproductname,
    String? purityname,
    String? purityshortname,
    double? purity,
    String? purityType,
    String? branchname,
    String? companyname,
    String? stoneProductname,
    String? stoneSubproductname,
    String? diamondProductname,
    String? diamondSubproductname,
  }) {
    return PrepareSkuLotRecord(
      lotId: lotId ?? this.lotId,
      lotNumber: lotNumber ?? this.lotNumber,
      companyid: companyid ?? this.companyid,
      branchid: branchid ?? this.branchid,
      designerid: designerid ?? this.designerid,
      productid: productid ?? this.productid,
      subproductid: subproductid ?? this.subproductid,
      purityid: purityid ?? this.purityid,
      rate: rate ?? this.rate,
      isAssorted: isAssorted ?? this.isAssorted,
      totalPcs: totalPcs ?? this.totalPcs,
      totalGrossWeight: totalGrossWeight ?? this.totalGrossWeight,
      totalNetWeight: totalNetWeight ?? this.totalNetWeight,
      stoneProductid: stoneProductid ?? this.stoneProductid,
      stoneSubproductid: stoneSubproductid ?? this.stoneSubproductid,
      stoneUnit: stoneUnit ?? this.stoneUnit,
      totalStonePcs: totalStonePcs ?? this.totalStonePcs,
      totalStoneWeight: totalStoneWeight ?? this.totalStoneWeight,
      totalStoneAmount: totalStoneAmount ?? this.totalStoneAmount,
      stoneItems: stoneItems ?? this.stoneItems,
      diamondProductid: diamondProductid ?? this.diamondProductid,
      diamondSubproductid: diamondSubproductid ?? this.diamondSubproductid,
      diamondUnit: diamondUnit ?? this.diamondUnit,
      totalDiamondPcs: totalDiamondPcs ?? this.totalDiamondPcs,
      totalDiamondWeight: totalDiamondWeight ?? this.totalDiamondWeight,
      totalDiamondAmount: totalDiamondAmount ?? this.totalDiamondAmount,
      diamondItems: diamondItems ?? this.diamondItems,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      designername: designername ?? this.designername,
      designershortname: designershortname ?? this.designershortname,
      designerAccode: designerAccode ?? this.designerAccode,
      productname: productname ?? this.productname,
      calctype: calctype ?? this.calctype,
      stocktype: stocktype ?? this.stocktype,
      diastone: diastone ?? this.diastone,
      subproductname: subproductname ?? this.subproductname,
      purityname: purityname ?? this.purityname,
      purityshortname: purityshortname ?? this.purityshortname,
      purity: purity ?? this.purity,
      purityType: purityType ?? this.purityType,
      branchname: branchname ?? this.branchname,
      companyname: companyname ?? this.companyname,
      stoneProductname: stoneProductname ?? this.stoneProductname,
      stoneSubproductname: stoneSubproductname ?? this.stoneSubproductname,
      diamondProductname: diamondProductname ?? this.diamondProductname,
      diamondSubproductname: diamondSubproductname ?? this.diamondSubproductname,
    );
  }
}

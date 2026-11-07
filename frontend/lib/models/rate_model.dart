class PurityRateItem {
  final int purityid;
  final String metalid;
  final String metalname;
  final String purityname;
  final String purityshortname;
  final double purity;
  final String type;
  final int? rateId;
  final int? batchId;
  final String ratedate;
  final double rate;
  final double buyRate;
  final double sellRate;
  final String notes;
  final bool isSavedForDate;
  final String previousRateDate;
  final String? updatedAt;

  PurityRateItem({
    required this.purityid,
    required this.metalid,
    this.metalname = '',
    required this.purityname,
    this.purityshortname = '',
    required this.purity,
    this.type = 'ORNAMENT',
    this.rateId,
    this.batchId,
    this.ratedate = '',
    this.rate = 0.0,
    this.buyRate = 0.0,
    this.sellRate = 0.0,
    this.notes = '',
    this.isSavedForDate = false,
    this.previousRateDate = '',
    this.updatedAt,
  });

  factory PurityRateItem.fromJson(Map<String, dynamic> json) {
    return PurityRateItem(
      purityid: int.tryParse(json['purityid']?.toString() ?? '0') ?? 0,
      metalid: json['metalid']?.toString().toUpperCase() ?? 'G',
      metalname: json['metalname']?.toString() ?? '',
      purityname: json['purityname']?.toString() ?? '',
      purityshortname: json['purityshortname']?.toString() ?? '',
      purity: double.tryParse(json['purity']?.toString() ?? '0') ?? 0.0,
      type: json['type']?.toString() ?? 'ORNAMENT',
      rateId: json['rate_id'] != null ? int.tryParse(json['rate_id'].toString()) : null,
      batchId: json['batch_id'] != null ? int.tryParse(json['batch_id'].toString()) : null,
      ratedate: json['ratedate']?.toString() ?? '',
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      buyRate: double.tryParse(json['buy_rate']?.toString() ?? '0') ?? 0.0,
      sellRate: double.tryParse(json['sell_rate']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      isSavedForDate: json['is_saved_for_date'] == true || json['is_saved_for_date'] == 1 || json['is_saved_for_date'] == 'true',
      previousRateDate: json['previous_rate_date']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? json['last_updated_at']?.toString() ?? json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purityid': purityid,
      'metalid': metalid,
      'purityname': purityname,
      'purity': purity,
      'rate': rate,
      'buy_rate': buyRate,
      'sell_rate': sellRate,
      'notes': notes,
    };
  }

  PurityRateItem copyWith({
    int? purityid,
    String? metalid,
    String? metalname,
    String? purityname,
    String? purityshortname,
    double? purity,
    String? type,
    int? rateId,
    int? batchId,
    String? ratedate,
    double? rate,
    double? buyRate,
    double? sellRate,
    String? notes,
    bool? isSavedForDate,
    String? previousRateDate,
    String? updatedAt,
  }) {
    return PurityRateItem(
      purityid: purityid ?? this.purityid,
      metalid: metalid ?? this.metalid,
      metalname: metalname ?? this.metalname,
      purityname: purityname ?? this.purityname,
      purityshortname: purityshortname ?? this.purityshortname,
      purity: purity ?? this.purity,
      type: type ?? this.type,
      rateId: rateId ?? this.rateId,
      batchId: batchId ?? this.batchId,
      ratedate: ratedate ?? this.ratedate,
      rate: rate ?? this.rate,
      buyRate: buyRate ?? this.buyRate,
      sellRate: sellRate ?? this.sellRate,
      notes: notes ?? this.notes,
      isSavedForDate: isSavedForDate ?? this.isSavedForDate,
      previousRateDate: previousRateDate ?? this.previousRateDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RateHistoryRecord {
  final int id;
  final int batchId;
  final String ratedate;
  final int purityid;
  final String metalid;
  final String metalname;
  final String purityname;
  final String purityshortname;
  final double purity;
  final double rate;
  final double buyRate;
  final double sellRate;
  final String notes;
  final String createdAt;
  final String updatedAt;

  RateHistoryRecord({
    required this.id,
    this.batchId = 1,
    required this.ratedate,
    required this.purityid,
    required this.metalid,
    this.metalname = '',
    required this.purityname,
    this.purityshortname = '',
    required this.purity,
    required this.rate,
    this.buyRate = 0.0,
    this.sellRate = 0.0,
    this.notes = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory RateHistoryRecord.fromJson(Map<String, dynamic> json) {
    return RateHistoryRecord(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      batchId: int.tryParse(json['batch_id']?.toString() ?? '1') ?? 1,
      ratedate: json['ratedate']?.toString() ?? '',
      purityid: int.tryParse(json['purityid']?.toString() ?? '0') ?? 0,
      metalid: json['metalid']?.toString().toUpperCase() ?? 'G',
      metalname: json['metalname']?.toString() ?? '',
      purityname: json['purityname']?.toString() ?? '',
      purityshortname: json['purityshortname']?.toString() ?? '',
      purity: double.tryParse(json['purity']?.toString() ?? '0') ?? 0.0,
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      buyRate: double.tryParse(json['buy_rate']?.toString() ?? '0') ?? 0.0,
      sellRate: double.tryParse(json['sell_rate']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class LatestRatesSummary {
  final double gold24k;
  final double gold22k;
  final double silver;
  final double platinum;
  final String lastUpdatedAt;
  final List<PurityRateItem> purityRates;

  LatestRatesSummary({
    this.gold24k = 7450.0,
    this.gold22k = 6850.0,
    this.silver = 92.50,
    this.platinum = 0.0,
    this.lastUpdatedAt = '',
    this.purityRates = const [],
  });

  factory LatestRatesSummary.fromJson(Map<String, dynamic> json) {
    final ticker = json['ticker'] as Map<String, dynamic>? ?? {};
    final rawPurities = json['purity_rates'] as List? ?? [];

    return LatestRatesSummary(
      gold24k: double.tryParse(ticker['gold_24k']?.toString() ?? '7450') ?? 7450.0,
      gold22k: double.tryParse(ticker['gold_22k']?.toString() ?? '6850') ?? 6850.0,
      silver: double.tryParse(ticker['silver']?.toString() ?? '92.5') ?? 92.5,
      platinum: double.tryParse(ticker['platinum']?.toString() ?? '0') ?? 0.0,
      lastUpdatedAt: ticker['last_updated_at']?.toString() ?? '',
      purityRates: rawPurities.map((i) => PurityRateItem.fromJson(i)).toList(),
    );
  }
}

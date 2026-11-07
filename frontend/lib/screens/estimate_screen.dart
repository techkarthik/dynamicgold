import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/employee_model.dart';
import '../models/estimate_model.dart';
import '../models/rate_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';

class EstimateScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(String targetModule)? onNavigateModule;

  const EstimateScreen({super.key, this.onBack, this.onNavigateModule});

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final DateFormat _dateOnlyFormat = DateFormat('dd-MM-yyyy');

  late TabController _tabController;
  int _selectedTabIndex = 0; // 0 = New Quotation, 1 = Quotation Register

  List<EstimateRecord> _estimates = [];
  List<EstimateRecord> _filteredEstimates = [];
  List<EmployeeRecord> _employees = [];
  EmployeeRecord? _selectedEmployee;
  LatestRatesSummary? _latestRates;

  bool _isLoading = false;
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  int _totalCount = 0;
  int _openCount = 0;
  int _todayCount = 0;
  double _totalValue = 0.0;
  String _nextEstimateNo = 'EST-1001';

  final TextEditingController _searchController = TextEditingController();

  // ================= FORM STATE =================
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _customerMobileCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Item builder inputs
  final _barcodeCtrl = TextEditingController();
  final _productNameCtrl = TextEditingController(text: 'Gold Ornament');
  final _subProductNameCtrl = TextEditingController();
  final _purityNameCtrl = TextEditingController(text: '22K Gold (916)');
  final _grossWeightCtrl = TextEditingController(text: '0.000');
  final _netWeightCtrl = TextEditingController(text: '0.000');
  final _stonePcsCtrl = TextEditingController(text: '0');
  final _stoneWeightCtrl = TextEditingController(text: '0.000');
  final _stonePriceCtrl = TextEditingController(text: '0.00');
  final _diamondPcsCtrl = TextEditingController(text: '0');
  final _diamondWeightCtrl = TextEditingController(text: '0.000');
  final _diamondPriceCtrl = TextEditingController(text: '0.00');
  final _vaPercentCtrl = TextEditingController(text: '8.0');
  final _mcCtrl = TextEditingController(text: '450.00');
  final _boardRateCtrl = TextEditingController(text: '6850.00');
  final _gstRateCtrl = TextEditingController(text: '3.0');

  final List<EstimateItem> _currentItems = [];
  bool _isSaving = false;
  bool _isLookingUpBarcode = false;
  double _calculatedItemTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _selectedTabIndex) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });

    _loadInitialData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilter();
      });
    });

    _netWeightCtrl.addListener(_recalcItemTotal);
    _grossWeightCtrl.addListener(_recalcItemTotal);
    _boardRateCtrl.addListener(_recalcItemTotal);
    _vaPercentCtrl.addListener(_recalcItemTotal);
    _mcCtrl.addListener(_recalcItemTotal);
    _stonePriceCtrl.addListener(_recalcItemTotal);
    _diamondPriceCtrl.addListener(_recalcItemTotal);
    _gstRateCtrl.addListener(_recalcItemTotal);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _customerNameCtrl.dispose();
    _customerMobileCtrl.dispose();
    _customerAddressCtrl.dispose();
    _notesCtrl.dispose();
    _barcodeCtrl.dispose();
    _productNameCtrl.dispose();
    _subProductNameCtrl.dispose();
    _purityNameCtrl.dispose();
    _grossWeightCtrl.dispose();
    _netWeightCtrl.dispose();
    _stonePcsCtrl.dispose();
    _stoneWeightCtrl.dispose();
    _stonePriceCtrl.dispose();
    _diamondPcsCtrl.dispose();
    _diamondWeightCtrl.dispose();
    _diamondPriceCtrl.dispose();
    _vaPercentCtrl.dispose();
    _mcCtrl.dispose();
    _boardRateCtrl.dispose();
    _gstRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getEstimatesData(token),
        _api.getEmployees(token),
        _api.getLatestRates(token),
      ]);

      if (mounted) {
        final estData = results[0] as Map<String, dynamic>;
        final empList = results[1] as List<EmployeeRecord>;
        final rates = results[2] as LatestRatesSummary;

        setState(() {
          _estimates = estData['estimates'] as List<EstimateRecord>? ?? [];
          _totalCount = estData['total_count'] ?? _estimates.length;
          _openCount = estData['open_count'] ?? 0;
          _todayCount = estData['today_count'] ?? 0;
          _totalValue = (estData['total_value'] as num?)?.toDouble() ?? 0.0;
          _nextEstimateNo = estData['next_estimate_no'] ?? 'EST-1001';
          _employees = empList.where((e) => e.active).toList();
          if (_employees.isNotEmpty && _selectedEmployee == null) {
            _selectedEmployee = _employees.first;
          }
          _latestRates = rates;
          if (rates.gold22k > 0) {
            _boardRateCtrl.text = rates.gold22k.toStringAsFixed(2);
          }
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading data: $e', isError: true);
      }
    }
  }

  Future<void> _loadEstimates() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final fromStr = _filterStartDate != null
          ? DateFormat('yyyy-MM-dd').format(_filterStartDate!)
          : null;
      final toStr = _filterEndDate != null
          ? DateFormat('yyyy-MM-dd').format(_filterEndDate!)
          : null;

      final estData = await _api.getEstimatesData(
        token,
        search: _searchQuery,
        status: _statusFilter,
        fromDate: fromStr,
        toDate: toStr,
      );

      if (mounted) {
        setState(() {
          _estimates = estData['estimates'] as List<EstimateRecord>? ?? [];
          _totalCount = estData['total_count'] ?? _estimates.length;
          _openCount = estData['open_count'] ?? 0;
          _todayCount = estData['today_count'] ?? 0;
          _totalValue = (estData['total_value'] as num?)?.toDouble() ?? 0.0;
          _nextEstimateNo = estData['next_estimate_no'] ?? 'EST-1001';
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading estimates: $e', isError: true);
      }
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredEstimates = _estimates.where((est) {
      final matchesStatus =
          _statusFilter == 'ALL' || est.status.toUpperCase() == _statusFilter;
      if (!matchesStatus) return false;

      if (query.isEmpty) return true;
      final estNoMatch = est.estimateNo.toLowerCase().contains(query);
      final custMatch = est.customerName.toLowerCase().contains(query);
      final phoneMatch = est.customerMobile.toLowerCase().contains(query);
      final empMatch =
          (est.employeeName ?? '').toLowerCase().contains(query) ||
          (est.employeeCode ?? '').toLowerCase().contains(query);
      final amtMatch = est.netAmount.toString().contains(query);

      return estNoMatch || custMatch || phoneMatch || empMatch || amtMatch;
    }).toList();
  }

  void _recalcItemTotal() {
    final net = double.tryParse(_netWeightCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_boardRateCtrl.text.trim()) ?? 0.0;
    final vaPct = double.tryParse(_vaPercentCtrl.text.trim()) ?? 0.0;
    final mc = double.tryParse(_mcCtrl.text.trim()) ?? 0.0;
    final stone = double.tryParse(_stonePriceCtrl.text.trim()) ?? 0.0;
    final diamond = double.tryParse(_diamondPriceCtrl.text.trim()) ?? 0.0;
    final gstRate = double.tryParse(_gstRateCtrl.text.trim()) ?? 3.0;

    final metalVal = net * rate;
    final vaVal = metalVal * (vaPct / 100.0);
    final taxable = metalVal + vaVal + mc + stone + diamond;
    final gst = taxable * (gstRate / 100.0);
    final total = taxable + gst;

    if (mounted && (_calculatedItemTotal - total).abs() > 0.001) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _calculatedItemTotal = total;
          });
        }
      });
    }
  }

  double _parseNum(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? fallback;
  }

  int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString().trim()) ?? fallback;
  }

  Future<void> _lookupBarcode([String? explicitSku]) async {
    final barcode = (explicitSku ?? _barcodeCtrl.text).trim();
    if (barcode.isEmpty) {
      _showSnackBar(
        'Please enter or scan a Barcode / SKU number.',
        isError: true,
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLookingUpBarcode = true);

    try {
      final res = await _api.lookupBarcodeForEstimate(token, barcode);
      if (!mounted) return;
      setState(() => _isLookingUpBarcode = false);

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;

        final fetchedSku = data['sku_code']?.toString() ?? barcode;
        final prodName =
            data['productname']?.toString() ??
            data['product_name']?.toString() ??
            'Gold Ornament';
        final subProdName =
            data['subproductname']?.toString() ??
            data['subproduct_name']?.toString() ??
            '';
        final purityName =
            data['purityname']?.toString() ??
            data['purity_name']?.toString() ??
            '22K Gold (916)';

        final gross = _parseNum(data['gross_weight']);
        final net = _parseNum(data['net_weight']);
        final effectiveGross = gross > 0 ? gross : net;
        final effectiveNet = net > 0 ? net : effectiveGross;

        final stPcs = _parseInt(data['stone_pcs']);
        final stWt = _parseNum(data['stone_weight']);
        final stPrice = _parseNum(
          data['stone_selling_price'] ?? data['stone_amt'],
        );
        final diaPcs = _parseInt(data['diamond_pcs']);
        final diaWt = _parseNum(data['diamond_weight']);
        final diaPrice = _parseNum(
          data['diamond_selling_price'] ?? data['diamond_amt'],
        );
        final va = _parseNum(
          data['va_percent'] ?? data['sales_va_percent'],
          8.0,
        );
        final mc = _parseNum(data['mc'] ?? data['sales_m_charge']);
        final bRate = _parseNum(data['board_rate'] ?? data['live_board_rate']);
        final gst = _parseNum(data['gst_rate'], 3.0);

        // Update controllers directly (avoiding reentrant setState crashes)
        _barcodeCtrl.text = fetchedSku;
        _productNameCtrl.text = prodName;
        _subProductNameCtrl.text = subProdName;
        _purityNameCtrl.text = purityName;
        _grossWeightCtrl.text = effectiveGross > 0
            ? effectiveGross.toStringAsFixed(3)
            : '0.000';
        _netWeightCtrl.text = effectiveNet > 0
            ? effectiveNet.toStringAsFixed(3)
            : '0.000';
        _stonePcsCtrl.text = stPcs.toString();
        _stoneWeightCtrl.text = stWt.toStringAsFixed(3);
        _stonePriceCtrl.text = stPrice.toStringAsFixed(2);
        _diamondPcsCtrl.text = diaPcs.toString();
        _diamondWeightCtrl.text = diaWt.toStringAsFixed(3);
        _diamondPriceCtrl.text = diaPrice.toStringAsFixed(2);
        _vaPercentCtrl.text = va.toStringAsFixed(2);
        _mcCtrl.text = mc.toStringAsFixed(2);

        if (bRate > 0) {
          _boardRateCtrl.text = bRate.toStringAsFixed(2);
        } else if (_latestRates != null && _latestRates!.gold22k > 0) {
          _boardRateCtrl.text = _latestRates!.gold22k.toStringAsFixed(2);
        }

        _gstRateCtrl.text = gst.toStringAsFixed(1);

        // Compute direct item total
        final currentNet = effectiveNet;
        final currentRate = double.tryParse(_boardRateCtrl.text.trim()) ?? 0.0;
        final metalVal = currentNet * currentRate;
        final vaVal = metalVal * (va / 100.0);
        final taxable = metalVal + vaVal + mc + stPrice + diaPrice;
        final gstVal = taxable * (gst / 100.0);
        _calculatedItemTotal = taxable + gstVal;

        if (mounted) {
          setState(() {});
        }

        final src = data['source']?.toString();
        final srcTag = src == 'PREPARE_SKU_LOT'
            ? 'Prepare Lot'
            : (src == 'PRODUCT_CATALOG' ? 'Catalog Master' : 'Tagged Stock');
        _showSnackBar(
          '✓ Loaded "$fetchedSku" ($prodName, ${effectiveNet.toStringAsFixed(3)}g) from $srcTag!',
        );
      } else {
        _showSnackBar(
          res['message']?.toString() ?? 'Barcode / SKU not found in database.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLookingUpBarcode = false);
        _showSnackBar('Barcode lookup failed: $e', isError: true);
      }
    }
  }

  Future<void> _showSkuPickerDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    List<Map<String, dynamic>> items = [];
    bool isDialogLoading = true;
    String dialogQuery = '';

    // Pre-fetch initial items BEFORE opening dialog to prevent illegal setState during build
    try {
      items = await _api.searchAvailableSkusForEstimate(token);
    } catch (_) {}
    isDialogLoading = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void loadSkus([String q = '']) async {
              setModalState(() => isDialogLoading = true);
              final list = await _api.searchAvailableSkusForEstimate(
                token,
                query: q,
              );
              if (ctx.mounted) {
                setModalState(() {
                  items = list;
                  isDialogLoading = false;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GlassTheme.primaryNeon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: GlassTheme.primaryNeon,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select SKU / Lot from Database',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Click any inventory item to populate quotation fields',
                          style: TextStyle(
                            fontSize: 11,
                            color: GlassTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh Inventory',
                    onPressed: () => loadSkus(dialogQuery),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText:
                            'Search by SKU code, lot number, or product name...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (val) {
                        dialogQuery = val;
                        loadSkus(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isDialogLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: GlassTheme.primaryNeon,
                              ),
                            )
                          : items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: GlassTheme.textSecondary,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No matching SKUs or lots found in database.',
                                    style: TextStyle(
                                      color: GlassTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Reload All Barcodes'),
                                    onPressed: () => loadSkus(''),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final item = items[idx];
                                final code = item['code']?.toString() ?? '';
                                final lotNo =
                                    item['lot_number']?.toString() ?? '';
                                final pName =
                                    item['product_name']?.toString() ??
                                    'Jewellery';
                                final purity =
                                    item['purity_name']?.toString() ?? '';
                                final netWt =
                                    (item['net_weight'] as num?)?.toDouble() ??
                                    0.0;
                                final status =
                                    item['status']?.toString() ?? 'IN_STOCK';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          code,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$pName ($purity)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Lot: $lotNo • Net Wt: ${netWt.toStringAsFixed(3)}g • Status: $status',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: GlassTheme.textSecondary,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: GlassTheme.textSecondary,
                                  ),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _lookupBarcode(code);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addItemToEstimate() {
    final sku = _barcodeCtrl.text.trim().isEmpty
        ? 'SKU-MANUAL'
        : _barcodeCtrl.text.trim();
    final prod = _productNameCtrl.text.trim().isEmpty
        ? 'Gold Ornament'
        : _productNameCtrl.text.trim();
    final sub = _subProductNameCtrl.text.trim();
    final purity = _purityNameCtrl.text.trim().isEmpty
        ? '22K Gold (916)'
        : _purityNameCtrl.text.trim();

    final gross = double.tryParse(_grossWeightCtrl.text.trim()) ?? 0.0;
    final net = double.tryParse(_netWeightCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_boardRateCtrl.text.trim()) ?? 0.0;
    final va = double.tryParse(_vaPercentCtrl.text.trim()) ?? 0.0;
    final mc = double.tryParse(_mcCtrl.text.trim()) ?? 0.0;
    final stonePcs = int.tryParse(_stonePcsCtrl.text.trim()) ?? 0;
    final stoneWt = double.tryParse(_stoneWeightCtrl.text.trim()) ?? 0.0;
    final stonePrice = double.tryParse(_stonePriceCtrl.text.trim()) ?? 0.0;
    final diaPcs = int.tryParse(_diamondPcsCtrl.text.trim()) ?? 0;
    final diaWt = double.tryParse(_diamondWeightCtrl.text.trim()) ?? 0.0;
    final diaPrice = double.tryParse(_diamondPriceCtrl.text.trim()) ?? 0.0;
    final gstRate = double.tryParse(_gstRateCtrl.text.trim()) ?? 3.0;

    if (net <= 0) {
      _showSnackBar(
        'Please enter a valid Net Weight greater than 0g.',
        isError: true,
      );
      return;
    }
    if (rate <= 0) {
      _showSnackBar('Please enter a valid Board Rate per gram.', isError: true);
      return;
    }

    final metalVal = net * rate;
    final vaVal = metalVal * (va / 100.0);
    final taxable = metalVal + vaVal + mc + stonePrice + diaPrice;
    final gstVal = taxable * (gstRate / 100.0);
    final total = taxable + gstVal;

    final newItem = EstimateItem(
      skuCode: sku,
      productName: prod,
      subProductName: sub,
      purityName: purity,
      grossWeight: gross > 0 ? gross : net,
      netWeight: net,
      stonePcs: stonePcs,
      stoneWeight: stoneWt,
      stoneSellingPrice: stonePrice,
      diamondPcs: diaPcs,
      diamondWeight: diaWt,
      diamondSellingPrice: diaPrice,
      vaPercent: va,
      mc: mc,
      boardRate: rate,
      gstRate: gstRate,
      gstAmount: gstVal,
      totalAmount: total,
    );

    setState(() {
      _currentItems.add(newItem);
      _barcodeCtrl.clear();
      _grossWeightCtrl.text = '0.000';
      _netWeightCtrl.text = '0.000';
      _stonePriceCtrl.text = '0.00';
      _diamondPriceCtrl.text = '0.00';
      _recalcItemTotal();
    });

    _showSnackBar('Item added! Total items: ${_currentItems.length}');
  }

  void _removeItem(int index) {
    setState(() {
      _currentItems.removeAt(index);
    });
  }

  void _clearForm() {
    setState(() {
      _customerNameCtrl.clear();
      _customerMobileCtrl.clear();
      _customerAddressCtrl.clear();
      _notesCtrl.clear();
      _barcodeCtrl.clear();
      _currentItems.clear();
      _grossWeightCtrl.text = '0.000';
      _netWeightCtrl.text = '0.000';
      _stonePriceCtrl.text = '0.00';
      _diamondPriceCtrl.text = '0.00';
      _recalcItemTotal();
    });
  }

  Future<void> _saveEstimate({bool printAfterSave = false}) async {
    if (_customerNameCtrl.text.trim().isEmpty) {
      _showSnackBar('Customer Name is required.', isError: true);
      return;
    }

    if (_currentItems.isEmpty) {
      _showSnackBar(
        'Please add at least one line item to the quotation.',
        isError: true,
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    double totalGross = 0.0;
    double totalNet = 0.0;
    double totalMetal = 0.0;
    double totalVa = 0.0;
    double totalMc = 0.0;
    double totalStone = 0.0;
    double totalDia = 0.0;
    double totalTaxable = 0.0;
    double totalGst = 0.0;
    double grandTotal = 0.0;

    for (final itm in _currentItems) {
      totalGross += itm.grossWeight;
      totalNet += itm.netWeight;
      totalMetal += itm.metalValue;
      totalVa += itm.vaCharges;
      totalMc += itm.mc;
      totalStone += itm.stoneSellingPrice;
      totalDia += itm.diamondSellingPrice;
      totalTaxable += itm.taxableSubtotal;
      totalGst += itm.gstAmount;
      grandTotal += itm.totalAmount;
    }

    final newRecord = EstimateRecord(
      estimateNo: _nextEstimateNo,
      customerName: _customerNameCtrl.text.trim(),
      customerMobile: _customerMobileCtrl.text.trim(),
      customerAddress: _customerAddressCtrl.text.trim(),
      employeeId: _selectedEmployee?.empid,
      employeeCode: _selectedEmployee != null
          ? 'EMP${_selectedEmployee!.empid}'
          : null,
      employeeName: _selectedEmployee?.empname,
      grossWeight: totalGross,
      netWeight: totalNet,
      totalMetalValue: totalMetal,
      totalMakingCharges: totalMc,
      totalStoneCharges: totalStone,
      totalDiamondCharges: totalDia,
      totalVaCharges: totalVa,
      taxableAmount: totalTaxable,
      gstRate: 3.0,
      taxAmount: totalGst,
      netAmount: grandTotal,
      status: 'OPEN',
      items: _currentItems,
      notes: _notesCtrl.text.trim(),
    );

    try {
      final res = await _api.createEstimate(token, newRecord);
      setState(() => _isSaving = false);

      if (res['success'] == true) {
        _showSnackBar('Estimate ${newRecord.estimateNo} created successfully!');
        final savedRecord = res['estimate'] != null
            ? EstimateRecord.fromJson(res['estimate'])
            : newRecord;

        _clearForm();
        await _loadEstimates();

        if (printAfterSave) {
          _showPrintSlipDialog(savedRecord);
        } else {
          // Switch to register tab
          setState(() {
            _tabController.animateTo(1);
          });
        }
      } else {
        _showSnackBar(
          res['message']?.toString() ?? 'Failed to save estimate.',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Error saving estimate: $e', isError: true);
    }
  }

  // ================= DATE-WISE DELETION MODAL =================
  void _showPurgeDialog() {
    String deleteMode = 'RANGE';
    DateTime selectedFromDate = DateTime.now().subtract(
      const Duration(days: 30),
    );
    DateTime selectedToDate = DateTime.now();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final fromStr = DateFormat('dd-MM-yyyy').format(selectedFromDate);
            final toStr = DateFormat('dd-MM-yyyy').format(selectedToDate);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_sweep_rounded,
                      color: GlassTheme.accentRose,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Purge Old Estimations',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clean up and permanently delete historical quotations by date range or cutoff date.',
                      style: TextStyle(
                        color: GlassTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'RANGE',
                          label: Text(
                            'Date Range',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        ButtonSegment(
                          value: 'BEFORE',
                          label: Text(
                            'Before Date',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        ButtonSegment(
                          value: 'SINGLE',
                          label: Text(
                            'Single Date',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                      selected: {deleteMode},
                      onSelectionChanged: (val) =>
                          setDialogState(() => deleteMode = val.first),
                    ),
                    const SizedBox(height: 16),

                    if (deleteMode == 'RANGE') ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePickerTile(
                              label: 'Start Date (From)',
                              valueStr: fromStr,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedFromDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => selectedFromDate = picked,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDatePickerTile(
                              label: 'End Date (To)',
                              valueStr: toStr,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedToDate,
                                  firstDate: selectedFromDate,
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedToDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else if (deleteMode == 'BEFORE') ...[
                      _buildDatePickerTile(
                        label: 'Delete all estimates created BEFORE',
                        valueStr: fromStr,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedFromDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedFromDate = picked);
                          }
                        },
                      ),
                    ] else ...[
                      _buildDatePickerTile(
                        label: 'Delete all estimates on date',
                        valueStr: fromStr,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedFromDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedFromDate = picked);
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: Deleted estimates cannot be recovered.',
                              style: TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: GlassTheme.textSecondary),
                  ),
                ),
                ElevatedButton.icon(
                  icon: isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Purge Estimates'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.accentRose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final token = auth.authToken;
                          if (token == null) return;

                          setDialogState(() => isProcessing = true);

                          try {
                            String? fromParam;
                            String? toParam;
                            String? beforeParam;
                            String? singleParam;

                            if (deleteMode == 'RANGE') {
                              fromParam = DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedFromDate);
                              toParam = DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedToDate);
                            } else if (deleteMode == 'BEFORE') {
                              beforeParam = DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedFromDate);
                            } else {
                              singleParam = DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedFromDate);
                            }

                            final res = await _api.deleteEstimatesByDate(
                              token,
                              fromDate: fromParam,
                              toDate: toParam,
                              beforeDate: beforeParam,
                              date: singleParam,
                            );

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }

                            if (res['success'] == true) {
                              _showSnackBar(
                                res['message']?.toString() ??
                                    'Old estimates purged successfully.',
                              );
                              await _loadEstimates();
                            } else {
                              _showSnackBar(
                                res['message']?.toString() ?? 'Purge failed.',
                                isError: true,
                              );
                            }
                          } catch (e) {
                            _showSnackBar('Purge failed: $e', isError: true);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    required String valueStr,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: GlassTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  valueStr,
                  style: const TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: GlassTheme.accentAmber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? GlassTheme.accentRose
            : const Color(0xFF059669),
      ),
    );
  }

  // ================= VIEW / PRINT QUOTATION SLIP DIALOG =================
  void _showPrintSlipDialog(EstimateRecord est) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 650,
            constraints: const BoxConstraints(maxHeight: 720),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GlassTheme.accentAmber.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: GlassTheme.accentAmber,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ESTIMATE / QUOTATION',
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              est.estimateNo,
                              style: const TextStyle(
                                color: GlassTheme.accentAmber,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CUSTOMER DETAILS',
                                      style: TextStyle(
                                        color: GlassTheme.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      est.customerName,
                                      style: const TextStyle(
                                        color: GlassTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (est.customerMobile.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Mob: ${est.customerMobile}',
                                        style: const TextStyle(
                                          color: GlassTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    if (est.customerAddress.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        est.customerAddress,
                                        style: const TextStyle(
                                          color: GlassTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SALES STAFF & META',
                                      style: TextStyle(
                                        color: GlassTheme.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      est.employeeName != null &&
                                              est.employeeName!.isNotEmpty
                                          ? '${est.employeeName} (${est.employeeCode ?? "STAFF"})'
                                          : 'Store Executive',
                                      style: const TextStyle(
                                        color: GlassTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Date: ${est.createdAt != null ? _dateFormat.format(DateTime.tryParse(est.createdAt!) ?? DateTime.now()) : _dateOnlyFormat.format(DateTime.now())}',
                                      style: const TextStyle(
                                        color: GlassTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Status: ${est.status}',
                                      style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'QUOTATION ITEMS',
                          style: TextStyle(
                            color: GlassTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                color: const Color(0xFFF1F5F9),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'SKU / Product',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Net Wt',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Rate',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'VA+MC',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Stones',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'GST',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Amount (₹)',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...est.items.map((itm) {
                                final vaMc = itm.vaCharges + itm.mc;
                                final stDia =
                                    itm.stoneSellingPrice +
                                    itm.diamondSellingPrice;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFF1F5F9),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itm.skuCode,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              itm.productName,
                                              style: const TextStyle(
                                                color: GlassTheme.textSecondary,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '${itm.netWeight.toStringAsFixed(3)}g',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '₹${itm.boardRate.toStringAsFixed(0)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '₹${vaMc.toStringAsFixed(0)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '₹${stDia.toStringAsFixed(0)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '₹${itm.gstAmount.toStringAsFixed(0)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _currencyFormat.format(
                                            itm.totalAmount,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Totals Summary Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            children: [
                              _buildSlipSummaryRow(
                                'Total Gross Weight',
                                '${est.grossWeight.toStringAsFixed(3)} g',
                              ),
                              _buildSlipSummaryRow(
                                'Total Net Weight',
                                '${est.netWeight.toStringAsFixed(3)} g',
                              ),
                              _buildSlipSummaryRow(
                                'Total Metal Value',
                                _currencyFormat.format(est.totalMetalValue),
                              ),
                              _buildSlipSummaryRow(
                                'Total VA & Making Charges',
                                _currencyFormat.format(
                                  est.totalVaCharges + est.totalMakingCharges,
                                ),
                              ),
                              _buildSlipSummaryRow(
                                'Total Stone & Diamond Charges',
                                _currencyFormat.format(
                                  est.totalStoneCharges +
                                      est.totalDiamondCharges,
                                ),
                              ),
                              _buildSlipSummaryRow(
                                'GST (Tax Amount)',
                                _currencyFormat.format(est.taxAmount),
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ESTIMATE NET AMOUNT',
                                    style: TextStyle(
                                      color: GlassTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(est.netAmount),
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (est.notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Notes: ${est.notes}',
                            style: const TextStyle(
                              color: GlassTheme.textSecondary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Voucher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassTheme.accentAmber,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showSnackBar(
                          'Printing quotation slip for ${est.estimateNo}...',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlipSummaryRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: GlassTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            val,
            style: const TextStyle(
              color: GlassTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ================= MAIN BUILD METHOD =================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet =
            constraints.maxWidth >= 768 && constraints.maxWidth < 1150;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // Top Responsive Header Bar
              _buildTopBar(isMobile),

              // Main Content Area
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: GlassTheme.primaryNeon,
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Tab 1: New Quotation Generator
                          _buildGeneratorTabView(isMobile, isTablet),

                          // Tab 2: Quotation Register
                          _buildRegisterTabView(isMobile, isTablet),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= TOP BAR =================
  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: GlassTheme.textPrimary,
                  ),
                  onPressed: widget.onBack,
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
              ],

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.request_quote_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ESTIMATE & QUOTATION',
                      style: TextStyle(
                        color: GlassTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Live 22K: ₹${_latestRates != null ? _latestRates!.gold22k.toStringAsFixed(2) : "6850.00"}/g • Next: $_nextEstimateNo',
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              if (!isMobile) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text(
                    'Purge by Date',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    foregroundColor: GlassTheme.accentRose,
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _showPurgeDialog,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: GlassTheme.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Refresh',
                  onPressed: _loadInitialData,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Tab Selector Bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              labelColor: GlassTheme.primaryNeon,
              unselectedLabelColor: GlassTheme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Create Quotation'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('Quotation Register ($_totalCount)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 1: NEW QUOTATION GENERATOR =================
  Widget _buildGeneratorTabView(bool isMobile, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Customer & Sales Staff Card
            _buildSectionCard(
              title: '1. CUSTOMER & SALES EXECUTIVE DETAILS',
              icon: Icons.person_pin_rounded,
              child: isMobile
                  ? Column(
                      children: [
                        _buildUniformTextField(
                          _customerNameCtrl,
                          'Customer Name *',
                          Icons.person_outline_rounded,
                          isRequired: true,
                        ),
                        const SizedBox(height: 10),
                        _buildUniformTextField(
                          _customerMobileCtrl,
                          'Customer Mobile',
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),
                        _buildEmployeeDropdown(),
                        const SizedBox(height: 10),
                        _buildUniformTextField(
                          _customerAddressCtrl,
                          'Customer Address / City',
                          Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 10),
                        _buildUniformTextField(
                          _notesCtrl,
                          'Quotation Remarks',
                          Icons.note_alt_outlined,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildUniformTextField(
                                _customerNameCtrl,
                                'Customer Name *',
                                Icons.person_outline_rounded,
                                isRequired: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildUniformTextField(
                                _customerMobileCtrl,
                                'Customer Mobile',
                                Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: _buildEmployeeDropdown()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildUniformTextField(
                                _customerAddressCtrl,
                                'Customer Address / City',
                                Icons.location_on_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildUniformTextField(
                                _notesCtrl,
                                'Quotation Remarks',
                                Icons.note_alt_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // 2. Barcode (SKU) Item Builder Card
            _buildSectionCard(
              title: '2. SCAN / ENTER BARCODE (SKU)',
              icon: Icons.qr_code_scanner_rounded,
              headerTrailing: Text(
                'Live 22K: ₹${_latestRates != null ? _latestRates!.gold22k.toStringAsFixed(2) : "6850.00"}/g',
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barcode Lookup Bar
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: TextField(
                            controller: _barcodeCtrl,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              labelText: 'SKU / Barcode Number',
                              hintText:
                                  'Enter SKU (e.g. 27A001), Lot (e.g. 2627-1), or Item # (e.g. 45)',
                              prefixIcon: const Icon(
                                Icons.barcode_reader,
                                size: 18,
                              ),
                              suffixIcon: _barcodeCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        _barcodeCtrl.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onEditingComplete: () => _lookupBarcode(),
                            onSubmitted: (_) => _lookupBarcode(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          icon: _isLookingUpBarcode
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search_rounded, size: 18),
                          label: const Text(
                            'Fetch Barcode',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: _isLookingUpBarcode
                              ? null
                              : _lookupBarcode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.list_alt_rounded, size: 18),
                          label: const Text(
                            'Browse SKUs',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _showSkuPickerDialog,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Uniform Grid of Auto-Populated Attributes
                  if (isMobile) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _productNameCtrl,
                            'Product Name',
                            Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _subProductNameCtrl,
                            'Design / Style',
                            Icons.style_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _purityNameCtrl,
                            'Purity',
                            Icons.verified_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _grossWeightCtrl,
                            'Gross Wt (g)',
                            Icons.scale_outlined,
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _netWeightCtrl,
                            'Net Wt (g) *',
                            Icons.balance_outlined,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _boardRateCtrl,
                            'Board Rate (₹/g)',
                            Icons.currency_rupee_rounded,
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _vaPercentCtrl,
                            'VA %',
                            Icons.percent_rounded,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _mcCtrl,
                            'MC (₹)',
                            Icons.handyman_outlined,
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _stonePriceCtrl,
                            'Stone Price (₹)',
                            Icons.diamond_outlined,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _diamondPriceCtrl,
                            'Diamond Price (₹)',
                            Icons.auto_awesome_rounded,
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _gstRateCtrl,
                            'GST %',
                            Icons.receipt_outlined,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Container()),
                      ],
                    ),
                  ] else ...[
                    // Desktop / Tablet 4-column equal grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _productNameCtrl,
                            'Product Name',
                            Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _subProductNameCtrl,
                            'Design / Style',
                            Icons.style_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _purityNameCtrl,
                            'Purity',
                            Icons.verified_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _grossWeightCtrl,
                            'Gross Wt (g)',
                            Icons.scale_outlined,
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _netWeightCtrl,
                            'Net Wt (g) *',
                            Icons.balance_outlined,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _boardRateCtrl,
                            'Board Rate (₹/g)',
                            Icons.currency_rupee_rounded,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _vaPercentCtrl,
                            'VA % (Wastage)',
                            Icons.percent_rounded,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _mcCtrl,
                            'Making Charges (₹)',
                            Icons.handyman_outlined,
                            isNumeric: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUniformTextField(
                            _stonePriceCtrl,
                            'Stone Price (₹)',
                            Icons.diamond_outlined,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _diamondPriceCtrl,
                            'Diamond Price (₹)',
                            Icons.auto_awesome_rounded,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildUniformTextField(
                            _gstRateCtrl,
                            'GST %',
                            Icons.receipt_outlined,
                            isNumeric: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Container()), // spacing filler
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Item Total & Add Item Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: isMobile
                        ? Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Item Total (Incl. GST):',
                                    style: TextStyle(
                                      color: Color(0xFF065F46),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(
                                      _calculatedItemTotal,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Add Item to Quotation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _addItemToEstimate,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calculate_rounded,
                                    color: Color(0xFF059669),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Item Total (Incl. GST):',
                                    style: TextStyle(
                                      color: Color(0xFF065F46),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currencyFormat.format(
                                      _calculatedItemTotal,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Add Item to Quotation',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _addItemToEstimate,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Line Items Table / Cards
            _buildSectionCard(
              title: '3. QUOTATION LINE ITEMS (${_currentItems.length})',
              icon: Icons.list_alt_rounded,
              child: _currentItems.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: Color(0xFFCBD5E1),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No items added yet. Scan a barcode above or fill details and click Add Item.',
                            style: TextStyle(
                              color: GlassTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        ..._currentItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final stDia =
                              item.stoneSellingPrice + item.diamondSellingPrice;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.skuCode,
                                              style: const TextStyle(
                                                color: Color(0xFF1D4977),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${item.productName} (${item.purityName})',
                                              style: const TextStyle(
                                                color: GlassTheme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        children: [
                                          Text(
                                            'Net: ${item.netWeight.toStringAsFixed(3)}g',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: GlassTheme.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            'Rate: ₹${item.boardRate.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: GlassTheme.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            'VA: ${item.vaPercent}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: GlassTheme.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            'MC: ₹${item.mc.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: GlassTheme.textSecondary,
                                            ),
                                          ),
                                          if (stDia > 0)
                                            Text(
                                              'Stones: ₹${stDia.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: GlassTheme.textSecondary,
                                              ),
                                            ),
                                          Text(
                                            'GST: ₹${item.gstAmount.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: GlassTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currencyFormat.format(item.totalAmount),
                                      style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: GlassTheme.accentRose,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeItem(idx),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // 4. Summary & Save Action Card
            _buildQuotationSummaryCard(isMobile),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ================= QUOTATION SUMMARY CARD =================
  Widget _buildQuotationSummaryCard(bool isMobile) {
    double totalGross = 0.0;
    double totalNet = 0.0;
    double totalMetal = 0.0;
    double totalVa = 0.0;
    double totalMc = 0.0;
    double totalStone = 0.0;
    double totalDia = 0.0;
    double totalGst = 0.0;
    double grandTotal = 0.0;

    for (final itm in _currentItems) {
      totalGross += itm.grossWeight;
      totalNet += itm.netWeight;
      totalMetal += itm.metalValue;
      totalVa += itm.vaCharges;
      totalMc += itm.mc;
      totalStone += itm.stoneSellingPrice;
      totalDia += itm.diamondSellingPrice;
      totalGst += itm.gstAmount;
      grandTotal += itm.totalAmount;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '4. ESTIMATE TOTAL SUMMARY',
            style: TextStyle(
              color: GlassTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 20),

          Wrap(
            spacing: 20,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildMetricPill(
                'Total Net Wt',
                '${totalNet.toStringAsFixed(3)} g',
              ),
              _buildMetricPill(
                'Metal Value',
                _currencyFormat.format(totalMetal),
              ),
              _buildMetricPill('VA Charges', _currencyFormat.format(totalVa)),
              _buildMetricPill(
                'Making Charges',
                _currencyFormat.format(totalMc),
              ),
              _buildMetricPill(
                'Stones & Dia',
                _currencyFormat.format(totalStone + totalDia),
              ),
              _buildMetricPill('GST (3%)', _currencyFormat.format(totalGst)),
            ],
          ),
          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NET PAYABLE ESTIMATE:',
                style: TextStyle(
                  color: GlassTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currencyFormat.format(grandTotal),
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Primary Actions
          isMobile
              ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 20),
                        label: const Text(
                          'Save Quotation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlassTheme.primaryNeon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => _saveEstimate(printAfterSave: false),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 20),
                        label: const Text(
                          'Save & Print Slip',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => _saveEstimate(printAfterSave: true),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _clearForm,
                      child: const Text('Clear Form'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: const Text(
                        'Save Quotation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassTheme.primaryNeon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () => _saveEstimate(printAfterSave: false),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: const Text(
                        'Save & Print Slip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () => _saveEstimate(printAfterSave: true),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            color: GlassTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ================= TAB 2: QUOTATION REGISTER VIEW =================
  Widget _buildRegisterTabView(bool isMobile, bool isTablet) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText:
                                'Search by Estimate No, Customer Name, Mobile, Staff...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (isMobile) ...[
                      IconButton(
                        icon: const Icon(
                          Icons.delete_sweep_rounded,
                          color: GlassTheme.accentRose,
                        ),
                        tooltip: 'Purge Old Estimates',
                        onPressed: _showPurgeDialog,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Filter chips & status dropdown
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(
                        color: GlassTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _statusFilter,
                          style: const TextStyle(
                            color: GlassTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Text('All Estimates'),
                            ),
                            DropdownMenuItem(
                              value: 'OPEN',
                              child: Text('Open Quotes'),
                            ),
                            DropdownMenuItem(
                              value: 'CONVERTED',
                              child: Text('Converted to Sales'),
                            ),
                            DropdownMenuItem(
                              value: 'CANCELLED',
                              child: Text('Cancelled'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _statusFilter = val;
                                _applyFilter();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text(
                        _filterStartDate == null
                            ? 'Filter Date'
                            : '${_dateOnlyFormat.format(_filterStartDate!)} - ${_filterEndDate != null ? _dateOnlyFormat.format(_filterEndDate!) : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange:
                              _filterStartDate != null && _filterEndDate != null
                              ? DateTimeRange(
                                  start: _filterStartDate!,
                                  end: _filterEndDate!,
                                )
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            _filterStartDate = picked.start;
                            _filterEndDate = picked.end;
                          });
                          _loadEstimates();
                        }
                      },
                    ),
                    if (_filterStartDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          setState(() {
                            _filterStartDate = null;
                            _filterEndDate = null;
                          });
                          _loadEstimates();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPI Metric Tiles
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Total Quotes',
                  '$_totalCount',
                  Icons.receipt_long_rounded,
                  const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Open Quotes',
                  '$_openCount',
                  Icons.pending_actions_rounded,
                  const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Today Quotes',
                  '$_todayCount',
                  Icons.today_rounded,
                  const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Estimates Register List / Cards
          if (_filteredEstimates.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: Color(0xFFCBD5E1),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No quotation records found.',
                    style: TextStyle(color: GlassTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._filteredEstimates.map((est) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                est.estimateNo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: GlassTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: est.status == 'OPEN'
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  est.status,
                                  style: TextStyle(
                                    color: est.status == 'OPEN'
                                        ? const Color(0xFF059669)
                                        : GlassTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${est.customerName} ${est.customerMobile.isNotEmpty ? "• ${est.customerMobile}" : ""}',
                            style: const TextStyle(
                              color: GlassTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Staff: ${est.employeeName ?? "N/A"} • Items: ${est.items.length} • Net Wt: ${est.netWeight.toStringAsFixed(3)}g',
                            style: const TextStyle(
                              color: GlassTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(est.netAmount),
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 20,
                                color: Color(0xFF2563EB),
                              ),
                              tooltip: 'View / Print Slip',
                              onPressed: () => _showPrintSlipDialog(est),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: GlassTheme.accentRose,
                              ),
                              tooltip: 'Delete Quotation',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Delete Estimate?'),
                                    content: Text(
                                      'Are you sure you want to delete ${est.estimateNo}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              GlassTheme.accentRose,
                                        ),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && est.estimateId != null) {
                                  final auth = Provider.of<AuthProvider>(
                                    context,
                                    listen: false,
                                  );
                                  if (auth.authToken != null) {
                                    final res = await _api.deleteEstimate(
                                      auth.authToken!,
                                      est.estimateId!,
                                    );
                                    if (res['success'] == true) {
                                      _showSnackBar(
                                        'Estimate ${est.estimateNo} deleted.',
                                      );
                                      _loadEstimates();
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ================= REUSABLE UI BUILDERS =================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? headerTrailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF475569)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ?headerTrailing,
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildUniformTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumeric = false,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : (keyboardType ?? TextInputType.text),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 12,
            color: GlassTheme.textSecondary,
          ),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: GlassTheme.primaryNeon,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        validator: isRequired
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<EmployeeRecord>(
        initialValue: _selectedEmployee,
        style: const TextStyle(
          fontSize: 13,
          color: GlassTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: 'Sales Staff (Employee Code) *',
          labelStyle: const TextStyle(
            fontSize: 12,
            color: GlassTheme.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.badge_outlined,
            size: 18,
            color: Color(0xFF64748B),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: GlassTheme.primaryNeon,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        items: _employees.map((emp) {
          return DropdownMenuItem<EmployeeRecord>(
            value: emp,
            child: Text(
              '[EMP${emp.empid}] ${emp.empname}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (val) {
          setState(() {
            _selectedEmployee = val;
          });
        },
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String val,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: GlassTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  val,
                  style: const TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

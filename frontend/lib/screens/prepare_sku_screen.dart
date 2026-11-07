import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/branch_model.dart';
import '../models/inventory_models.dart';
import '../models/rate_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';

class PrepareSkuScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PrepareSkuScreen({super.key, this.onBack});

  @override
  State<PrepareSkuScreen> createState() => _PrepareSkuScreenState();
}

class _PrepareSkuScreenState extends State<PrepareSkuScreen> {
  final ApiService _api = ApiService();

  // Data collections
  List<PrepareSkuLotRecord> _lots = [];
  List<PrepareSkuLotRecord> _filteredLots = [];
  List<DesignerRecord> _allDesigners = [];
  List<ProductRecord> _allProducts = [];
  List<SubProductRecord> _allSubProducts = [];
  List<Purity> _allOrnamentPurities = [];
  List<Branch> _allBranches = [];
  LatestRatesSummary _latestRates = LatestRatesSummary();

  // Screen UI State
  bool _isLoading = false;
  bool _isSaving = false;
  bool _showForm = false;
  bool _isTableView = true;

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterBranchId = 'ALL';
  int? _filterDesignerId;
  int? _filterProductId;
  String _filterIsAssorted = 'ALL';
  String _filterStatus = 'ALL'; // 'ALL', 'ACTIVE', 'DISABLED'

  // Date Filtering (Default: TODAY)
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _datePreset =
      'TODAY'; // 'TODAY', 'YESTERDAY', 'WEEK', 'MONTH', 'ALL', 'CUSTOM'

  // Form State
  final _formKey = GlobalKey<FormState>();
  PrepareSkuLotRecord? _editingRecord;

  String? _selectedBranchId;
  int? _selectedDesignerId;
  int? _selectedProductId;
  int? _selectedSubProductId;
  int? _selectedPurityId;
  String _isAssorted = 'NO';

  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _totalPcsController = TextEditingController(
    text: '1',
  );
  final TextEditingController _totalGrossWtController = TextEditingController(
    text: '0.000',
  );
  final TextEditingController _totalNetWtController = TextEditingController(
    text: '0.000',
  );
  final TextEditingController _remarksController = TextEditingController();

  // FocusNodes for Enter Key Navigation
  final FocusNode _rateFocusNode = FocusNode();
  final FocusNode _totalPcsFocusNode = FocusNode();
  final FocusNode _grossWtFocusNode = FocusNode();
  final FocusNode _netWtFocusNode = FocusNode();
  final FocusNode _remarksFocusNode = FocusNode();

  // Multi-Item Stones and Diamonds Lists
  List<SkuLotStoneItem> _stoneItems = [];
  List<SkuLotDiamondItem> _diamondItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rateController.dispose();
    _totalPcsController.dispose();
    _totalGrossWtController.dispose();
    _totalNetWtController.dispose();
    _remarksController.dispose();

    _rateFocusNode.dispose();
    _totalPcsFocusNode.dispose();
    _grossWtFocusNode.dispose();
    _netWtFocusNode.dispose();
    _remarksFocusNode.dispose();

    super.dispose();
  }

  String _formatDateForApi(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  String _formatDateForDisplay(DateTime dt) {
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
  }

  Future<void> _loadData({bool reloadLotsOnly = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final fromStr = (_datePreset == 'ALL')
          ? null
          : _formatDateForApi(_fromDate);
      final toStr = (_datePreset == 'ALL') ? null : _formatDateForApi(_toDate);
      final activeStr = (_filterStatus == 'ALL')
          ? null
          : (_filterStatus == 'ACTIVE' ? '1' : '0');

      if (reloadLotsOnly) {
        final lotsData = await _api.getPrepareSkuLotsData(
          token,
          companyId: auth.activeCompanyId,
          fromDate: fromStr,
          toDate: toStr,
          isActive: activeStr,
        );
        if (mounted) {
          setState(() {
            _lots = lotsData['lots'] as List<PrepareSkuLotRecord>? ?? [];
            _applyFilter();
            _isLoading = false;
          });
        }
        return;
      }

      final results = await Future.wait([
        _api.getPrepareSkuLotsData(
          token,
          companyId: auth.activeCompanyId,
          fromDate: fromStr,
          toDate: toStr,
          isActive: activeStr,
        ),
        _api.getDesigners(token),
        _api.getProducts(token),
        _api.getSubProducts(token),
        _api.getPurities(token),
        _api.getBranches(token, companyId: auth.activeCompanyId),
        _api.getLatestRates(token),
      ]);

      if (mounted) {
        final lotsData = results[0] as Map<String, dynamic>;
        final designers = results[1] as List<DesignerRecord>;
        final products = results[2] as List<ProductRecord>;
        final subProducts = results[3] as List<SubProductRecord>;
        final purities = results[4] as List<Purity>;
        final branches = results[5] as List<Branch>;
        final latestRates = results[6] as LatestRatesSummary;

        // Filter purities for ORNAMENTS only
        final ornamentPurities = purities.where((p) {
          final type = p.type.toUpperCase().trim();
          return type.isEmpty || type == 'ORNAMENT' || type == 'ORNAMENTS';
        }).toList();

        setState(() {
          _lots = lotsData['lots'] as List<PrepareSkuLotRecord>? ?? [];
          _allDesigners = designers;
          _allProducts = products;
          _allSubProducts = subProducts;
          _allOrnamentPurities = ornamentPurities;
          _allBranches = branches;
          _latestRates = latestRates;

          // Default branch selection
          if (_selectedBranchId == null ||
              !_allBranches.any((b) => b.branchId == _selectedBranchId)) {
            if (_allBranches.isNotEmpty) {
              _selectedBranchId = _allBranches.first.branchId;
            }
          }

          // Default designer selection
          if (_selectedDesignerId == null ||
              !_allDesigners.any((d) => d.designerid == _selectedDesignerId)) {
            if (_allDesigners.isNotEmpty) {
              _selectedDesignerId = _allDesigners.first.designerid;
            }
          }

          // Default product selection
          if (_selectedProductId == null ||
              !_allProducts.any((p) => p.productid == _selectedProductId)) {
            if (_allProducts.isNotEmpty) {
              _selectedProductId = _allProducts.first.productid;
            }
          }

          // Default purity matching selected product metal
          _syncPurityWithSelectedProduct();

          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading Prepare SKU data: $e');
      }
    }
  }

  void _setDatePreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _datePreset = preset;
      if (preset == 'TODAY') {
        _fromDate = DateTime(now.year, now.month, now.day);
        _toDate = DateTime(now.year, now.month, now.day);
      } else if (preset == 'YESTERDAY') {
        final y = now.subtract(const Duration(days: 1));
        _fromDate = DateTime(y.year, y.month, y.day);
        _toDate = DateTime(y.year, y.month, y.day);
      } else if (preset == 'WEEK') {
        _fromDate = now.subtract(const Duration(days: 7));
        _toDate = now;
      } else if (preset == 'MONTH') {
        _fromDate = DateTime(now.year, now.month, 1);
        _toDate = now;
      } else if (preset == 'ALL') {
        _fromDate = DateTime(2020, 1, 1);
        _toDate = now.add(const Duration(days: 365));
      }
    });
    _loadData(reloadLotsOnly: true);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _datePreset = 'CUSTOM';
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
        }
      });
      _loadData(reloadLotsOnly: true);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _datePreset = 'CUSTOM';
      });
      _loadData(reloadLotsOnly: true);
    }
  }

  /// Returns purities matching the metal of the currently selected product
  List<Purity> _getMatchingPuritiesForSelectedProduct() {
    if (_selectedProductId == null) return _allOrnamentPurities;

    final selectedProduct = _allProducts
        .where((p) => p.productid == _selectedProductId)
        .firstOrNull;
    if (selectedProduct == null) return _allOrnamentPurities;

    final productMetal = (selectedProduct.metalid ?? '').trim().toUpperCase();
    final productMetalName = (selectedProduct.metalname ?? '')
        .trim()
        .toUpperCase();
    final productCatName = (selectedProduct.catname ?? '').trim().toUpperCase();
    final prodName = selectedProduct.productname.trim().toUpperCase();

    final isGold =
        productMetal == 'G' ||
        productMetalName.contains('GOLD') ||
        productCatName.contains('GOLD') ||
        prodName.contains('GOLD');
    final isSilver =
        productMetal == 'SR' ||
        productMetal == 'S' ||
        productMetalName.contains('SILVER') ||
        productCatName.contains('SILVER') ||
        prodName.contains('SILVER');
    final isPlatinum =
        productMetal == 'PT' ||
        productMetalName.contains('PLATINUM') ||
        productCatName.contains('PLATINUM');

    if (isGold) {
      final matching = _allOrnamentPurities.where((p) {
        final pMetal = p.metalid.trim().toUpperCase();
        final pName = p.purityname.toUpperCase();
        return pMetal == 'G' ||
            pName.contains('KT') ||
            pName.contains('GOLD') ||
            pName.contains('916') ||
            pName.contains('750') ||
            pName.contains('22') ||
            pName.contains('18') ||
            pName.contains('24') ||
            pName.contains('14') ||
            pName.contains('999');
      }).toList();
      if (matching.isNotEmpty) return matching;
    } else if (isSilver) {
      final matching = _allOrnamentPurities.where((p) {
        final pMetal = p.metalid.trim().toUpperCase();
        final pName = p.purityname.toUpperCase();
        return pMetal == 'SR' ||
            pMetal == 'S' ||
            pName.contains('SILVER') ||
            pName.contains('925') ||
            pName.contains('92.5');
      }).toList();
      if (matching.isNotEmpty) return matching;
    } else if (isPlatinum) {
      final matching = _allOrnamentPurities.where((p) {
        final pMetal = p.metalid.trim().toUpperCase();
        final pName = p.purityname.toUpperCase();
        return pMetal == 'PT' || pName.contains('PLAT');
      }).toList();
      if (matching.isNotEmpty) return matching;
    } else if (productMetal.isNotEmpty) {
      final matching = _allOrnamentPurities.where((p) {
        return p.metalid.trim().toUpperCase() == productMetal;
      }).toList();
      if (matching.isNotEmpty) return matching;
    }

    return _allOrnamentPurities;
  }

  /// Syncs the selected purity and purity rate with the selected product's metal
  void _syncPurityWithSelectedProduct() {
    final matchingPurities = _getMatchingPuritiesForSelectedProduct();
    if (matchingPurities.isNotEmpty) {
      if (_selectedPurityId == null ||
          !matchingPurities.any((p) => p.purityid == _selectedPurityId)) {
        _selectedPurityId = matchingPurities.first.purityid;
      }
    } else if (_allOrnamentPurities.isNotEmpty) {
      _selectedPurityId = _allOrnamentPurities.first.purityid;
    }
    _updatePurityRate(_selectedPurityId, force: true);
  }

  /// Updates the purity rate dynamically whenever purity selection changes
  void _updatePurityRate(int? purityId, {bool force = false}) {
    if (purityId == null) return;
    double foundRate = 0.0;

    // 1. Try to find direct purity rate from daily purity rates list
    for (final r in _latestRates.purityRates) {
      if (r.purityid == purityId && r.rate > 0) {
        foundRate = r.rate;
        break;
      }
    }

    // 2. Derive rate based on metal benchmark rates and purity percentage
    if (foundRate == 0.0) {
      final p = _allOrnamentPurities
          .where((pur) => pur.purityid == purityId)
          .firstOrNull;
      if (p != null) {
        final pName = p.purityname.toUpperCase();
        final pMetal = p.metalid.toUpperCase();
        final purityPer = p.purity > 0 ? p.purity : 91.6;

        final isGoldPurity =
            pMetal == 'G' ||
            pName.contains('KT') ||
            pName.contains('GOLD') ||
            pName.contains('916') ||
            pName.contains('750') ||
            pName.contains('22') ||
            pName.contains('18') ||
            pName.contains('24');
        final isSilverPurity =
            pMetal == 'SR' ||
            pMetal == 'S' ||
            pName.contains('SILVER') ||
            pName.contains('925') ||
            pName.contains('92.5');
        final isPlatinumPurity = pMetal == 'PT' || pName.contains('PLAT');

        if (isGoldPurity) {
          if (pName.contains('24') ||
              pName.contains('999') ||
              purityPer >= 99.0) {
            foundRate = _latestRates.gold24k > 0
                ? _latestRates.gold24k
                : 7450.0;
          } else if (pName.contains('22') ||
              pName.contains('916') ||
              (purityPer >= 91.0 && purityPer <= 92.0)) {
            foundRate = _latestRates.gold22k > 0
                ? _latestRates.gold22k
                : 6850.0;
          } else {
            final base24k = _latestRates.gold24k > 0
                ? _latestRates.gold24k
                : (_latestRates.gold22k > 0
                      ? (_latestRates.gold22k / 0.916)
                      : 7450.0);
            foundRate = base24k * (purityPer / 100.0);
          }
        } else if (isSilverPurity) {
          final baseSilver = _latestRates.silver > 0
              ? _latestRates.silver
              : 92.50;
          foundRate = baseSilver * (purityPer / 92.5);
        } else if (isPlatinumPurity) {
          final basePlat = _latestRates.platinum > 0
              ? _latestRates.platinum
              : 3800.0;
          foundRate = basePlat * (purityPer / 100.0);
        } else {
          final base24k = _latestRates.gold24k > 0
              ? _latestRates.gold24k
              : 7450.0;
          foundRate = base24k * (purityPer / 100.0);
        }
      }
    }

    if (foundRate > 0) {
      if (force ||
          _rateController.text.isEmpty ||
          _rateController.text == '0' ||
          _rateController.text == '0.00') {
        _rateController.text = foundRate.toStringAsFixed(2);
      }
    }
  }

  void _applyFilter() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final activeComp = auth.activeCompanyId.trim().toUpperCase();
    final q = _searchQuery.trim().toLowerCase();

    _filteredLots = _lots.where((lot) {
      // Company filter
      if (activeComp.isNotEmpty) {
        final lotComp = lot.companyid.trim().toUpperCase();
        if (lotComp.isNotEmpty && lotComp != activeComp) return false;
      }

      // Status filter
      if (_filterStatus == 'ACTIVE' && !lot.isActive) return false;
      if (_filterStatus == 'DISABLED' && lot.isActive) return false;

      // Branch filter
      if (_filterBranchId != 'ALL' &&
          lot.branchid.toUpperCase() != _filterBranchId.toUpperCase()) {
        return false;
      }

      // Designer filter
      if (_filterDesignerId != null && lot.designerid != _filterDesignerId) {
        return false;
      }

      // Product filter
      if (_filterProductId != null && lot.productid != _filterProductId) {
        return false;
      }

      // Is Assorted filter
      if (_filterIsAssorted != 'ALL' &&
          lot.isAssorted.toUpperCase() != _filterIsAssorted.toUpperCase()) {
        return false;
      }

      if (q.isEmpty) return true;

      final lotNum = lot.lotNumber.toLowerCase();
      final designer = (lot.designername ?? '').toLowerCase();
      final prod = (lot.productname ?? '').toLowerCase();
      final sub = (lot.subproductname ?? '').toLowerCase();
      final purity = (lot.purityname ?? '').toLowerCase();
      final branch = (lot.branchname ?? '').toLowerCase();
      final status = lot.status.toLowerCase();
      final remarks = lot.remarks.toLowerCase();

      return lotNum.contains(q) ||
          designer.contains(q) ||
          prod.contains(q) ||
          sub.contains(q) ||
          purity.contains(q) ||
          branch.contains(q) ||
          status.contains(q) ||
          remarks.contains(q);
    }).toList();
  }

  /// Automatically calculates net weight by deducting stone and diamond weights in grams
  void _autoCalculateNetWeight() {
    final grs = double.tryParse(_totalGrossWtController.text.trim()) ?? 0.0;

    double totalStoneGrams = 0.0;
    for (final s in _stoneItems) {
      totalStoneGrams += s.weightInGrams;
    }

    double totalDiamondGrams = 0.0;
    for (final d in _diamondItems) {
      totalDiamondGrams += d.weightInGrams;
    }

    double net = grs - totalStoneGrams - totalDiamondGrams;
    if (net < 0) net = 0.0;
    _totalNetWtController.text = net.toStringAsFixed(3);
  }

  void _openCreateForm() {
    setState(() {
      _editingRecord = null;
      _selectedBranchId = _allBranches.isNotEmpty
          ? _allBranches.first.branchId
          : null;
      _selectedDesignerId = _allDesigners.isNotEmpty
          ? _allDesigners.first.designerid
          : null;
      _selectedProductId = _allProducts.isNotEmpty
          ? _allProducts.first.productid
          : null;
      _selectedSubProductId = null;
      _isAssorted = 'NO';
      _rateController.clear();
      _totalPcsController.text = '1';
      _totalGrossWtController.text = '0.000';
      _totalNetWtController.text = '0.000';
      _remarksController.clear();
      _stoneItems = [];
      _diamondItems = [];
      _showForm = true;

      _syncPurityWithSelectedProduct();
    });
  }

  void _openEditForm(PrepareSkuLotRecord record) {
    setState(() {
      _editingRecord = record;
      _selectedBranchId = record.branchid;
      _selectedDesignerId = record.designerid;
      _selectedProductId = record.productid;
      _selectedSubProductId = record.subproductid;
      _selectedPurityId = record.purityid;
      _isAssorted = record.isAssorted.toUpperCase();
      _rateController.text = record.rate.toStringAsFixed(2);
      _totalPcsController.text = record.totalPcs.toString();
      _totalGrossWtController.text = record.totalGrossWeight.toStringAsFixed(3);
      _totalNetWtController.text = record.totalNetWeight.toStringAsFixed(3);

      // Populate multi-stone items with rates and purchase costs
      if (record.stoneItems.isNotEmpty) {
        _stoneItems = record.stoneItems
            .map(
              (s) => SkuLotStoneItem(
                stoneProductId: s.stoneProductId,
                stoneProductName: s.stoneProductName,
                stoneSubProductId: s.stoneSubProductId,
                stoneSubProductName: s.stoneSubProductName,
                stoneUnit: s.stoneUnit,
                pcs: s.pcs,
                weight: s.weight,
                rate: s.rate,
                amount: s.amount,
              ),
            )
            .toList();
      } else if (record.stoneProductid != null ||
          record.totalStonePcs > 0 ||
          record.totalStoneWeight > 0) {
        _stoneItems = [
          SkuLotStoneItem(
            stoneProductId: record.stoneProductid,
            stoneProductName: record.stoneProductname,
            stoneSubProductId: record.stoneSubproductid,
            stoneSubProductName: record.stoneSubproductname,
            stoneUnit: record.stoneUnit,
            pcs: record.totalStonePcs,
            weight: record.totalStoneWeight,
            rate: 0.0,
            amount: record.totalStoneAmount,
          ),
        ];
      } else {
        _stoneItems = [];
      }

      // Populate multi-diamond items with rates and purchase costs
      if (record.diamondItems.isNotEmpty) {
        _diamondItems = record.diamondItems
            .map(
              (d) => SkuLotDiamondItem(
                diamondProductId: d.diamondProductId,
                diamondProductName: d.diamondProductName,
                diamondSubProductId: d.diamondSubProductId,
                diamondSubProductName: d.diamondSubProductName,
                diamondUnit: d.diamondUnit,
                pcs: d.pcs,
                weight: d.weight,
                rate: d.rate,
                amount: d.amount,
              ),
            )
            .toList();
      } else if (record.diamondProductid != null ||
          record.totalDiamondPcs > 0 ||
          record.totalDiamondWeight > 0) {
        _diamondItems = [
          SkuLotDiamondItem(
            diamondProductId: record.diamondProductid,
            diamondProductName: record.diamondProductname,
            diamondSubProductId: record.diamondSubproductid,
            diamondSubProductName: record.diamondSubproductname,
            diamondUnit: record.diamondUnit,
            pcs: record.totalDiamondPcs,
            weight: record.totalDiamondWeight,
            rate: 0.0,
            amount: record.totalDiamondAmount,
          ),
        ];
      } else {
        _diamondItems = [];
      }

      _remarksController.text = record.remarks;
      _showForm = true;
    });
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDesignerId == null) {
      _showErrorSnackBar('Please select a Designer');
      return;
    }
    if (_selectedProductId == null) {
      _showErrorSnackBar('Please select a Product');
      return;
    }
    if (_selectedPurityId == null) {
      _showErrorSnackBar('Please select an Ornament Purity');
      return;
    }
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      _showErrorSnackBar('Please select a Branch');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    final activeComp = auth.activeCompanyId.isNotEmpty
        ? auth.activeCompanyId
        : 'COMP01';

    // Calculate aggregated stone and diamond sums
    final totalStonePcsSum = _stoneItems.fold<int>(
      0,
      (sum, item) => sum + item.pcs,
    );
    final totalStoneWtSum = _stoneItems.fold<double>(
      0.0,
      (sum, item) => sum + item.weight,
    );
    final totalStoneAmountSum = _stoneItems.fold<double>(
      0.0,
      (sum, item) => sum + item.calculatedAmount,
    );

    final totalDiamondPcsSum = _diamondItems.fold<int>(
      0,
      (sum, item) => sum + item.pcs,
    );
    final totalDiamondWtSum = _diamondItems.fold<double>(
      0.0,
      (sum, item) => sum + item.weight,
    );
    final totalDiamondAmountSum = _diamondItems.fold<double>(
      0.0,
      (sum, item) => sum + item.calculatedAmount,
    );

    final record = PrepareSkuLotRecord(
      lotId: _editingRecord?.lotId,
      lotNumber: _editingRecord?.lotNumber ?? '',
      companyid: activeComp,
      branchid: _selectedBranchId!,
      designerid: _selectedDesignerId!,
      productid: _selectedProductId!,
      subproductid: _selectedSubProductId,
      purityid: _selectedPurityId!,
      rate: double.tryParse(_rateController.text.trim()) ?? 0.0,
      isAssorted: _isAssorted,
      totalPcs: int.tryParse(_totalPcsController.text.trim()) ?? 1,
      totalGrossWeight:
          double.tryParse(_totalGrossWtController.text.trim()) ?? 0.0,
      totalNetWeight: double.tryParse(_totalNetWtController.text.trim()) ?? 0.0,
      stoneProductid: _stoneItems.isNotEmpty
          ? _stoneItems.first.stoneProductId
          : null,
      stoneSubproductid: _stoneItems.isNotEmpty
          ? _stoneItems.first.stoneSubProductId
          : null,
      stoneUnit: _stoneItems.isNotEmpty ? _stoneItems.first.stoneUnit : 'G',
      totalStonePcs: totalStonePcsSum,
      totalStoneWeight: totalStoneWtSum,
      totalStoneAmount: totalStoneAmountSum,
      stoneItems: _stoneItems,
      diamondProductid: _diamondItems.isNotEmpty
          ? _diamondItems.first.diamondProductId
          : null,
      diamondSubproductid: _diamondItems.isNotEmpty
          ? _diamondItems.first.diamondSubProductId
          : null,
      diamondUnit: _diamondItems.isNotEmpty
          ? _diamondItems.first.diamondUnit
          : 'C',
      totalDiamondPcs: totalDiamondPcsSum,
      totalDiamondWeight: totalDiamondWtSum,
      totalDiamondAmount: totalDiamondAmountSum,
      diamondItems: _diamondItems,
      isActive: _editingRecord?.isActive ?? true,
      status: _editingRecord?.status ?? 'PENDING_SKU',
      remarks: _remarksController.text.trim(),
    );

    try {
      if (_editingRecord == null) {
        // Create new SKU Lot
        final res = await _api.createPrepareSkuLot(token, record);
        setState(() => _isSaving = false);

        if (res['success'] == true) {
          final lotNumber =
              res['lot_number']?.toString() ??
              res['lot']?['lot_number']?.toString() ??
              'LOT-GENERATED';
          final lotData = res['lot'] != null
              ? PrepareSkuLotRecord.fromJson(res['lot'])
              : null;

          setState(() {
            _showForm = false;
          });
          await _loadData(reloadLotsOnly: true);

          if (mounted) {
            _showLotCreatedPopup(
              lotNumber,
              lotData ?? record.copyWith(lotNumber: lotNumber),
            );
          }
        } else {
          _showErrorSnackBar(res['message'] ?? 'Failed to create SKU Lot');
        }
      } else {
        // Update existing SKU Lot
        final res = await _api.updatePrepareSkuLot(
          token,
          _editingRecord!.lotId!,
          record,
        );
        setState(() => _isSaving = false);

        if (res['success'] == true) {
          setState(() {
            _showForm = false;
            _editingRecord = null;
          });
          await _loadData(reloadLotsOnly: true);
          if (mounted) {
            _showSuccessSnackBar(
              'SKU Lot ${_editingRecord?.lotNumber ?? ''} updated successfully',
            );
          }
        } else {
          _showErrorSnackBar(res['message'] ?? 'Failed to update SKU Lot');
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Error saving SKU Lot: $e');
    }
  }

  /// Deactivates / Disables or Reactivates a lot (Lot cannot be permanently deleted)
  Future<void> _toggleLotActive(PrepareSkuLotRecord record) async {
    final willDeactivate = record.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: willDeactivate
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                    : const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                willDeactivate
                    ? Icons.block_rounded
                    : Icons.check_circle_rounded,
                color: willDeactivate
                    ? const Color(0xFFD97706)
                    : const Color(0xFF059669),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              willDeactivate ? "Deactivate SKU Lot?" : "Reactivate SKU Lot?",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          willDeactivate
              ? "Are you sure you want to deactivate SKU Lot '${record.lotNumber}'?\nThis lot will be marked as Inactive / Disabled, but historical records will be preserved."
              : "Do you want to reactivate SKU Lot '${record.lotNumber}' for active stock tagging operations?",
          style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate
                  ? const Color(0xFFD97706)
                  : const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              willDeactivate ? "Deactivate Lot" : "Reactivate Lot",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);
    try {
      final res = await _api.togglePrepareSkuLotActive(
        token,
        record.lotId!,
        !willDeactivate,
      );
      if (res['success'] == true) {
        _showSuccessSnackBar(
          "SKU Lot ${record.lotNumber} ${willDeactivate ? 'deactivated' : 'reactivated'} successfully",
        );
        await _loadData(reloadLotsOnly: true);
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar(res['message'] ?? "Failed to update lot status");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar("Error updating lot status: $e");
    }
  }

  /// Interactive modal dialog displaying the newly generated Lot Number
  void _showLotCreatedPopup(String lotNumber, PrepareSkuLotRecord lot) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Celebration Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "SKU Lot Created Successfully!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "A unique Lot Number has been generated for this inventory batch.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),

                  // Lot Number Display Card with Copy
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "GENERATED LOT NUMBER",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                lotNumber,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD97706),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: lotNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Lot Number copied to clipboard!",
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text("Copy"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Summary Details Table
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _buildPopupSummaryRow(
                          "Product",
                          "${lot.productname ?? 'Product'} (${lot.subproductname ?? '-'})",
                        ),
                        const Divider(height: 12, color: Color(0xFFE2E8F0)),
                        _buildPopupSummaryRow(
                          "Purity & Rate",
                          "${lot.purityname ?? 'Purity'} • ₹${lot.rate.toStringAsFixed(2)}/g",
                        ),
                        const Divider(height: 12, color: Color(0xFFE2E8F0)),
                        _buildPopupSummaryRow(
                          "Pieces & Gross Wt",
                          "${lot.totalPcs} pcs • ${lot.totalGrossWeight.toStringAsFixed(3)} g",
                        ),
                        const Divider(height: 12, color: Color(0xFFE2E8F0)),
                        _buildPopupSummaryRow(
                          "Net Weight",
                          "${lot.totalNetWeight.toStringAsFixed(3)} g",
                          highlight: true,
                        ),
                        if (lot.totalStoneAmount > 0 ||
                            lot.totalDiamondAmount > 0) ...[
                          const Divider(height: 12, color: Color(0xFFE2E8F0)),
                          _buildPopupSummaryRow(
                            "Stone / Diamond Cost",
                            "₹${(lot.totalStoneAmount + lot.totalDiamondAmount).toStringAsFixed(2)}",
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Close Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlassTheme.primaryNeon,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Done & Continue",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupSummaryRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            color: highlight
                ? const Color(0xFF0284C7)
                : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  /// ================= STONES & DIAMONDS MASTER POPUP WINDOW =================
  /// Triggered after Gross Weight entry or when clicking the "Stones & Diamonds Grid" button
  Future<void> _openStonesDiamondsDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StonesDiamondsDialog(
        initialStones: _stoneItems,
        initialDiamonds: _diamondItems,
        grossWeight:
            double.tryParse(_totalGrossWtController.text.trim()) ?? 0.0,
        allProducts: _allProducts,
        allSubProducts: _allSubProducts,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _stoneItems = (result['stones'] as List<SkuLotStoneItem>?) ?? [];
        _diamondItems = (result['diamonds'] as List<SkuLotDiamondItem>?) ?? [];
        _autoCalculateNetWeight();
      });
      FocusScope.of(context).requestFocus(_remarksFocusNode);
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    Widget? prefixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      isDense: true,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: GlassTheme.accentRose,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLots = _filteredLots.length;
    final totalPcs = _filteredLots.fold<int>(
      0,
      (sum, lot) => sum + lot.totalPcs,
    );
    final totalGrsWt = _filteredLots.fold<double>(
      0.0,
      (sum, lot) => sum + lot.totalGrossWeight,
    );
    final totalNetWt = _filteredLots.fold<double>(
      0.0,
      (sum, lot) => sum + lot.totalNetWeight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Quick Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_buildHeader(), _buildHeaderActionButtons()],
              ),
              const SizedBox(height: 20),

              // Summary Stat Cards
              _buildStatCards(totalLots, totalPcs, totalGrsWt, totalNetWt),
              const SizedBox(height: 20),

              // Entry Form (Expandable)
              if (_showForm) ...[_buildFormCard(), const SizedBox(height: 24)],

              // Filter & Search Toolbar (with Date Range Filters)
              _buildToolbar(),
              const SizedBox(height: 16),

              // Data Table / Cards View
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredLots.isEmpty)
                _buildEmptyState()
              else if (_isTableView)
                _buildLotsTableView()
              else
                _buildLotsCardView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.onBack != null) ...[
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF0F172A),
                ),
                onPressed: widget.onBack,
                tooltip: "Back",
              ),
              const SizedBox(width: 8),
            ],
            const Text(
              "STOCK / PREPARE FOR SKU",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Prepare for SKU (Lot Master)",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
          onPressed: () => _loadData(reloadLotsOnly: true),
          tooltip: "Refresh Data",
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showForm
              ? () => setState(() => _showForm = false)
              : _openCreateForm,
          icon: Icon(
            _showForm ? Icons.close_rounded : Icons.add_rounded,
            size: 18,
          ),
          label: Text(_showForm ? "Close Form" : "+ New SKU Lot"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _showForm
                ? const Color(0xFF64748B)
                : GlassTheme.primaryNeon,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(
    int totalLots,
    int totalPcs,
    double totalGrsWt,
    double totalNetWt,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              "Total SKU Lots",
              totalLots.toString(),
              Icons.inventory_2_rounded,
              const Color(0xFF4F46E5),
              isWide,
            ),
            _buildStatCard(
              "Total Pieces",
              "$totalPcs pcs",
              Icons.category_rounded,
              const Color(0xFF059669),
              isWide,
            ),
            _buildStatCard(
              "Gross Weight",
              "${totalGrsWt.toStringAsFixed(3)} g",
              Icons.scale_rounded,
              const Color(0xFFD97706),
              isWide,
            ),
            _buildStatCard(
              "Net Weight",
              "${totalNetWt.toStringAsFixed(3)} g",
              Icons.diamond_rounded,
              const Color(0xFF0284C7),
              isWide,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isWide,
  ) {
    return Container(
      width: isWide ? 220 : 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    final matchingSubProducts = _allSubProducts.where((sp) {
      if (_selectedProductId == null) return true;
      return sp.productid == _selectedProductId;
    }).toList();

    final matchingOrnamentPurities = _getMatchingPuritiesForSelectedProduct();
    final matchingPurityId =
        (_selectedPurityId != null &&
            matchingOrnamentPurities.any(
              (p) => p.purityid == _selectedPurityId,
            ))
        ? _selectedPurityId
        : (matchingOrnamentPurities.isNotEmpty
              ? matchingOrnamentPurities.first.purityid
              : null);

    final stonePcsCount = _stoneItems.fold<int>(0, (sum, i) => sum + i.pcs);
    final stoneWtSum = _stoneItems.fold<double>(
      0.0,
      (sum, i) => sum + i.weightInGrams,
    );
    final stoneAmtSum = _stoneItems.fold<double>(
      0.0,
      (sum, i) => sum + i.calculatedAmount,
    );

    final diamondPcsCount = _diamondItems.fold<int>(0, (sum, i) => sum + i.pcs);
    final diamondWtSum = _diamondItems.fold<double>(
      0.0,
      (sum, i) => sum + i.weightInGrams,
    );
    final diamondAmtSum = _diamondItems.fold<double>(
      0.0,
      (sum, i) => sum + i.calculatedAmount,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GlassTheme.primaryNeon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _editingRecord != null
                            ? Icons.edit_note_rounded
                            : Icons.post_add_rounded,
                        color: GlassTheme.primaryNeon,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingRecord != null
                              ? "Edit SKU Lot: ${_editingRecord!.lotNumber}"
                              : "Prepare New SKU Lot",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Configure items, weights, purity, stones & diamonds. Lot Number is generated on save.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () => setState(() => _showForm = false),
                  tooltip: "Close Form",
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFE2E8F0)),

            // Section 1: Main Identification & Classification
            const Text(
              "1. ITEM & MASTER ATTRIBUTES",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Branch Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedBranchId,
                    decoration: _inputDecoration(
                      "Branch *",
                      prefixIcon: const Icon(
                        Icons.storefront_rounded,
                        size: 20,
                      ),
                    ),
                    items: _allBranches.map((b) {
                      return DropdownMenuItem(
                        value: b.branchId,
                        child: Text(
                          b.branchName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBranchId = val),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Branch is required" : null,
                  ),
                ),

                // Designer Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedDesignerId,
                    decoration: _inputDecoration(
                      "Designer *",
                      prefixIcon: const Icon(
                        Icons.design_services_rounded,
                        size: 20,
                      ),
                    ),
                    items: _allDesigners.map((d) {
                      return DropdownMenuItem(
                        value: d.designerid,
                        child: Text(
                          "${d.designername} (${d.designershortname})",
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedDesignerId = val),
                    validator: (v) => v == null ? "Designer is required" : null,
                  ),
                ),

                // Product Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _selectedProductId,
                    decoration: _inputDecoration(
                      "Product *",
                      prefixIcon: const Icon(Icons.category_rounded, size: 20),
                    ),
                    items: _allProducts.map((p) {
                      final mName =
                          (p.metalname != null && p.metalname!.isNotEmpty)
                          ? " [${p.metalname}]"
                          : "";
                      return DropdownMenuItem(
                        value: p.productid,
                        child: Text(
                          "${p.productname}$mName",
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedProductId = val;
                        if (_selectedSubProductId != null &&
                            !_allSubProducts.any(
                              (sp) =>
                                  sp.subproductid == _selectedSubProductId &&
                                  sp.productid == val,
                            )) {
                          _selectedSubProductId = null;
                        }
                        _syncPurityWithSelectedProduct();
                      });
                    },
                    validator: (v) => v == null ? "Product is required" : null,
                  ),
                ),

                // Sub-Product Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _selectedSubProductId,
                    decoration: _inputDecoration(
                      "Sub-Product (Optional)",
                      prefixIcon: const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 20,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          "-- All / None --",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      ...matchingSubProducts.map((sp) {
                        return DropdownMenuItem<int?>(
                          value: sp.subproductid,
                          child: Text(
                            sp.subproductname,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedSubProductId = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Purity & Rates
            const Text(
              "2. PURITY, RATE & CONFIGURATION",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Ornament Purity Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: matchingPurityId,
                    decoration: _inputDecoration(
                      "Ornament Purity *",
                      prefixIcon: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 20,
                      ),
                    ),
                    items: matchingOrnamentPurities.map((p) {
                      return DropdownMenuItem(
                        value: p.purityid,
                        child: Text(
                          "${p.purityname} (${p.purityshortname}) - ${p.purity}%",
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPurityId = val;
                        _updatePurityRate(val, force: true);
                      });
                      FocusScope.of(context).requestFocus(_rateFocusNode);
                    },
                    validator: (v) => v == null ? "Purity is required" : null,
                  ),
                ),

                // Purity Rate (₹ / g)
                SizedBox(
                  width: 260,
                  child: TextFormField(
                    controller: _rateController,
                    focusNode: _rateFocusNode,
                    decoration: _inputDecoration(
                      "Purity Rate (₹ / g) *",
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 20,
                      ),
                      hint: "e.g. 7250.00",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_totalPcsFocusNode),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Rate is required";
                      }
                      final d = double.tryParse(v.trim());
                      if (d == null || d <= 0) return "Enter valid rate";
                      return null;
                    },
                  ),
                ),

                // IS ASSORTED Dropdown
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _isAssorted,
                    decoration: _inputDecoration(
                      "Is Assorted? *",
                      prefixIcon: const Icon(
                        Icons.call_split_rounded,
                        size: 20,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'NO',
                        child: Text(
                          "NO (Single SKU)",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'YES',
                        child: Text(
                          "YES (Assorted Lot)",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _isAssorted = val ?? 'NO'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 3: Quantity & Weights (With Enter Navigation & Stones Trigger)
            const Text(
              "3. QUANTITY & WEIGHTS",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // Total Pcs
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _totalPcsController,
                    focusNode: _totalPcsFocusNode,
                    decoration: _inputDecoration(
                      "Total Pcs *",
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_grossWtFocusNode),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "Pcs required";
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return "Must be > 0";
                      return null;
                    },
                  ),
                ),

                // Total Gross Weight (Pressing Enter or completing entry triggers Stones & Diamonds modal)
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _totalGrossWtController,
                    focusNode: _grossWtFocusNode,
                    decoration: _inputDecoration(
                      "Total Gross Wt (g) *",
                      prefixIcon: const Icon(Icons.scale_rounded, size: 20),
                      hint: "0.000",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,3}'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _autoCalculateNetWeight(),
                    onFieldSubmitted: (val) {
                      _autoCalculateNetWeight();
                      final grs = double.tryParse(val.trim()) ?? 0.0;
                      if (grs > 0) {
                        _openStonesDiamondsDialog();
                      } else {
                        FocusScope.of(context).requestFocus(_netWtFocusNode);
                      }
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Gross weight required";
                      }
                      final d = double.tryParse(v.trim());
                      if (d == null || d <= 0) return "Must be > 0";
                      return null;
                    },
                  ),
                ),

                // Total Net Weight (Auto-calculated with less weight from stones/diamonds)
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _totalNetWtController,
                    focusNode: _netWtFocusNode,
                    decoration: _inputDecoration(
                      "Total Net Wt (g) *",
                      prefixIcon: const Icon(
                        Icons.fitness_center_rounded,
                        size: 20,
                      ),
                      hint: "0.000",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,3}'),
                      ),
                    ],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_remarksFocusNode),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Net weight required";
                      }
                      final d = double.tryParse(v.trim());
                      if (d == null || d < 0) return "Must be >= 0";
                      final grs =
                          double.tryParse(
                            _totalGrossWtController.text.trim(),
                          ) ??
                          0.0;
                      if (grs > 0 && d > grs) return "Cannot exceed Gross Wt";
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 4: Stones & Diamonds Interactive Summary & Modal Trigger Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
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
                              color: const Color(
                                0xFF059669,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.diamond_rounded,
                              color: Color(0xFF059669),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "STONES & DIAMONDS ATTACHMENT",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                "Stones: ${stonePcsCount}p (${stoneWtSum.toStringAsFixed(3)}g - ₹${stoneAmtSum.toStringAsFixed(2)}) | Diamonds: ${diamondPcsCount}p (${diamondWtSum.toStringAsFixed(3)}g - ₹${diamondAmtSum.toStringAsFixed(2)})",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _openStonesDiamondsDialog,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty)
                              ? "Edit Stones & Diamonds Grid (${_stoneItems.length + _diamondItems.length})"
                              : "💎 Add Stones & Diamonds (Grid)",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (_stoneItems.isNotEmpty ||
                                  _diamondItems.isNotEmpty)
                              ? const Color(0xFF059669)
                              : const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ..._stoneItems.map(
                          (s) => Chip(
                            backgroundColor: const Color(0xFFECFDF5),
                            avatar: const Icon(
                              Icons.grain_rounded,
                              size: 16,
                              color: Color(0xFF059669),
                            ),
                            label: Text(
                              "Stn: ${s.pcs}p • ${s.weight.toStringAsFixed(3)}${s.stoneUnit} • ₹${s.calculatedAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ),
                        ..._diamondItems.map(
                          (d) => Chip(
                            backgroundColor: const Color(0xFFF0F9FF),
                            avatar: const Icon(
                              Icons.diamond_rounded,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                            label: Text(
                              "Dia: ${d.pcs}p • ${d.weight.toStringAsFixed(3)}${d.diamondUnit} • ₹${d.calculatedAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Remarks
            TextFormField(
              controller: _remarksController,
              focusNode: _remarksFocusNode,
              decoration: _inputDecoration(
                "Remarks / Lot Notes (Optional)",
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                hint:
                    "Add specific instructions, packet details, or supplier info...",
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveRecord(),
            ),
            const SizedBox(height: 24),

            // Form Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _showForm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRecord,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _isSaving
                        ? "Saving..."
                        : (_editingRecord != null
                              ? "Update SKU Lot"
                              : "Save & Generate Lot Number"),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.primaryNeon,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= TOOLBAR WITH COMPREHENSIVE DATE & STATUS FILTERS =================
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date Range Filters & Presets
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Presets
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.date_range_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    DropdownButton<String>(
                      value: _datePreset,
                      underline: const SizedBox(),
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'TODAY',
                          child: Text("Today (Default)"),
                        ),
                        DropdownMenuItem(
                          value: 'YESTERDAY',
                          child: Text("Yesterday"),
                        ),
                        DropdownMenuItem(
                          value: 'WEEK',
                          child: Text("Last 7 Days"),
                        ),
                        DropdownMenuItem(
                          value: 'MONTH',
                          child: Text("This Month"),
                        ),
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text("All Historical Lots"),
                        ),
                        DropdownMenuItem(
                          value: 'CUSTOM',
                          child: Text("Custom Range"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) _setDatePreset(val);
                      },
                    ),
                  ],
                ),
              ),

              // From Date Picker Button
              OutlinedButton.icon(
                onPressed: _pickFromDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: Text(
                  "From: ${_formatDateForDisplay(_fromDate)}",
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // To Date Picker Button
              OutlinedButton.icon(
                onPressed: _pickToDate,
                icon: const Icon(Icons.event_rounded, size: 14),
                label: Text(
                  "To: ${_formatDateForDisplay(_toDate)}",
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Status Filter (Active / Disabled / All)
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _filterStatus,
                  decoration: _inputDecoration(
                    "Status Filter",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text(
                        "All Statuses",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'ACTIVE',
                      child: Text(
                        "Active Lots Only",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'DISABLED',
                      child: Text(
                        "Disabled / Inactive",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterStatus = val ?? 'ALL';
                    });
                    _loadData(reloadLotsOnly: true);
                  },
                ),
              ),

              // Search Button
              ElevatedButton.icon(
                onPressed: () => _loadData(reloadLotsOnly: true),
                icon: const Icon(Icons.filter_alt_rounded, size: 15),
                label: const Text(
                  "Apply Filter",
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Row 2: Search Input & Master Filter Dropdowns
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search Lot #, Designer, Product...",
                    isDense: true,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),

              // Branch Filter
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _filterBranchId,
                  decoration: _inputDecoration(
                    "Branch",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ALL',
                      child: Text(
                        "All Branches",
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._allBranches.map(
                      (b) => DropdownMenuItem(
                        value: b.branchId,
                        child: Text(
                          b.branchName,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterBranchId = val ?? 'ALL';
                      _applyFilter();
                    });
                  },
                ),
              ),

              // Designer Filter
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _filterDesignerId,
                  decoration: _inputDecoration(
                    "Designer",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        "All Designers",
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._allDesigners.map(
                      (d) => DropdownMenuItem<int?>(
                        value: d.designerid,
                        child: Text(
                          d.designername,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterDesignerId = val;
                      _applyFilter();
                    });
                  },
                ),
              ),

              // Is Assorted Filter
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _filterIsAssorted,
                  decoration: _inputDecoration(
                    "Assorted",
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text(
                        "All Lots",
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'NO',
                      child: Text(
                        "Single SKU (NO)",
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'YES',
                      child: Text(
                        "Assorted (YES)",
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterIsAssorted = val ?? 'ALL';
                      _applyFilter();
                    });
                  },
                ),
              ),

              // View Switcher (Table vs Card)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.table_rows_rounded,
                      color: _isTableView
                          ? GlassTheme.primaryNeon
                          : const Color(0xFF94A3B8),
                    ),
                    tooltip: "Table View",
                    onPressed: () => setState(() => _isTableView = true),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.grid_view_rounded,
                      color: !_isTableView
                          ? GlassTheme.primaryNeon
                          : const Color(0xFF94A3B8),
                    ),
                    tooltip: "Card Grid View",
                    onPressed: () => setState(() => _isTableView = false),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF94A3B8),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _datePreset == 'TODAY'
                ? "No SKU Lots Created Today (${_formatDateForDisplay(_fromDate)})"
                : "No Prepare SKU Lots Found in Selected Date Range",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            "Create your first SKU preparation lot or select 'All Historical Lots' in the date filter above.",
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => _setDatePreset('ALL'),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text("View All Historical Lots"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _openCreateForm,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("+ New SKU Lot"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.primaryNeon,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLotsTableView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          headingTextStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
          dataTextStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF0F172A),
          ),
          columnSpacing: 20,
          horizontalMargin: 20,
          columns: const [
            DataColumn(label: Text("STATUS")),
            DataColumn(label: Text("LOT NUMBER")),
            DataColumn(label: Text("DATE")),
            DataColumn(label: Text("BRANCH")),
            DataColumn(label: Text("DESIGNER")),
            DataColumn(label: Text("PRODUCT & SUBPRODUCT")),
            DataColumn(label: Text("PURITY & RATE")),
            DataColumn(label: Text("PCS")),
            DataColumn(label: Text("GROSS WT")),
            DataColumn(label: Text("NET WT")),
            DataColumn(label: Text("STONES / DIAMONDS")),
            DataColumn(label: Text("ACTIONS")),
          ],
          rows: _filteredLots.map((lot) {
            final stoneSummary = lot.stoneItems.isNotEmpty
                ? "${lot.stoneItems.length} items (${lot.totalStoneWeight.toStringAsFixed(2)}g • ₹${lot.totalStoneAmount.toStringAsFixed(0)})"
                : (lot.totalStonePcs > 0
                      ? "${lot.totalStonePcs}p (${lot.totalStoneWeight.toStringAsFixed(2)}${lot.stoneUnit})"
                      : "-");

            final diamondSummary = lot.diamondItems.isNotEmpty
                ? "${lot.diamondItems.length} items (${lot.totalDiamondWeight.toStringAsFixed(2)}ct • ₹${lot.totalDiamondAmount.toStringAsFixed(0)})"
                : (lot.totalDiamondPcs > 0
                      ? "${lot.totalDiamondPcs}p (${lot.totalDiamondWeight.toStringAsFixed(2)}${lot.diamondUnit})"
                      : "-");

            final dateFormatted =
                (lot.createdAt != null && lot.createdAt!.length >= 10)
                ? lot.createdAt!.substring(0, 10)
                : '-';

            return DataRow(
              cells: [
                // Status Badge (Active / Disabled)
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: lot.isActive
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: lot.isActive
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Text(
                      lot.isActive ? "ACTIVE" : "DISABLED",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: lot.isActive
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),

                // Lot Number with copy
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          lot.lotNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        tooltip: "Copy Lot Number",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: lot.lotNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Copied ${lot.lotNumber}"),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Date
                DataCell(
                  Text(
                    dateFormatted,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),

                // Branch
                DataCell(
                  Text(
                    lot.branchname ?? lot.branchid,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

                // Designer
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lot.designername ?? "ID: ${lot.designerid}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (lot.designershortname != null &&
                          lot.designershortname!.isNotEmpty)
                        Text(
                          lot.designershortname!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),

                // Product & Subproduct
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lot.productname ?? "ID: ${lot.productid}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (lot.subproductname != null &&
                          lot.subproductname!.isNotEmpty)
                        Text(
                          lot.subproductname!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),

                // Purity & Rate
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lot.purityname ?? "ID: ${lot.purityid}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "₹${lot.rate.toStringAsFixed(2)}/g",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pcs
                DataCell(
                  Text(
                    "${lot.totalPcs} pcs",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // Gross Wt
                DataCell(
                  Text(
                    "${lot.totalGrossWeight.toStringAsFixed(3)} g",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                // Net Wt
                DataCell(
                  Text(
                    "${lot.totalNetWeight.toStringAsFixed(3)} g",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),

                // Stones / Diamonds summary
                DataCell(
                  Text(
                    "Stn: $stoneSummary\nDia: $diamondSummary",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),

                // Actions (Edit & Deactivate/Reactivate)
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                        tooltip: "Edit Lot",
                        onPressed: () => _openEditForm(lot),
                      ),
                      IconButton(
                        icon: Icon(
                          lot.isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: lot.isActive
                              ? const Color(0xFFD97706)
                              : const Color(0xFF059669),
                        ),
                        tooltip: lot.isActive
                            ? "Deactivate / Disable Lot"
                            : "Reactivate Lot",
                        onPressed: () => _toggleLotActive(lot),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLotsCardView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 3
            : (constraints.maxWidth > 700 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 360,
          ),
          itemCount: _filteredLots.length,
          itemBuilder: (context, index) {
            final lot = _filteredLots[index];
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: lot.isActive
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFFCA5A5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Card Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          lot.lotNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: lot.isActive
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lot.isActive ? 'ACTIVE' : 'DISABLED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: lot.isActive
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                            tooltip: "Copy Lot Number",
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: lot.lotNumber),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Copied ${lot.lotNumber}"),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Card Details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${lot.productname ?? 'Product'} ${lot.subproductname != null ? '• ${lot.subproductname}' : ''}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Designer: ${lot.designername ?? 'ID ${lot.designerid}'} | Branch: ${lot.branchname ?? lot.branchid}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Purity & Rate",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  lot.purityname ?? 'Purity',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  "₹${lot.rate.toStringAsFixed(2)}/g",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${lot.totalPcs} Pcs",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  "Grs: ${lot.totalGrossWeight.toStringAsFixed(3)}g",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  "Net: ${lot.totalNetWeight.toStringAsFixed(3)}g",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Card Footer Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Stn: ${lot.stoneItems.isNotEmpty ? '${lot.stoneItems.length} items (₹${lot.totalStoneAmount.toStringAsFixed(0)})' : '${lot.totalStonePcs}p'}${lot.diamondItems.isNotEmpty ? ' | Dia: ${lot.diamondItems.length} items (₹${lot.totalDiamondAmount.toStringAsFixed(0)})' : (lot.totalDiamondPcs > 0 ? ' | Dia: ${lot.totalDiamondPcs}p' : '')}",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                            tooltip: "Edit Lot",
                            onPressed: () => _openEditForm(lot),
                          ),
                          IconButton(
                            icon: Icon(
                              lot.isActive
                                  ? Icons.block_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: lot.isActive
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF059669),
                            ),
                            tooltip: lot.isActive
                                ? "Deactivate / Disable Lot"
                                : "Reactivate Lot",
                            onPressed: () => _toggleLotActive(lot),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// =========================================================================
/// UNIFIED STONES & DIAMONDS MASTER POPUP DIALOG (SINGLE WINDOW ENTRY)
/// =========================================================================
class _StonesDiamondsDialog extends StatefulWidget {
  final List<SkuLotStoneItem> initialStones;
  final List<SkuLotDiamondItem> initialDiamonds;
  final double grossWeight;
  final List<ProductRecord> allProducts;
  final List<SubProductRecord> allSubProducts;

  const _StonesDiamondsDialog({
    required this.initialStones,
    required this.initialDiamonds,
    required this.grossWeight,
    required this.allProducts,
    required this.allSubProducts,
  });

  @override
  State<_StonesDiamondsDialog> createState() => _StonesDiamondsDialogState();
}

class _StonesDiamondsDialogState extends State<_StonesDiamondsDialog> {
  late List<SkuLotStoneItem> _stones;
  late List<SkuLotDiamondItem> _diamonds;

  List<ProductRecord> _combinedProducts = [];

  // Quick Entry Form Controls
  int? _quickProductId;
  int? _quickSubProductId;
  String _quickUnit = 'G';
  final _quickPcsCtrl = TextEditingController(text: '1');
  final _quickWtCtrl = TextEditingController();
  final _quickRateCtrl = TextEditingController();
  final _quickAmtCtrl = TextEditingController();

  final FocusNode _quickProdFocus = FocusNode();
  final FocusNode _quickSubProdFocus = FocusNode();
  final FocusNode _quickUnitFocus = FocusNode();
  final FocusNode _quickPcsFocus = FocusNode();
  final FocusNode _quickWtFocus = FocusNode();
  final FocusNode _quickRateFocus = FocusNode();
  final FocusNode _quickAmtFocus = FocusNode();
  final FocusNode _quickAddFocus = FocusNode();

  // Editing state
  bool _isEditing = false;
  bool _editingIsDiamond = false;
  int? _editingIndex;
  String? _noticeMsg;

  bool _isDiamondProduct(ProductRecord? p) {
    if (p == null) return false;
    final m = (p.metalid ?? '').toUpperCase().trim();
    final d = p.diastone.toUpperCase().trim();
    return m == 'D' || m == 'DIAMOND' || d == 'D' || d == 'DIAMOND';
  }

  bool _isStoneProduct(ProductRecord? p) {
    if (p == null) return false;
    final m = (p.metalid ?? '').toUpperCase().trim();
    final d = p.diastone.toUpperCase().trim();
    return m == 'T' ||
        m == 'STONE' ||
        m == 'S' ||
        d == 'S' ||
        d == 'STONE' ||
        d == 'SYNTHETIC' ||
        d == 'P' ||
        d == 'PRECIOUS';
  }

  @override
  void initState() {
    super.initState();

    // Deep copy initial lists
    _stones = widget.initialStones
        .map(
          (s) => SkuLotStoneItem(
            stoneProductId: s.stoneProductId,
            stoneProductName: s.stoneProductName,
            stoneSubProductId: s.stoneSubProductId,
            stoneSubProductName: s.stoneSubProductName,
            stoneUnit: s.stoneUnit,
            pcs: s.pcs,
            weight: s.weight,
            rate: s.rate,
            amount: s.amount,
          ),
        )
        .toList();

    _diamonds = widget.initialDiamonds
        .map(
          (d) => SkuLotDiamondItem(
            diamondProductId: d.diamondProductId,
            diamondProductName: d.diamondProductName,
            diamondSubProductId: d.diamondSubProductId,
            diamondSubProductName: d.diamondSubProductName,
            diamondUnit: d.diamondUnit,
            pcs: d.pcs,
            weight: d.weight,
            rate: d.rate,
            amount: d.amount,
          ),
        )
        .toList();

    // Filter combined stone and diamond products
    _combinedProducts = widget.allProducts
        .where((p) => _isDiamondProduct(p) || _isStoneProduct(p))
        .toList();
    if (_combinedProducts.isEmpty) {
      _combinedProducts = widget.allProducts;
    }

    if (_combinedProducts.isNotEmpty) {
      _quickProductId = _combinedProducts.first.productid;
      _quickUnit = _isDiamondProduct(_combinedProducts.first) ? 'C' : 'G';
    }
  }

  @override
  void dispose() {
    _quickPcsCtrl.dispose();
    _quickWtCtrl.dispose();
    _quickRateCtrl.dispose();
    _quickAmtCtrl.dispose();

    _quickProdFocus.dispose();
    _quickSubProdFocus.dispose();
    _quickUnitFocus.dispose();
    _quickPcsFocus.dispose();
    _quickWtFocus.dispose();
    _quickRateFocus.dispose();
    _quickAmtFocus.dispose();
    _quickAddFocus.dispose();

    super.dispose();
  }

  void _onWeightOrRateChanged() {
    final wt = double.tryParse(_quickWtCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_quickRateCtrl.text.trim()) ?? 0.0;
    if (wt > 0 && rate > 0) {
      final total = wt * rate;
      _quickAmtCtrl.text = total.toStringAsFixed(2);
    }
  }

  void _addOrUpdateItem() {
    final wt = double.tryParse(_quickWtCtrl.text.trim()) ?? 0.0;
    if (_quickProductId == null) {
      _showModalError("Please select a Stone / Diamond Product");
      _quickProdFocus.requestFocus();
      return;
    }
    if (wt <= 0) {
      _showModalError("Please enter a valid Weight / Carats > 0");
      _quickWtFocus.requestFocus();
      return;
    }

    final pcs = int.tryParse(_quickPcsCtrl.text.trim()) ?? 1;
    final rate = double.tryParse(_quickRateCtrl.text.trim()) ?? 0.0;
    final enteredAmt = double.tryParse(_quickAmtCtrl.text.trim()) ?? 0.0;
    final amount = enteredAmt > 0 ? enteredAmt : (wt * rate);

    final prod = _combinedProducts.firstWhere(
      (p) => p.productid == _quickProductId,
      orElse: () => _combinedProducts.first,
    );
    final isDia = _isDiamondProduct(prod);

    final matchingSubs = widget.allSubProducts
        .where((sp) => sp.subproductid == _quickSubProductId)
        .toList();
    final subName = matchingSubs.isNotEmpty
        ? matchingSubs.first.subproductname
        : null;

    setState(() {
      if (_isEditing && _editingIndex != null) {
        if (_editingIsDiamond) {
          if (_editingIndex! < _diamonds.length) {
            _diamonds.removeAt(_editingIndex!);
          }
        } else {
          if (_editingIndex! < _stones.length) {
            _stones.removeAt(_editingIndex!);
          }
        }
      }

      if (isDia) {
        _diamonds.add(
          SkuLotDiamondItem(
            diamondProductId: _quickProductId,
            diamondProductName: prod.productname,
            diamondSubProductId: _quickSubProductId,
            diamondSubProductName: subName,
            diamondUnit: _quickUnit,
            pcs: pcs > 0 ? pcs : 1,
            weight: wt,
            rate: rate,
            amount: amount,
          ),
        );
      } else {
        _stones.add(
          SkuLotStoneItem(
            stoneProductId: _quickProductId,
            stoneProductName: prod.productname,
            stoneSubProductId: _quickSubProductId,
            stoneSubProductName: subName,
            stoneUnit: _quickUnit,
            pcs: pcs > 0 ? pcs : 1,
            weight: wt,
            rate: rate,
            amount: amount,
          ),
        );
      }

      _isEditing = false;
      _editingIndex = null;
      _quickPcsCtrl.text = '1';
      _quickWtCtrl.clear();
      _quickRateCtrl.clear();
      _quickAmtCtrl.clear();
      _noticeMsg =
          "✓ ${isDia ? '✨ Diamond' : '💎 Stone'} item added! Total: ₹${amount.toStringAsFixed(2)}";
    });

    // Re-focus immediately on Product Dropdown for rapid consecutive data entry
    _quickProdFocus.requestFocus();
  }

  void _editStoneItem(int index) {
    final item = _stones[index];
    setState(() {
      _isEditing = true;
      _editingIsDiamond = false;
      _editingIndex = index;

      _quickProductId = item.stoneProductId;
      _quickSubProductId = item.stoneSubProductId;
      _quickUnit = item.stoneUnit.toUpperCase() == 'C' ? 'C' : 'G';
      _quickPcsCtrl.text = item.pcs.toString();
      _quickWtCtrl.text = item.weight > 0 ? item.weight.toStringAsFixed(3) : '';
      _quickRateCtrl.text = item.rate > 0 ? item.rate.toStringAsFixed(2) : '';
      _quickAmtCtrl.text = item.calculatedAmount > 0
          ? item.calculatedAmount.toStringAsFixed(2)
          : '';
      _noticeMsg = "Editing Stone #${index + 1}";
    });
    _quickWtFocus.requestFocus();
  }

  void _editDiamondItem(int index) {
    final item = _diamonds[index];
    setState(() {
      _isEditing = true;
      _editingIsDiamond = true;
      _editingIndex = index;

      _quickProductId = item.diamondProductId;
      _quickSubProductId = item.diamondSubProductId;
      _quickUnit = item.diamondUnit.toUpperCase() == 'G' ? 'G' : 'C';
      _quickPcsCtrl.text = item.pcs.toString();
      _quickWtCtrl.text = item.weight > 0 ? item.weight.toStringAsFixed(3) : '';
      _quickRateCtrl.text = item.rate > 0 ? item.rate.toStringAsFixed(2) : '';
      _quickAmtCtrl.text = item.calculatedAmount > 0
          ? item.calculatedAmount.toStringAsFixed(2)
          : '';
      _noticeMsg = "Editing Diamond #${index + 1}";
    });
    _quickWtFocus.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editingIndex = null;
      _quickPcsCtrl.text = '1';
      _quickWtCtrl.clear();
      _quickRateCtrl.clear();
      _quickAmtCtrl.clear();
      _noticeMsg = null;
    });
    _quickProdFocus.requestFocus();
  }

  void _deleteStoneItem(int index) {
    setState(() {
      _stones.removeAt(index);
      if (_isEditing && !_editingIsDiamond && _editingIndex == index) {
        _cancelEdit();
      }
    });
  }

  void _deleteDiamondItem(int index) {
    setState(() {
      _diamonds.removeAt(index);
      if (_isEditing && _editingIsDiamond && _editingIndex == index) {
        _cancelEdit();
      }
    });
  }

  void _showModalError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  InputDecoration _modalInputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
      ),
    );
  }

  Widget _buildStatPill(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isLarge = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isLarge ? 18 : 15, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isLarge ? 13 : 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grsWt = widget.grossWeight;

    // Compute stones sums
    final stonePcs = _stones.fold<int>(0, (sum, i) => sum + i.pcs);
    final stoneWtGrams = _stones.fold<double>(
      0.0,
      (sum, i) => sum + i.weightInGrams,
    );
    final stoneTotalCost = _stones.fold<double>(
      0.0,
      (sum, i) => sum + i.calculatedAmount,
    );

    // Compute diamonds sums
    final diaPcs = _diamonds.fold<int>(0, (sum, i) => sum + i.pcs);
    final diaWtGrams = _diamonds.fold<double>(
      0.0,
      (sum, i) => sum + i.weightInGrams,
    );
    final diaTotalCarats = _diamonds.fold<double>(
      0.0,
      (sum, i) =>
          sum +
          (i.diamondUnit.toUpperCase() == 'C' ? i.weight : (i.weight * 5.0)),
    );
    final diaTotalCost = _diamonds.fold<double>(
      0.0,
      (sum, i) => sum + i.calculatedAmount,
    );

    final totalLessGrams = stoneWtGrams + diaWtGrams;
    final calculatedNet = (grsWt - totalLessGrams).clamp(0.0, 999999.0);
    final combinedPurchaseCost = stoneTotalCost + diaTotalCost;
    final totalRowsCount = _stones.length + _diamonds.length;

    final matchingSubs = widget.allSubProducts.where((sp) {
      if (_quickProductId == null) return true;
      return sp.productid == _quickProductId;
    }).toList();

    // Auto-focus on Product Dropdown when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_quickProdFocus.canRequestFocus &&
          !_quickProdFocus.hasFocus &&
          !_quickSubProdFocus.hasFocus &&
          !_quickUnitFocus.hasFocus &&
          !_quickPcsFocus.hasFocus &&
          !_quickWtFocus.hasFocus &&
          !_quickRateFocus.hasFocus &&
          !_quickAmtFocus.hasFocus &&
          !_isEditing) {
        _quickProdFocus.requestFocus();
      }
    });

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 780),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF059669,
                          ).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.diamond_rounded,
                          color: Color(0xFF34D399),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Lot Stones & Diamonds Entry (Single Window)",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Select Stone (S) or Diamond (D) in a single dropdown. Press Enter to navigate through fields and add to grid.",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: "Close Window",
                  ),
                ],
              ),
            ),

            // Live Stat Pills Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildStatPill(
                    "GROSS WT",
                    "${grsWt.toStringAsFixed(3)} g",
                    const Color(0xFFD97706),
                    Icons.scale_rounded,
                  ),
                  _buildStatPill(
                    "STONES LESS WT",
                    "${stoneWtGrams.toStringAsFixed(3)} g ($stonePcs pcs)",
                    const Color(0xFF059669),
                    Icons.grain_rounded,
                  ),
                  _buildStatPill(
                    "DIAMONDS LESS WT",
                    "${diaWtGrams.toStringAsFixed(3)} g (${diaTotalCarats.toStringAsFixed(2)} ct / $diaPcs pcs)",
                    const Color(0xFF0284C7),
                    Icons.diamond_rounded,
                  ),
                  _buildStatPill(
                    "NET GOLD WT",
                    "${calculatedNet.toStringAsFixed(3)} g",
                    const Color(0xFF4F46E5),
                    Icons.fitness_center_rounded,
                    isLarge: true,
                  ),
                  _buildStatPill(
                    "TOTAL PUR COST",
                    "₹${combinedPurchaseCost.toStringAsFixed(2)}",
                    const Color(0xFF10B981),
                    Icons.currency_rupee_rounded,
                    isLarge: true,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Single Quick Entry Form & Unified Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // SINGLE QUICK ENTRY BAR
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isEditing
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isEditing
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFCBD5E1),
                          width: _isEditing ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isEditing
                                    ? Icons.edit_note_rounded
                                    : Icons.playlist_add_rounded,
                                size: 18,
                                color: _isEditing
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isEditing
                                    ? "Edit Item Row (${_editingIsDiamond ? 'Diamond' : 'Stone'})"
                                    : "Add Stone / Diamond Item",
                                style: TextStyle(
                                  color: _isEditing
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF0284C7,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "Enter-Key Fast Navigation",
                                  style: TextStyle(
                                    color: Color(0xFF0284C7),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (_noticeMsg != null)
                                Text(
                                  _noticeMsg!,
                                  style: TextStyle(
                                    color: _noticeMsg!.startsWith('✓')
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFB45309),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Controls Row
                          Row(
                            children: [
                              // 1. Unified Product Selector (Stone & Diamond)
                              Expanded(
                                flex: 4,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _quickProductId,
                                  focusNode: _quickProdFocus,
                                  isExpanded: true,
                                  decoration: _modalInputDecoration(
                                    'Item / Product (D/S) *',
                                  ),
                                  items: _combinedProducts.map((p) {
                                    final isDia = _isDiamondProduct(p);
                                    final isStn = _isStoneProduct(p);
                                    final prefix = isDia
                                        ? '✨ [Dia]'
                                        : (isStn ? '💎 [Stn]' : '[Item]');
                                    return DropdownMenuItem<int?>(
                                      value: p.productid,
                                      child: Text(
                                        "$prefix ${p.productname}",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isDia
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isDia
                                              ? const Color(0xFF0284C7)
                                              : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _quickProductId = val;
                                      if (val != null) {
                                        final match = _combinedProducts
                                            .where((p) => p.productid == val)
                                            .toList();
                                        if (match.isNotEmpty) {
                                          _quickUnit =
                                              _isDiamondProduct(match.first)
                                              ? 'C'
                                              : 'G';
                                        }
                                      }
                                      _quickSubProductId = null;
                                    });
                                    _quickSubProdFocus.requestFocus();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 2. Sub-Product Selector
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _quickSubProductId,
                                  focusNode: _quickSubProdFocus,
                                  isExpanded: true,
                                  decoration: _modalInputDecoration(
                                    'Sub-Product (Optional)',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        "None / Default",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    ...matchingSubs.map(
                                      (sp) => DropdownMenuItem<int?>(
                                        value: sp.subproductid,
                                        child: Text(
                                          sp.subproductname,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _quickSubProductId = val);
                                    _quickUnitFocus.requestFocus();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 3. Unit Selector
                              SizedBox(
                                width: 95,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _quickUnit,
                                  focusNode: _quickUnitFocus,
                                  decoration: _modalInputDecoration('Unit'),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'G',
                                      child: Text(
                                        'Gram (G)',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'C',
                                      child: Text(
                                        'Carat (C)',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _quickUnit = val ?? 'G');
                                    _quickPcsFocus.requestFocus();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 4. Pieces (Pcs)
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  controller: _quickPcsCtrl,
                                  focusNode: _quickPcsFocus,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      _quickWtFocus.requestFocus(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: _modalInputDecoration('Pcs *'),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 5. Weight / Carats
                              SizedBox(
                                width: 95,
                                child: TextFormField(
                                  controller: _quickWtCtrl,
                                  focusNode: _quickWtFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => _onWeightOrRateChanged(),
                                  onFieldSubmitted: (_) =>
                                      _quickRateFocus.requestFocus(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: _modalInputDecoration(
                                    'Weight *',
                                    hint: '0.000',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 6. Purchase Rate
                              SizedBox(
                                width: 95,
                                child: TextFormField(
                                  controller: _quickRateCtrl,
                                  focusNode: _quickRateFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => _onWeightOrRateChanged(),
                                  onFieldSubmitted: (_) =>
                                      _quickAmtFocus.requestFocus(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: _modalInputDecoration(
                                    'Pur Rate ₹',
                                    hint: '0.00',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // 7. Amount
                              SizedBox(
                                width: 105,
                                child: TextFormField(
                                  controller: _quickAmtCtrl,
                                  focusNode: _quickAmtFocus,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _addOrUpdateItem(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                  decoration: _modalInputDecoration(
                                    'Amount ₹',
                                    hint: '0.00',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Action Button
                              ElevatedButton.icon(
                                focusNode: _quickAddFocus,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isEditing
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  _isEditing
                                      ? Icons.check_circle
                                      : Icons.add_circle,
                                  size: 16,
                                ),
                                label: Text(
                                  _isEditing ? "Update" : "Add",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _addOrUpdateItem,
                              ),
                              if (_isEditing) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: "Cancel Edit",
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF64748B),
                                    size: 18,
                                  ),
                                  onPressed: _cancelEdit,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // UNIFIED DATA GRID TABLE
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: totalRowsCount == 0
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.diamond_outlined,
                                      size: 42,
                                      color: const Color(
                                        0xFF94A3B8,
                                      ).withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "No Stone or Diamond items added yet.",
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Select a product in the entry bar above and press Enter to add items.",
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFFF1F5F9),
                                      ),
                                      dataRowMinHeight: 38,
                                      dataRowMaxHeight: 44,
                                      horizontalMargin: 14,
                                      columnSpacing: 16,
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            "#",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Type",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Product Name",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Sub-Product",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Unit",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Pcs",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Weight",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Less Wt (g)",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Rate (₹)",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Total Amount (₹)",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            "Actions",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: [
                                        // Stones Rows
                                        ..._stones.asMap().entries.map((entry) {
                                          final idx = entry.key;
                                          final item = entry.value;
                                          return DataRow(
                                            color:
                                                WidgetStateProperty.resolveWith<
                                                  Color?
                                                >((states) {
                                                  if (_isEditing &&
                                                      !_editingIsDiamond &&
                                                      _editingIndex == idx) {
                                                    return const Color(
                                                      0xFFFEF3C7,
                                                    );
                                                  }
                                                  return null;
                                                }),
                                            cells: [
                                              DataCell(
                                                Text(
                                                  "${idx + 1}",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF059669,
                                                    ).withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    "💎 Stone",
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF059669),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.stoneProductName ??
                                                      "Stone",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.stoneSubProductName ??
                                                      "-",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF1F5F9,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    item.stoneUnit
                                                                .toUpperCase() ==
                                                            'C'
                                                        ? "Carat (C)"
                                                        : "Gram (G)",
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "${item.pcs}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "${item.weight.toStringAsFixed(3)} ${item.stoneUnit}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "${item.weightInGrams.toStringAsFixed(3)} g",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.rate > 0
                                                      ? "₹${item.rate.toStringAsFixed(2)}"
                                                      : "-",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "₹${item.calculatedAmount.toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF059669),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Focus(
                                                  canRequestFocus: false,
                                                  skipTraversal: true,
                                                  descendantsAreFocusable:
                                                      false,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF0284C7,
                                                          ),
                                                        ),
                                                        tooltip: "Edit Stone",
                                                        onPressed: () =>
                                                            _editStoneItem(idx),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          size: 16,
                                                          color: Color(
                                                            0xFFEF4444,
                                                          ),
                                                        ),
                                                        tooltip: "Remove Stone",
                                                        onPressed: () =>
                                                            _deleteStoneItem(
                                                              idx,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),

                                        // Diamonds Rows
                                        ..._diamonds.asMap().entries.map((
                                          entry,
                                        ) {
                                          final idx = entry.key;
                                          final item = entry.value;
                                          return DataRow(
                                            color:
                                                WidgetStateProperty.resolveWith<
                                                  Color?
                                                >((states) {
                                                  if (_isEditing &&
                                                      _editingIsDiamond &&
                                                      _editingIndex == idx) {
                                                    return const Color(
                                                      0xFFFEF3C7,
                                                    );
                                                  }
                                                  return null;
                                                }),
                                            cells: [
                                              DataCell(
                                                Text(
                                                  "${_stones.length + idx + 1}",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF0284C7,
                                                    ).withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    "✨ Diamond",
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF0284C7),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.diamondProductName ??
                                                      "Diamond",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.diamondSubProductName ??
                                                      "-",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF1F5F9,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    item.diamondUnit
                                                                .toUpperCase() ==
                                                            'G'
                                                        ? "Gram (G)"
                                                        : "Carat (C)",
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "${item.pcs}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "${item.weight.toStringAsFixed(3)} ${item.diamondUnit}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "${item.weightInGrams.toStringAsFixed(3)} g",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  item.rate > 0
                                                      ? "₹${item.rate.toStringAsFixed(2)}"
                                                      : "-",
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  "₹${item.calculatedAmount.toStringAsFixed(2)}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0284C7),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Focus(
                                                  canRequestFocus: false,
                                                  skipTraversal: true,
                                                  descendantsAreFocusable:
                                                      false,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF0284C7,
                                                          ),
                                                        ),
                                                        tooltip: "Edit Diamond",
                                                        onPressed: () =>
                                                            _editDiamondItem(
                                                              idx,
                                                            ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .delete_outline_rounded,
                                                          size: 16,
                                                          color: Color(
                                                            0xFFEF4444,
                                                          ),
                                                        ),
                                                        tooltip:
                                                            "Remove Diamond",
                                                        onPressed: () =>
                                                            _deleteDiamondItem(
                                                              idx,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total: ${_stones.length} Stone item(s), ${_diamonds.length} Diamond item(s) configured",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _stones.clear();
                            _diamonds.clear();
                            _cancelEdit();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Clear All"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, {
                            'stones': _stones,
                            'diamonds': _diamonds,
                          });
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 17),
                        label: const Text(
                          "Apply & Calculate Net Weight (Enter)",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlassTheme.primaryNeon,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

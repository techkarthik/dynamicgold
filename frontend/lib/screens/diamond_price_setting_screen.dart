import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/branch_model.dart';
import '../models/inventory_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class DiamondPriceSettingScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DiamondPriceSettingScreen({super.key, this.onBack});

  @override
  State<DiamondPriceSettingScreen> createState() =>
      _DiamondPriceSettingScreenState();
}

class _DiamondPriceSettingScreenState extends State<DiamondPriceSettingScreen> {
  final ApiService _api = ApiService();

  List<DiamondPriceSettingRecord> _diamondPriceSettings = [];
  List<DiamondPriceSettingRecord> _filteredDiamondPriceSettings = [];
  List<ProductRecord> _allDiamondProducts = [];
  List<SubProductRecord> _allSubProducts = [];
  List<Map<String, dynamic>> _allDealers = [];
  List<Branch> _allBranches = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _showForm = false;
  bool _isTableView = true;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterBranchId = 'ALL';
  int? _filterProductId;
  String? _filterDealerAccode;

  // Form State
  final _formKey = GlobalKey<FormState>();
  DiamondPriceSettingRecord? _editingRecord;

  String _selectedBranchId = ''; // '' means ALL BRANCHES / GLOBAL
  int? _selectedProductId;
  int? _selectedSubProductId;
  String? _selectedDealerAccode;

  final TextEditingController _fromCentController = TextEditingController();
  final TextEditingController _toCentController = TextEditingController();
  final TextEditingController _centRateController = TextEditingController();

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
    _fromCentController.dispose();
    _toCentController.dispose();
    _centRateController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getDiamondPriceSettingsData(
          token,
          companyId: auth.activeCompanyId,
        ),
        _api.getDiamondProducts(token),
        _api.getSubProducts(token),
        _api.getPriceSettingDealers(token),
        _api.getBranches(token, companyId: auth.activeCompanyId),
      ]);

      if (mounted) {
        final dpsData = results[0] as Map<String, dynamic>;
        final products = results[1] as List<ProductRecord>;
        final subProducts = results[2] as List<SubProductRecord>;
        final dealers = results[3] as List<Map<String, dynamic>>;
        final branches = results[4] as List<Branch>;

        setState(() {
          _diamondPriceSettings =
              dpsData['diamond_price_settings']
                  as List<DiamondPriceSettingRecord>? ??
              [];
          _allDiamondProducts = products;
          _allSubProducts = subProducts;
          _allDealers = dealers;
          _allBranches = branches;

          if ((_selectedProductId == null ||
                  !_allDiamondProducts.any(
                    (p) => p.productid == _selectedProductId,
                  )) &&
              _allDiamondProducts.isNotEmpty) {
            _selectedProductId = _allDiamondProducts.first.productid;
          }

          if ((_selectedDealerAccode == null ||
                  !_allDealers.any(
                    (d) => d['accode'] == _selectedDealerAccode,
                  )) &&
              _allDealers.isNotEmpty) {
            _selectedDealerAccode = _allDealers.first['accode']?.toString();
          }

          _applyFilter();
          if (_showForm && _editingRecord == null) {
            _autoCalculateNextWeightRange();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading diamond price settings: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final activeComp = auth.activeCompanyId.trim().toUpperCase();
    final q = _searchQuery.trim().toLowerCase();

    _filteredDiamondPriceSettings = _diamondPriceSettings.where((dps) {
      if (activeComp.isNotEmpty) {
        final dpsComp = (dps.companyid ?? '').trim().toUpperCase();
        if (dpsComp.isNotEmpty && dpsComp != activeComp) return false;
      }

      final matchesBranch =
          _filterBranchId == 'ALL' ||
          (dps.branchid ?? '').toUpperCase() == _filterBranchId.toUpperCase();
      final matchesProduct =
          _filterProductId == null || dps.productid == _filterProductId;
      final matchesDealer =
          _filterDealerAccode == null || dps.accode == _filterDealerAccode;
      if (!matchesBranch || !matchesProduct || !matchesDealer) return false;

      if (q.isEmpty) return true;

      return (dps.productname ?? '').toLowerCase().contains(q) ||
          (dps.subproductname ?? '').toLowerCase().contains(q) ||
          (dps.dealername ?? '').toLowerCase().contains(q) ||
          (dps.accounttype ?? '').toLowerCase().contains(q) ||
          (dps.branchname ?? '').toLowerCase().contains(q) ||
          (dps.branchid ?? '').toLowerCase().contains(q) ||
          dps.accode.toLowerCase().contains(q) ||
          dps.fromCent.toString().contains(q) ||
          dps.toCent.toString().contains(q) ||
          dps.centRate.toString().contains(q);
    }).toList();
  }

  List<SubProductRecord> _getAvailableSubProducts(int? prodId) {
    if (prodId == null) return [];
    return _allSubProducts.where((sp) => sp.productid == prodId).toList();
  }

  void _autoCalculateNextWeightRange({bool force = false}) {
    if (_editingRecord != null && !force) return;
    if (_selectedProductId == null || _selectedDealerAccode == null) {
      _fromCentController.text = '0.000';
      _toCentController.text = '10.000';
      return;
    }

    final matching = _diamondPriceSettings.where((dps) {
      final dpsBranch = (dps.branchid ?? '').toUpperCase();
      final selBranch = _selectedBranchId.toUpperCase();
      if (dpsBranch != selBranch) return false;
      if (dps.productid != _selectedProductId) return false;
      if (dps.accode != _selectedDealerAccode) return false;

      final dpsSub = (dps.subproductid == null || dps.subproductid == 0)
          ? null
          : dps.subproductid;
      final selSub =
          (_selectedSubProductId == null || _selectedSubProductId == 0)
          ? null
          : _selectedSubProductId;
      if (dpsSub != selSub) return false;

      if (_editingRecord != null && dps.id == _editingRecord!.id) return false;

      return true;
    }).toList();

    if (matching.isNotEmpty) {
      double maxTo = matching.first.toCent;
      for (final dps in matching) {
        if (dps.toCent > maxTo) {
          maxTo = dps.toCent;
        }
      }

      final nextFrom = maxTo + 0.001;
      final nextTo = maxTo + 10.000;

      setState(() {
        _fromCentController.text = nextFrom.toStringAsFixed(3);
        _toCentController.text = nextTo.toStringAsFixed(3);
      });
    } else {
      setState(() {
        _fromCentController.text = '0.000';
        _toCentController.text = '10.000';
      });
    }
  }

  String _getWeightRangeHelperText() {
    if (_selectedProductId == null || _selectedDealerAccode == null) return '';
    final matching = _diamondPriceSettings.where((dps) {
      final dpsBranch = (dps.branchid ?? '').toUpperCase();
      final selBranch = _selectedBranchId.toUpperCase();
      if (dpsBranch != selBranch) return false;
      if (dps.productid != _selectedProductId) return false;
      if (dps.accode != _selectedDealerAccode) return false;
      final dpsSub = (dps.subproductid == null || dps.subproductid == 0)
          ? null
          : dps.subproductid;
      final selSub =
          (_selectedSubProductId == null || _selectedSubProductId == 0)
          ? null
          : _selectedSubProductId;
      return dpsSub == selSub;
    }).toList();

    final foundBranch = _allBranches
        .where(
          (b) => b.branchId.toUpperCase() == _selectedBranchId.toUpperCase(),
        )
        .firstOrNull;
    final branchName = _selectedBranchId.isEmpty
        ? "Global / All Branches"
        : (foundBranch?.branchName ?? _selectedBranchId);

    if (matching.isNotEmpty) {
      matching.sort((a, b) => a.fromCent.compareTo(b.fromCent));
      final ranges = matching
          .map(
            (m) =>
                "${m.fromCent.toStringAsFixed(3)}c - ${m.toCent.toStringAsFixed(3)}c (@ ₹${m.centRate.toStringAsFixed(2)})",
          )
          .join(", ");
      double maxTo = matching.first.toCent;
      for (final m in matching) {
        if (m.toCent > maxTo) maxTo = m.toCent;
      }
      return "[$branchName] Existing range(s): $ranges. Next cent weight starts automatically at ${(maxTo + 0.001).toStringAsFixed(3)} cents.";
    } else {
      return "[$branchName] No prior cent ranges found for this combination. New range starts from 0.000 cents.";
    }
  }

  void _openForm([DiamondPriceSettingRecord? existing]) {
    setState(() {
      _editingRecord = existing;
      _showForm = true;

      if (existing != null) {
        _selectedBranchId = existing.branchid ?? '';
        _selectedProductId = existing.productid;
        _selectedSubProductId = existing.subproductid;
        _selectedDealerAccode = existing.accode;
        _fromCentController.text = existing.fromCent.toStringAsFixed(3);
        _toCentController.text = existing.toCent.toStringAsFixed(3);
        _centRateController.text = existing.centRate > 0
            ? existing.centRate.toStringAsFixed(2)
            : '';
      } else {
        _selectedBranchId = '';
        if (_allDiamondProducts.isNotEmpty) {
          _selectedProductId = _allDiamondProducts.first.productid;
        }
        _selectedSubProductId = null;
        if (_allDealers.isNotEmpty) {
          _selectedDealerAccode = _allDealers.first['accode']?.toString();
        }
        _centRateController.text = '';
        _autoCalculateNextWeightRange(force: true);
      }
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingRecord = null;
    });
  }

  Future<void> _saveDiamondPriceSettingForm() async {
    if (!_formKey.currentState!.validate()) return;

    final fCent = double.tryParse(_fromCentController.text.trim());
    final tCent = double.tryParse(_toCentController.text.trim());
    final cRate = double.tryParse(_centRateController.text.trim());

    if (fCent == null || tCent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid numeric Cent Weights."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    if (fCent < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("From Cent Weight cannot be negative."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    if (tCent <= fCent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "To Cent Weight must be strictly greater than From Cent Weight.",
          ),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    if (cRate == null || cRate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter a valid non-negative Cent Rate (₹/cent).",
          ),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Diamond/Stone Product."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    if (_selectedDealerAccode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Dealer or Smith."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expired. Please log in again."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final record = DiamondPriceSettingRecord(
      id: _editingRecord?.id,
      companyid: auth.activeCompanyId,
      branchid: _selectedBranchId,
      productid: _selectedProductId!,
      subproductid: _selectedSubProductId,
      accode: _selectedDealerAccode!,
      fromCent: fCent,
      toCent: tCent,
      centRate: cRate,
    );

    try {
      final Map<String, dynamic> res;
      if (_editingRecord == null) {
        res = await _api.createDiamondPriceSetting(token, record);
      } else {
        res = await _api.updateDiamondPriceSetting(
          token,
          _editingRecord!.id!,
          record,
        );
      }

      if (mounted) {
        setState(() => _isSaving = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message'] ??
                    (_editingRecord == null
                        ? "Diamond Price Setting saved successfully!"
                        : "Diamond Price Setting updated successfully!"),
              ),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
          _closeForm();
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? "Operation failed."),
              backgroundColor: GlassTheme.accentRose,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  Future<void> _deleteDiamondPriceSetting(
    DiamondPriceSettingRecord record,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose),
            SizedBox(width: 8),
            Text("Delete Diamond Price Setting"),
          ],
        ),
        content: Text(
          "Are you sure you want to delete Diamond Price Setting rule for '${record.productname ?? 'Product'}' (${record.fromCent.toStringAsFixed(3)}c - ${record.toCent.toStringAsFixed(3)}c @ ₹${record.centRate.toStringAsFixed(2)}/cent) linked to '${record.dealername ?? record.accode}'?",
          style: const TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    try {
      final res = await _api.deleteDiamondPriceSetting(token, record.id!);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Diamond Price Setting deleted successfully!"),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? "Failed to delete."),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Bar
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // Summary Metric Cards
        _buildSummaryStats(),
        const SizedBox(height: 18),

        // In-page Entry Form
        if (_showForm) ...[_buildInPageEntryForm(), const SizedBox(height: 20)],

        // Search & Filter Toolbar
        _buildSearchToolbar(),
        const SizedBox(height: 18),

        // Main Content Area
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF0284C7)),
            ),
          )
        else if (_filteredDiamondPriceSettings.isEmpty)
          _buildEmptyState()
        else if (_isTableView)
          _buildTableView()
        else
          _buildCardsGridView(),

        const SizedBox(height: 40),
      ],
    );
  }

  // ================= HEADER BAR =================
  Widget _buildHeaderBar(
    BuildContext context,
    AuthProvider auth,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: GlassTheme.textPrimary,
                      ),
                      tooltip: "Back to Inventory Master",
                      onPressed: widget.onBack,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.diamond_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                              "Diamond Price Setting",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: GlassTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const StatusBadge(
                              label: "Inventory Master #9",
                              color: Color(0xFF0284C7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Configure weight ranges & cent rates for diamond/stone products",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow) ...[
                    // View Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.grid_view_rounded,
                              size: 20,
                              color: !_isTableView
                                  ? const Color(0xFF0284C7)
                                  : Colors.grey,
                            ),
                            tooltip: "Grid View",
                            onPressed: () =>
                                setState(() => _isTableView = false),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.table_chart_rounded,
                              size: 20,
                              color: _isTableView
                                  ? const Color(0xFF0284C7)
                                  : Colors.grey,
                            ),
                            tooltip: "Table View",
                            onPressed: () =>
                                setState(() => _isTableView = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showForm
                            ? Colors.grey.shade700
                            : const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      icon: Icon(
                        _showForm ? Icons.close_rounded : Icons.add_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _showForm ? "Close Form" : "Add Diamond Rate",
                      ),
                      onPressed: () {
                        if (_showForm) {
                          _closeForm();
                        } else {
                          _openForm();
                        }
                      },
                    ),
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.grid_view_rounded,
                              size: 20,
                              color: !_isTableView
                                  ? const Color(0xFF0284C7)
                                  : Colors.grey,
                            ),
                            tooltip: "Grid View",
                            onPressed: () =>
                                setState(() => _isTableView = false),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.table_chart_rounded,
                              size: 20,
                              color: _isTableView
                                  ? const Color(0xFF0284C7)
                                  : Colors.grey,
                            ),
                            tooltip: "Table View",
                            onPressed: () =>
                                setState(() => _isTableView = true),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showForm
                            ? Colors.grey.shade700
                            : const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      icon: Icon(
                        _showForm ? Icons.close_rounded : Icons.add_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _showForm ? "Close Form" : "Add Diamond Rate",
                      ),
                      onPressed: () {
                        if (_showForm) {
                          _closeForm();
                        } else {
                          _openForm();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ================= SUMMARY METRIC CARDS =================
  Widget _buildSummaryStats() {
    final totalRules = _diamondPriceSettings.length;
    final uniqueProducts = _diamondPriceSettings
        .map((s) => s.productid)
        .toSet()
        .length;
    final uniqueDealers = _diamondPriceSettings
        .map((s) => s.accode)
        .toSet()
        .length;
    final avgCentRate = totalRules > 0
        ? (_diamondPriceSettings.fold<double>(
                0.0,
                (acc, s) => acc + s.centRate,
              ) /
              totalRules)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              "Total Diamond Rates",
              totalRules.toString(),
              Icons.receipt_long_rounded,
              const Color(0xFF0284C7),
              cardWidth,
            ),
            _buildStatCard(
              "Active Products",
              uniqueProducts.toString(),
              Icons.diamond_rounded,
              const Color(0xFF0EA5E9),
              cardWidth,
            ),
            _buildStatCard(
              "Dealers / Smiths",
              uniqueDealers.toString(),
              Icons.storefront_rounded,
              const Color(0xFF10B981),
              cardWidth,
            ),
            _buildStatCard(
              "Avg Cent Rate",
              "₹${avgCentRate.toStringAsFixed(2)}",
              Icons.monetization_on_rounded,
              const Color(0xFFF59E0B),
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GlassTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= IN-PAGE ENTRY FORM =================
  Widget _buildInPageEntryForm() {
    final availableSubProducts = _getAvailableSubProducts(_selectedProductId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Title Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _editingRecord == null
                      ? "Add New Diamond Price Setting"
                      : "Edit Diamond Price Setting (ID: ${_editingRecord!.id})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GlassTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: GlassTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: _closeForm,
                ),
              ],
            ),
            const Divider(color: Color(0xFFF1F5F9), height: 24),

            // Row 1: Branch, Product, Sub-Product, Dealer
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // Branch Dropdown
                SizedBox(
                  width: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Branch",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedBranchId,
                        decoration: _inputDecoration("Select Branch"),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              "Global / All Branches",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ..._allBranches.map(
                            (b) => DropdownMenuItem<String>(
                              value: b.branchId,
                              child: Text(
                                "${b.branchId} - ${b.branchName}",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedBranchId = val ?? '';
                            _autoCalculateNextWeightRange();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Diamond Product Dropdown
                SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Diamond/Stone Product *",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _selectedProductId,
                        decoration: _inputDecoration("Select Product"),
                        items: _allDiamondProducts.map((p) {
                          final badge =
                              (p.diastone == 'D' || p.diastone == 'Diamond')
                              ? '[DIA]'
                              : '[STONE]';
                          return DropdownMenuItem<int>(
                            value: p.productid,
                            child: Text(
                              "$badge ${p.productname}",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProductId = val;
                            final subs = _getAvailableSubProducts(val);
                            if (_selectedSubProductId != null &&
                                !subs.any(
                                  (s) =>
                                      s.subproductid == _selectedSubProductId,
                                )) {
                              _selectedSubProductId = null;
                            }
                            _autoCalculateNextWeightRange();
                          });
                        },
                        validator: (v) =>
                            v == null ? "Product is required" : null,
                      ),
                    ],
                  ),
                ),

                // Sub-Product Dropdown
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sub-Item / Cut",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        isExpanded: true,
                        initialValue: _selectedSubProductId,
                        decoration: _inputDecoration("General / None"),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              "(None / General Cut)",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ...availableSubProducts.map(
                            (sp) => DropdownMenuItem<int?>(
                              value: sp.subproductid,
                              child: Text(
                                sp.subproductname,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedSubProductId = val;
                            _autoCalculateNextWeightRange();
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Dealer Dropdown
                SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Smith / Dealer *",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedDealerAccode,
                        decoration: _inputDecoration("Select Dealer/Smith"),
                        items: _allDealers.map((d) {
                          final accode = d['accode']?.toString() ?? '';
                          final accname =
                              d['accountname']?.toString() ?? accode;
                          final acctype =
                              d['accounttype']?.toString() ?? 'DEALER';
                          return DropdownMenuItem<String>(
                            value: accode,
                            child: Text(
                              "[$acctype] $accname ($accode)",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDealerAccode = val;
                            _autoCalculateNextWeightRange();
                          });
                        },
                        validator: (v) =>
                            v == null ? "Dealer is required" : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Continuous Weight Range Helper Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF0284C7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getWeightRangeHelperText(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Row 2: From Cent Weight, To Cent Weight, Cent Rate
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // From Cent Weight
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "From Cent *",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fromCentController,
                        decoration: _inputDecoration("0.000", suffixText: "c"),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,4}'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          if (double.tryParse(v.trim()) == null) {
                            return "Invalid";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // To Cent Weight
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "To Cent *",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _toCentController,
                        decoration: _inputDecoration("10.000", suffixText: "c"),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,4}'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          final to = double.tryParse(v.trim());
                          if (to == null) return "Invalid";
                          final from = double.tryParse(
                            _fromCentController.text.trim(),
                          );
                          if (from != null && to <= from) {
                            return "Must be > From";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // Cent Rate (₹/cent)
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Cent Rate (₹ / Cent) *",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _centRateController,
                        decoration: _inputDecoration("0.00", prefixText: "₹ "),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          if (double.tryParse(v.trim()) == null) {
                            return "Invalid rate";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
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
                  onPressed: _closeForm,
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text(
                    _isSaving
                        ? "Saving..."
                        : (_editingRecord == null
                              ? "Save Diamond Rate"
                              : "Update Diamond Rate"),
                  ),
                  onPressed: _isSaving ? null : _saveDiamondPriceSettingForm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= SEARCH & FILTER TOOLBAR =================
  Widget _buildSearchToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Box
          SizedBox(
            width: 250,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search diamond settings...",
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: GlassTheme.textSecondary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
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

          // Branch Filter Dropdown
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _filterBranchId,
              decoration: _inputDecoration("Branch Filter"),
              items: [
                const DropdownMenuItem(
                  value: 'ALL',
                  child: Text("All Branches", overflow: TextOverflow.ellipsis),
                ),
                const DropdownMenuItem(
                  value: '',
                  child: Text("Global Only", overflow: TextOverflow.ellipsis),
                ),
                ..._allBranches.map(
                  (b) => DropdownMenuItem(
                    value: b.branchId,
                    child: Text(b.branchName, overflow: TextOverflow.ellipsis),
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

          // Product Filter Dropdown
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _filterProductId,
              decoration: _inputDecoration("Product Filter"),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text("All Products", overflow: TextOverflow.ellipsis),
                ),
                ..._allDiamondProducts.map(
                  (p) => DropdownMenuItem(
                    value: p.productid,
                    child: Text(p.productname, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _filterProductId = val;
                  _applyFilter();
                });
              },
            ),
          ),

          // Dealer Filter Dropdown
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _filterDealerAccode,
              decoration: _inputDecoration("Dealer Filter"),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text("All Dealers", overflow: TextOverflow.ellipsis),
                ),
                ..._allDealers.map(
                  (d) => DropdownMenuItem(
                    value: d['accode']?.toString(),
                    child: Text(
                      d['accountname']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _filterDealerAccode = val;
                  _applyFilter();
                });
              },
            ),
          ),

          // Reset Filters Button
          if (_filterBranchId != 'ALL' ||
              _filterProductId != null ||
              _filterDealerAccode != null ||
              _searchQuery.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text("Reset"),
              onPressed: () {
                setState(() {
                  _filterBranchId = 'ALL';
                  _filterProductId = null;
                  _filterDealerAccode = null;
                  _searchController.clear();
                  _searchQuery = '';
                  _applyFilter();
                });
              },
            ),
        ],
      ),
    );
  }

  // ================= TABLE VIEW =================
  Widget _buildTableView() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMaxHeight: 58,
          columnSpacing: 20,
          columns: const [
            DataColumn(
              label: Text(
                "#",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Branch",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Diamond Product",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Sub-Item / Cut",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Dealer / Smith",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Cent Weight Range",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Cent Rate",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "Actions",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
          ],
          rows: _filteredDiamondPriceSettings.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final record = entry.value;

            final branchName =
                (record.branchid == null || record.branchid!.isEmpty)
                ? "Global"
                : (record.branchname?.isNotEmpty == true
                      ? record.branchname!
                      : record.branchid!);

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    idx.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (record.branchid == null || record.branchid!.isEmpty)
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      branchName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            (record.branchid == null ||
                                record.branchid!.isEmpty)
                            ? const Color(0xFF64748B)
                            : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diamond_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        record.productname ?? "Product #${record.productid}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    record.subproductname?.isNotEmpty == true
                        ? record.subproductname!
                        : "General Cut",
                    style: TextStyle(
                      fontSize: 12,
                      color: record.subproductname?.isNotEmpty == true
                          ? GlassTheme.textPrimary
                          : GlassTheme.textSecondary,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            record.dealername ?? record.accode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            record.accode,
                            style: const TextStyle(
                              fontSize: 10,
                              color: GlassTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: record.accounttype == 'SMITH'
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.accounttype ?? 'DEALER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: record.accounttype == 'SMITH'
                                ? const Color(0xFFB45309)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      "${record.fromCent.toStringAsFixed(3)} - ${record.toCent.toStringAsFixed(3)} Cents",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    "₹${record.centRate.toStringAsFixed(2)} / cent",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Color(0xFF0284C7),
                        ),
                        tooltip: "Edit Diamond Rate",
                        onPressed: () => _openForm(record),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: GlassTheme.accentRose,
                        ),
                        tooltip: "Delete Diamond Rate",
                        onPressed: () => _deleteDiamondPriceSetting(record),
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

  // ================= CARDS GRID VIEW =================
  Widget _buildCardsGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 700
            ? 1
            : (constraints.maxWidth < 1100 ? 2 : 3);
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _filteredDiamondPriceSettings.map((record) {
            final branchName =
                (record.branchid == null || record.branchid!.isEmpty)
                ? "Global / All Branches"
                : (record.branchname?.isNotEmpty == true
                      ? record.branchname!
                      : record.branchid!);

            return Container(
              width: itemWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x040F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.diamond_rounded,
                          color: Color(0xFF0284C7),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.productname ??
                                  "Product #${record.productid}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: GlassTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              record.subproductname?.isNotEmpty == true
                                  ? record.subproductname!
                                  : "General Cut",
                              style: const TextStyle(
                                fontSize: 11,
                                color: GlassTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: Color(0xFF0284C7),
                        ),
                        onPressed: () => _openForm(record),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: GlassTheme.accentRose,
                        ),
                        onPressed: () => _deleteDiamondPriceSetting(record),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 20),

                  // Branch & Dealer
                  Row(
                    children: [
                      const Icon(
                        Icons.store_rounded,
                        size: 14,
                        color: GlassTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          branchName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: GlassTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: record.accounttype == 'SMITH'
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.accounttype ?? 'DEALER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: record.accounttype == 'SMITH'
                                ? const Color(0xFFB45309)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle_rounded,
                        size: 14,
                        color: GlassTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${record.dealername ?? record.accode} (${record.accode})",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weight Range & Rate Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Cent Range",
                              style: TextStyle(
                                fontSize: 10,
                                color: GlassTheme.textSecondary,
                              ),
                            ),
                            Text(
                              "${record.fromCent.toStringAsFixed(3)} - ${record.toCent.toStringAsFixed(3)}c",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "Cent Rate",
                              style: TextStyle(
                                fontSize: 10,
                                color: GlassTheme.textSecondary,
                              ),
                            ),
                            Text(
                              "₹${record.centRate.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 14,
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
            );
          }).toList(),
        );
      },
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.diamond_rounded,
              color: Color(0xFF0284C7),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Diamond Price Setting Rules Found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: GlassTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Configure weight ranges and cent rates for your diamond and stone products.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text("Create First Diamond Rate"),
            onPressed: () => _openForm(),
          ),
        ],
      ),
    );
  }

  // ================= INPUT DECORATION HELPERS =================
  InputDecoration _inputDecoration(
    String hintText, {
    String? suffixText,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      suffixText: suffixText,
      prefixText: prefixText,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/branch_model.dart';
import '../models/inventory_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class PriceSettingScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PriceSettingScreen({super.key, this.onBack});

  @override
  State<PriceSettingScreen> createState() => _PriceSettingScreenState();
}

class _PriceSettingScreenState extends State<PriceSettingScreen> {
  final ApiService _api = ApiService();

  List<PriceSettingRecord> _priceSettings = [];
  List<PriceSettingRecord> _filteredPriceSettings = [];
  List<ProductRecord> _allProducts = [];
  List<SubProductRecord> _allSubProducts = [];
  List<Map<String, dynamic>> _allDealers = [];
  List<Branch> _allBranches = [];

  bool _isLoading = false;
  String _searchQuery = '';
  String _filterBranchId = 'ALL';
  int? _filterProductId;
  String? _filterDealerAccode;
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  PriceSettingRecord? _editingRecord;
  final _formKey = GlobalKey<FormState>();

  String _selectedBranchId = '';
  int? _selectedProductId;
  int? _selectedSubProductId;
  String? _selectedDealerAccode;

  final TextEditingController _weightFromController = TextEditingController(
    text: '0.000',
  );
  final TextEditingController _weightToController = TextEditingController(
    text: '10.000',
  );
  final TextEditingController _vaPercentController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController _wastageController = TextEditingController(
    text: '0.000',
  );
  final TextEditingController _mcPerGramController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController _mChargeController = TextEditingController(
    text: '0.00',
  );

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightFromController.dispose();
    _weightToController.dispose();
    _vaPercentController.dispose();
    _wastageController.dispose();
    _mcPerGramController.dispose();
    _mChargeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getPriceSettingsData(token, companyId: auth.activeCompanyId),
        _api.getProducts(token),
        _api.getSubProducts(token),
        _api.getPriceSettingDealers(token),
        _api.getBranches(token, companyId: auth.activeCompanyId),
      ]);

      if (mounted) {
        final psData = results[0] as Map<String, dynamic>;
        final products = results[1] as List<ProductRecord>;
        final subProducts = results[2] as List<SubProductRecord>;
        final dealers = results[3] as List<Map<String, dynamic>>;
        final branches = results[4] as List<Branch>;

        setState(() {
          _priceSettings =
              psData['price_settings'] as List<PriceSettingRecord>? ?? [];
          _allProducts = products;
          _allSubProducts = subProducts;
          _allDealers = dealers;
          _allBranches = branches;

          if ((_selectedProductId == null ||
                  !_allProducts.any(
                    (p) => p.productid == _selectedProductId,
                  )) &&
              _allProducts.isNotEmpty) {
            _selectedProductId = _allProducts.first.productid;
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
            content: Text("Error loading price settings: $e"),
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

    _filteredPriceSettings = _priceSettings.where((ps) {
      if (activeComp.isNotEmpty) {
        final psComp = (ps.companyid ?? '').trim().toUpperCase();
        if (psComp.isNotEmpty && psComp != activeComp) return false;
      }

      final matchesBranch =
          _filterBranchId == 'ALL' ||
          (ps.branchid ?? '').toUpperCase() == _filterBranchId.toUpperCase();
      final matchesProduct =
          _filterProductId == null || ps.productid == _filterProductId;
      final matchesDealer =
          _filterDealerAccode == null || ps.accode == _filterDealerAccode;
      if (!matchesBranch || !matchesProduct || !matchesDealer) return false;

      if (q.isEmpty) return true;

      return (ps.productname ?? '').toLowerCase().contains(q) ||
          (ps.subproductname ?? '').toLowerCase().contains(q) ||
          (ps.dealername ?? '').toLowerCase().contains(q) ||
          (ps.accounttype ?? '').toLowerCase().contains(q) ||
          (ps.branchname ?? '').toLowerCase().contains(q) ||
          (ps.branchid ?? '').toLowerCase().contains(q) ||
          ps.accode.toLowerCase().contains(q) ||
          ps.weightFrom.toString().contains(q) ||
          ps.weightTo.toString().contains(q) ||
          ps.vaPercent.toString().contains(q) ||
          ps.wastage.toString().contains(q) ||
          ps.mcPerGram.toString().contains(q) ||
          ps.mCharge.toString().contains(q);
    }).toList();
  }

  List<SubProductRecord> _getAvailableSubProducts(int? prodId) {
    if (prodId == null) return [];
    return _allSubProducts.where((sp) => sp.productid == prodId).toList();
  }

  void _autoCalculateNextWeightRange({bool force = false}) {
    if (_editingRecord != null && !force) return;
    if (_selectedProductId == null || _selectedDealerAccode == null) {
      _weightFromController.text = '0.000';
      _weightToController.text = '10.000';
      return;
    }

    final matching = _priceSettings.where((ps) {
      final psBranch = (ps.branchid ?? '').toUpperCase();
      final selBranch = _selectedBranchId.toUpperCase();
      if (psBranch != selBranch) return false;
      if (ps.productid != _selectedProductId) return false;
      if (ps.accode != _selectedDealerAccode) return false;

      final psSub = (ps.subproductid == null || ps.subproductid == 0)
          ? null
          : ps.subproductid;
      final selSub =
          (_selectedSubProductId == null || _selectedSubProductId == 0)
          ? null
          : _selectedSubProductId;
      if (psSub != selSub) return false;

      if (_editingRecord != null && ps.id == _editingRecord!.id) return false;

      return true;
    }).toList();

    if (matching.isNotEmpty) {
      double maxTo = matching.first.weightTo;
      for (final ps in matching) {
        if (ps.weightTo > maxTo) {
          maxTo = ps.weightTo;
        }
      }

      final nextFrom = maxTo + 0.001;
      final nextTo = maxTo + 10.000;

      setState(() {
        _weightFromController.text = nextFrom.toStringAsFixed(3);
        _weightToController.text = nextTo.toStringAsFixed(3);
      });
    } else {
      setState(() {
        _weightFromController.text = '0.000';
        _weightToController.text = '10.000';
      });
    }
  }

  String _getWeightRangeHelperText() {
    if (_selectedProductId == null || _selectedDealerAccode == null) return '';
    final matching = _priceSettings.where((ps) {
      final psBranch = (ps.branchid ?? '').toUpperCase();
      final selBranch = _selectedBranchId.toUpperCase();
      if (psBranch != selBranch) return false;
      if (ps.productid != _selectedProductId) return false;
      if (ps.accode != _selectedDealerAccode) return false;
      final psSub = (ps.subproductid == null || ps.subproductid == 0)
          ? null
          : ps.subproductid;
      final selSub =
          (_selectedSubProductId == null || _selectedSubProductId == 0)
          ? null
          : _selectedSubProductId;
      return psSub == selSub;
    }).toList();

    final branchName = _selectedBranchId.isEmpty
        ? "Global / All Branches"
        : (_allBranches
                  .where(
                    (b) =>
                        b.branchId.toUpperCase() ==
                        _selectedBranchId.toUpperCase(),
                  )
                  .firstOrNull
                  ?.branchName ??
              _selectedBranchId);

    if (matching.isNotEmpty) {
      matching.sort((a, b) => a.weightFrom.compareTo(b.weightFrom));
      final ranges = matching
          .map(
            (m) =>
                "${m.weightFrom.toStringAsFixed(2)}g - ${m.weightTo.toStringAsFixed(2)}g",
          )
          .join(", ");
      double maxTo = matching.first.weightTo;
      for (final m in matching) {
        if (m.weightTo > maxTo) maxTo = m.weightTo;
      }
      return "[$branchName] Existing range(s): $ranges. Next weight starts automatically at ${(maxTo + 0.001).toStringAsFixed(3)}g.";
    } else {
      return "[$branchName] No prior ranges found for this combination. New weight range starts from 0.000g.";
    }
  }

  void _openForm([PriceSettingRecord? existing]) {
    setState(() {
      _editingRecord = existing;
      _showForm = true;
      if (existing != null) {
        _selectedBranchId = existing.branchid ?? '';
        _selectedProductId = existing.productid;
        _selectedSubProductId = existing.subproductid;
        _selectedDealerAccode = existing.accode;
        _weightFromController.text = existing.weightFrom.toStringAsFixed(3);
        _weightToController.text = existing.weightTo.toStringAsFixed(3);
        _vaPercentController.text = existing.vaPercent.toStringAsFixed(2);
        _wastageController.text = existing.wastage.toStringAsFixed(3);
        _mcPerGramController.text = existing.mcPerGram.toStringAsFixed(2);
        _mChargeController.text = existing.mCharge.toStringAsFixed(2);
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _selectedBranchId = '';
    _selectedProductId = _allProducts.isNotEmpty
        ? _allProducts.first.productid
        : null;
    _selectedSubProductId = null; // None / General by default
    _selectedDealerAccode = _allDealers.isNotEmpty
        ? _allDealers.first['accode']?.toString()
        : null;
    _vaPercentController.text = '0.00';
    _wastageController.text = '0.000';
    _mcPerGramController.text = '0.00';
    _mChargeController.text = '0.00';
    _autoCalculateNextWeightRange(force: true);
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingRecord = null;
      _resetFormFields();
    });
  }

  Future<void> _savePriceSettingForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Product."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    if (_selectedDealerAccode == null || _selectedDealerAccode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Dealer/Smith."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    final wFrom = double.tryParse(_weightFromController.text.trim()) ?? 0.0;
    final wTo = double.tryParse(_weightToController.text.trim()) ?? 0.0;

    if (wFrom < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Weight From cannot be negative."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    if (wTo <= wFrom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Weight To must be strictly greater than Weight From."),
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

    final record = PriceSettingRecord(
      id: _editingRecord?.id,
      companyid: auth.activeCompanyId,
      branchid: _selectedBranchId,
      productid: _selectedProductId!,
      subproductid: _selectedSubProductId,
      accode: _selectedDealerAccode!,
      weightFrom: wFrom,
      weightTo: wTo,
      vaPercent: double.tryParse(_vaPercentController.text.trim()) ?? 0.0,
      wastage: double.tryParse(_wastageController.text.trim()) ?? 0.0,
      mcPerGram: double.tryParse(_mcPerGramController.text.trim()) ?? 0.0,
      mCharge: double.tryParse(_mChargeController.text.trim()) ?? 0.0,
    );

    try {
      final Map<String, dynamic> res;
      if (_editingRecord == null) {
        res = await _api.createPriceSetting(token, record);
      } else {
        res = await _api.updatePriceSetting(token, _editingRecord!.id!, record);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message'] ??
                    (_editingRecord == null
                        ? "Price Setting saved successfully!"
                        : "Price Setting updated successfully!"),
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

  Future<void> _deletePriceSetting(PriceSettingRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose),
            SizedBox(width: 8),
            Text("Delete Price Setting"),
          ],
        ),
        content: Text(
          "Are you sure you want to delete Price Setting rule for '${record.productname ?? 'Product'}' (${record.weightFrom.toStringAsFixed(2)}g - ${record.weightTo.toStringAsFixed(2)}g) linked to '${record.dealername ?? record.accode}'?",
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
      final res = await _api.deletePriceSetting(token, record.id!);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Price Setting deleted successfully!"),
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
    final isMobile = MediaQuery.of(context).size.width < 700;

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
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          )
        else if (_filteredPriceSettings.isEmpty)
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: GlassTheme.textPrimary,
              ),
              tooltip: "Back to Item Master",
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 4),
          ],
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.price_change_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text(
                      "Price Setting",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: GlassTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    StatusBadge(
                      label: "Inventory Master #8",
                      color: Color(0xFF6366F1),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Configure weight-wise VA%, wastage & making charges linked to products and dealers",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
                        ? const Color(0xFF6366F1)
                        : Colors.grey,
                  ),
                  tooltip: "Grid View",
                  onPressed: () => setState(() => _isTableView = false),
                ),
                IconButton(
                  icon: Icon(
                    Icons.table_chart_rounded,
                    size: 20,
                    color: _isTableView ? const Color(0xFF6366F1) : Colors.grey,
                  ),
                  tooltip: "Table View",
                  onPressed: () => setState(() => _isTableView = true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Refresh Button
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: GlassTheme.textSecondary,
            ),
            tooltip: "Refresh Data",
            onPressed: _loadData,
          ),
          const SizedBox(width: 10),
          // New Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            icon: Icon(_showForm ? Icons.close : Icons.add_rounded, size: 18),
            label: Text(
              _showForm ? "Close Form" : "New Price Setting",
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
    );
  }

  // ================= SUMMARY METRICS =================
  Widget _buildSummaryStats() {
    final uniqueProducts = _priceSettings
        .map((p) => p.productid)
        .toSet()
        .length;
    final uniqueDealers = _priceSettings.map((p) => p.accode).toSet().length;
    final uniqueBranches = _priceSettings
        .map(
          (p) => (p.branchid == null || p.branchid!.isEmpty)
              ? 'GLOBAL'
              : p.branchid!.toUpperCase(),
        )
        .toSet()
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: "Total Price Rules",
            value: _priceSettings.length.toString(),
            icon: Icons.rule_folder_rounded,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: "Configured Products",
            value: uniqueProducts.toString(),
            icon: Icons.category_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: "Assigned Dealers / Smiths",
            value: uniqueDealers.toString(),
            icon: Icons.badge_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: "Active Branches",
            value: uniqueBranches.toString(),
            icon: Icons.store_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
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
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: GlassTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: GlassTheme.textPrimary,
                ),
              ),
            ],
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
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C6366F1),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _editingRecord == null
                        ? Icons.add_circle_outline_rounded
                        : Icons.edit_note_rounded,
                    color: const Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _editingRecord == null
                      ? "Add New Price Setting Rule"
                      : "Edit Price Setting Rule #${_editingRecord!.id}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: GlassTheme.textSecondary,
                  ),
                  onPressed: _closeForm,
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFE2E8F0)),
            // Row 1: Branch, Product, Sub-Product, Dealer
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 950;

                final branchField = Column(
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
                      initialValue:
                          _allBranches.any(
                            (b) =>
                                b.branchId.toUpperCase() ==
                                _selectedBranchId.toUpperCase(),
                          )
                          ? _selectedBranchId
                          : (_selectedBranchId.isEmpty ? '' : ''),
                      decoration: _inputDecoration("Select Branch"),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text(
                            "Global / All Branches",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ..._allBranches.map((b) {
                          return DropdownMenuItem<String>(
                            value: b.branchId,
                            child: Text(
                              "${b.branchId} - ${b.branchName}",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedBranchId = val ?? '';
                          _autoCalculateNextWeightRange();
                        });
                      },
                    ),
                  ],
                );

                final productField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Product Name *",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedProductId,
                      decoration: _inputDecoration("Select Product"),
                      items: _allProducts.map((p) {
                        return DropdownMenuItem<int>(
                          value: p.productid,
                          child: Text(
                            p.productname,
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
                                (s) => s.subproductid == _selectedSubProductId,
                              )) {
                            _selectedSubProductId = null;
                          }
                          _autoCalculateNextWeightRange();
                        });
                      },
                      validator: (val) =>
                          val == null ? "Product is required" : null,
                    ),
                  ],
                );

                final subProductField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sub-Product Name",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedSubProductId,
                      decoration: _inputDecoration("General / None"),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            "(None / Main Product Only)",
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                        ...availableSubProducts.map((sp) {
                          return DropdownMenuItem<int?>(
                            value: sp.subproductid,
                            child: Text(
                              sp.subproductname,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedSubProductId = val;
                          _autoCalculateNextWeightRange();
                        });
                      },
                    ),
                  ],
                );

                final dealerField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Dealer / Smith Name *",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDealerAccode,
                      decoration: _inputDecoration("Select Dealer / Smith"),
                      items: _allDealers.map((d) {
                        final name = d['accountname'] ?? d['accode'];
                        final type = d['accounttype'] ?? 'DEALER';
                        return DropdownMenuItem<String>(
                          value: d['accode']?.toString(),
                          child: Text(
                            "$name ($type)",
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
                      validator: (val) => (val == null || val.isEmpty)
                          ? "Dealer is required"
                          : null,
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: branchField),
                      const SizedBox(width: 14),
                      Expanded(child: productField),
                      const SizedBox(width: 14),
                      Expanded(child: subProductField),
                      const SizedBox(width: 14),
                      Expanded(child: dealerField),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: branchField),
                          const SizedBox(width: 14),
                          Expanded(child: productField),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: subProductField),
                          const SizedBox(width: 14),
                          Expanded(child: dealerField),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            // Helper info banner for weight range auto-continuation
            if (_editingRecord == null &&
                _selectedProductId != null &&
                _selectedDealerAccode != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getWeightRangeHelperText(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Row 2: Weight Range (From, To)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Weight Range From (g) *",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _weightFromController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration("e.g. 0.000", suffix: "g"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Weight From is required";
                          }
                          final v = double.tryParse(val.trim());
                          if (v == null || v < 0) return "Must be >= 0";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Weight Range To (g) *",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _weightToController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration(
                          "e.g. 10.000",
                          suffix: "g",
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Weight To is required";
                          }
                          final v = double.tryParse(val.trim());
                          final f =
                              double.tryParse(
                                _weightFromController.text.trim(),
                              ) ??
                              0.0;
                          if (v == null) return "Invalid number";
                          if (v <= f) return "Must be > Weight From ($f)";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Row 3: Pricing fields: VA%, Wastage, MC/g, Flat M.Charge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "VA Percent (%)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _vaPercentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration("0.00", suffix: "%"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Wastage (g / %)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _wastageController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration("0.000", suffix: "g"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "MC Per Gram (₹/g)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _mcPerGramController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration("0.00", prefix: "₹"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Flat M. Charge (₹)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _mChargeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration("0.00", prefix: "₹"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Actions
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
                  child: const Text(
                    "Cancel",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _isSaving
                        ? "Saving..."
                        : (_editingRecord == null
                              ? "Save Price Setting"
                              : "Update Price Setting"),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: _isSaving ? null : _savePriceSettingForm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    String? prefix,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix != null ? "$prefix " : null,
      suffixText: suffix != null ? " $suffix" : null,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }

  // ================= FILTER AND SEARCH TOOLBAR =================
  Widget _buildSearchToolbar() {
    return Row(
      children: [
        // Search Bar
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search by Product, Sub-product, Dealer, Branch...",
              prefixIcon: const Icon(
                Icons.search,
                color: GlassTheme.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilter();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
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
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilter();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        // Filter by Branch
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            initialValue: _filterBranchId,
            decoration: _filterDecoration("Branch"),
            items: [
              const DropdownMenuItem<String>(
                value: 'ALL',
                child: Text("All Branches", style: TextStyle(fontSize: 13)),
              ),
              const DropdownMenuItem<String>(
                value: '',
                child: Text(
                  "Global / All Only",
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ..._allBranches.map(
                (b) => DropdownMenuItem<String>(
                  value: b.branchId,
                  child: Text(
                    "${b.branchId} - ${b.branchName}",
                    style: const TextStyle(fontSize: 13),
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
        const SizedBox(width: 12),
        // Filter by Product
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<int?>(
            initialValue: _filterProductId,
            decoration: _filterDecoration("All Products"),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text("All Products", style: TextStyle(fontSize: 13)),
              ),
              ..._allProducts.map(
                (p) => DropdownMenuItem<int?>(
                  value: p.productid,
                  child: Text(
                    p.productname,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
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
        const SizedBox(width: 12),
        // Filter by Dealer
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String?>(
            initialValue: _filterDealerAccode,
            decoration: _filterDecoration("All Dealers"),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  "All Dealers / Smiths",
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ..._allDealers.map(
                (d) => DropdownMenuItem<String?>(
                  value: d['accode']?.toString(),
                  child: Text(
                    d['accountname'] ?? d['accode'],
                    style: const TextStyle(fontSize: 13),
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
      ],
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12,
        color: GlassTheme.textSecondary,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  // ================= CARD GRID VIEW =================
  Widget _buildCardsGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 3
            : (constraints.maxWidth > 700 ? 2 : 1);
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _filteredPriceSettings.map((ps) {
            return SizedBox(
              width: itemWidth,
              child: _buildPriceSettingCard(ps),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPriceSettingCard(PriceSettingRecord ps) {
    final isGlobal =
        (ps.branchid == null || ps.branchid!.isEmpty || ps.branchid == 'ALL');
    final branchText = isGlobal
        ? "Global / All"
        : (ps.branchname != null && ps.branchname!.isNotEmpty
              ? "${ps.branchid} - ${ps.branchname}"
              : ps.branchid!);

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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Product name & Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ps.productname ?? "Product #${ps.productid}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                    if (ps.subproductname != null &&
                        ps.subproductname!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 14,
                            color: Color(0xFFEC4899),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ps.subproductname!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEC4899),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Color(0xFF6366F1),
                    ),
                    tooltip: "Edit Rule",
                    onPressed: () => _openForm(ps),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: GlassTheme.accentRose,
                    ),
                    tooltip: "Delete Rule",
                    onPressed: () => _deletePriceSetting(ps),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Branch tag & Dealer tag & Weight range badge
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Branch Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGlobal
                      ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                      : const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGlobal ? Icons.public_rounded : Icons.store_rounded,
                      size: 12,
                      color: isGlobal
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      branchText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isGlobal
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              // Dealer Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 12,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ps.dealername ?? ps.accode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              // Weight Range Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${ps.weightFrom.toStringAsFixed(2)}g - ${ps.weightTo.toStringAsFixed(2)}g",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          // Pricing Grid Details
          Row(
            children: [
              Expanded(
                child: _buildDetailCell(
                  "VA %",
                  "${ps.vaPercent.toStringAsFixed(2)}%",
                  const Color(0xFF8B5CF6),
                ),
              ),
              Expanded(
                child: _buildDetailCell(
                  "Wastage",
                  "${ps.wastage.toStringAsFixed(3)}g",
                  const Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailCell(
                  "MC / Gram",
                  "₹${ps.mcPerGram.toStringAsFixed(2)}",
                  const Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: _buildDetailCell(
                  "Flat M.Charge",
                  "₹${ps.mCharge.toStringAsFixed(2)}",
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCell(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: GlassTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
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
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            horizontalMargin: 20,
            columnSpacing: 24,
            columns: const [
              DataColumn(
                label: Text(
                  "#",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "BRANCH",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "PRODUCT",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "SUB-PRODUCT",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "DEALER / SMITH",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "WEIGHT RANGE",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "VA %",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "WASTAGE",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "MC / GRAM",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "M. CHARGE",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "ACTIONS",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ),
            ],
            rows: _filteredPriceSettings.map((ps) {
              final isGlobal =
                  (ps.branchid == null ||
                  ps.branchid!.isEmpty ||
                  ps.branchid == 'ALL');
              final branchText = isGlobal
                  ? "Global / All"
                  : (ps.branchname != null && ps.branchname!.isNotEmpty
                        ? "${ps.branchid} (${ps.branchname})"
                        : ps.branchid!);

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      ps.id.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: GlassTheme.textSecondary,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isGlobal
                            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                            : const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        branchText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isGlobal
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      ps.productname ?? "Prod #${ps.productid}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(
                    Text(
                      ps.subproductname != null && ps.subproductname!.isNotEmpty
                          ? ps.subproductname!
                          : "—",
                      style: TextStyle(
                        color: ps.subproductname != null
                            ? const Color(0xFFEC4899)
                            : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      ps.dealername ?? ps.accode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
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
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${ps.weightFrom.toStringAsFixed(2)}g - ${ps.weightTo.toStringAsFixed(2)}g",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${ps.vaPercent.toStringAsFixed(2)}%",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${ps.wastage.toStringAsFixed(3)}g",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "₹${ps.mcPerGram.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "₹${ps.mCharge.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Color(0xFF6366F1),
                          ),
                          onPressed: () => _openForm(ps),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: GlassTheme.accentRose,
                          ),
                          onPressed: () => _deletePriceSetting(ps),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ================= EMPTY STATE =================
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.price_change_rounded,
              size: 40,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Price Settings Configured",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: GlassTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Define product & dealer weight range rules for automated VA% and making charge calculations.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              "Create First Price Setting",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => _openForm(),
          ),
        ],
      ),
    );
  }
}

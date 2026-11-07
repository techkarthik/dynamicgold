import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class ProductMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ProductMasterScreen({super.key, this.onBack});

  @override
  State<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
  final ApiService _api = ApiService();

  List<ProductRecord> _products = [];
  List<ProductRecord> _filteredProducts = [];
  List<CategoryRecord> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  int _lastProductId = 0;
  int _nextProductId = 1;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  ProductRecord? _editingProduct;
  final _formKey = GlobalKey<FormState>();

  int? _selectedCategoryId;
  final _nameController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  String _selectedCalcType = 'WEIGHT';
  String _selectedStockType = 'SKU';
  String _selectedHaveStone = 'NO';
  String _selectedHaveSubProduct = 'NO';
  String _selectedStudded = 'N'; // 'Y' or 'N'
  String _selectedDiaStone =
      ''; // 'D' (Diamond), 'S' (Stone), 'P' (Precious), or ''
  String _selectedStoneUnit = 'CARAT'; // 'CARAT' (CTS) or 'GRAM' (GMS)
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _hsnCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getProductsData(token),
        _api.getCategories(token),
      ]);

      if (mounted) {
        final productsData = results[0] as Map<String, dynamic>;
        setState(() {
          _products = productsData['products'] as List<ProductRecord>? ?? [];
          _lastProductId =
              int.tryParse(productsData['last_productid']?.toString() ?? '0') ??
              0;
          _nextProductId =
              int.tryParse(productsData['next_productid']?.toString() ?? '1') ??
              1;
          _categories = results[1] as List<CategoryRecord>;
          _applyFilter(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading products: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredProducts = List.from(_products);
    } else {
      _filteredProducts = _products.where((p) {
        final diastoneLabel = p.diastone == 'D'
            ? 'diamond'
            : (p.diastone == 'S'
                  ? 'stone'
                  : (p.diastone == 'P' ? 'precious' : 'plain'));
        return p.productname.toLowerCase().contains(_searchQuery) ||
            p.productid.toString().contains(_searchQuery) ||
            p.hsncode.toLowerCase().contains(_searchQuery) ||
            (p.catname ?? '').toLowerCase().contains(_searchQuery) ||
            (p.catcode ?? '').toLowerCase().contains(_searchQuery) ||
            (p.metalname ?? '').toLowerCase().contains(_searchQuery) ||
            p.calctype.toLowerCase().contains(_searchQuery) ||
            p.stocktype.toLowerCase().contains(_searchQuery) ||
            p.studded.toLowerCase().contains(_searchQuery) ||
            p.diastone.toLowerCase().contains(_searchQuery) ||
            diastoneLabel.contains(_searchQuery) ||
            p.stoneunit.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  void _openForm([ProductRecord? existing]) {
    setState(() {
      _editingProduct = existing;
      _showForm = true;
      if (existing != null) {
        _selectedCategoryId = existing.categoryid;
        _nameController.text = existing.productname;
        _hsnCodeController.text = existing.hsncode;
        _selectedCalcType = existing.calctype;
        _selectedStockType = existing.stocktype;
        _selectedHaveStone = existing.havestoneDiamond;
        _selectedHaveSubProduct = existing.havesubproduct;
        _selectedStudded = existing.studded.isNotEmpty
            ? existing.studded
            : (existing.havestoneDiamond == 'YES' ? 'Y' : 'N');
        _selectedDiaStone = existing.diastone;
        _selectedStoneUnit = existing.stoneunit.isNotEmpty
            ? existing.stoneunit
            : 'CARAT';
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _selectedCategoryId = _categories.isNotEmpty ? _categories.first.id : null;
    _nameController.clear();
    _hsnCodeController.clear();
    _selectedCalcType = 'WEIGHT';
    _selectedStockType = 'SKU';
    _selectedHaveStone = 'NO';
    _selectedHaveSubProduct = 'NO';
    _selectedStudded = 'N';
    _selectedDiaStone = '';
    _selectedStoneUnit = 'CARAT';
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingProduct = null;
      _resetFormFields();
    });
  }

  Future<void> _saveProductForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Category"),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final isDuplicate = _products.any(
      (p) =>
          p.productname.trim().toLowerCase() == name.toLowerCase() &&
          (_editingProduct == null ||
              p.productid != _editingProduct!.productid),
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Product name '$name' already exists. Product name must be unique.",
          ),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isStudded = _selectedStudded == 'Y' || _selectedDiaStone.isNotEmpty;
      final record = ProductRecord(
        productid: _editingProduct?.productid,
        categoryid: _selectedCategoryId!,
        productname: name,
        calctype: _selectedCalcType,
        stocktype: _selectedStockType,
        havestoneDiamond: isStudded ? 'YES' : _selectedHaveStone,
        havesubproduct: _selectedHaveSubProduct,
        studded: isStudded ? 'Y' : 'N',
        diastone: _selectedDiaStone,
        hsncode: _hsnCodeController.text.trim(),
        stoneunit: isStudded ? _selectedStoneUnit : '',
      );

      final isEditing =
          _editingProduct != null && _editingProduct!.productid != null;
      final response = isEditing
          ? await _api.updateProduct(token, _editingProduct!.productid!, record)
          : await _api.createProduct(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? "Product '$name' updated successfully!"
                    : "Product '$name' created successfully!",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
          _closeForm();
          await _loadData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message']?.toString() ?? "Failed to save product",
              ),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        // Header
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // Embedded In-Page Form
        if (_showForm) ...[
          _buildInPageEntryForm(isMobile),
          const SizedBox(height: 20),
        ],

        // Search & View toggles
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Body
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: GlassTheme.primaryNeon),
            ),
          )
        else if (_filteredProducts.isEmpty)
          _buildEmptyState(context, auth)
        else if (_isTableView && !isMobile)
          _buildTableView(context, auth)
        else
          _buildCardsGridView(context, auth, isMobile),
      ],
    );
  }

  // ================= HEADER BAR =================
  Widget _buildHeaderBar(
    BuildContext context,
    AuthProvider auth,
    bool isMobile,
  ) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: GlassTheme.textPrimary,
                  ),
                  tooltip: "Back to Inventory Submenu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Product Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(
                        label: "4th Master",
                        color: Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Define jewellery item products, calculation types, stock tracking (SKU/Open), and stone flags",
                    style: TextStyle(
                      fontSize: 12,
                      color: GlassTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMobile)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.grid_view_rounded,
                          color: !_isTableView
                              ? GlassTheme.primaryNeon
                              : GlassTheme.textMuted,
                          size: 18,
                        ),
                        tooltip: "Card Grid View",
                        onPressed: () => setState(() => _isTableView = false),
                      ),
                      const SizedBox(
                        height: 20,
                        child: VerticalDivider(
                          width: 1,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.table_rows_rounded,
                          color: _isTableView
                              ? GlassTheme.primaryNeon
                              : GlassTheme.textMuted,
                          size: 18,
                        ),
                        tooltip: "Compact Table View",
                        onPressed: () => setState(() => _isTableView = true),
                      ),
                    ],
                  ),
                ),
              if (!isMobile) const SizedBox(width: 12),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: GlassTheme.textPrimary,
                ),
                tooltip: "Reload Products",
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm
                      ? const Color(0xFF334155)
                      : const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  _showForm ? Icons.close_rounded : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(
                  _showForm ? "Close Form" : "Add Product",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
      ),
    );
  }

  // ================= IN-PAGE ENTRY FORM COMPONENT =================
  Widget _buildInPageEntryForm(bool isMobile) {
    final isEditing = _editingProduct != null;
    final displayId = isEditing ? _editingProduct!.productid : _nextProductId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar with ID indicators
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_circle_outline_rounded,
                    color: const Color(0xFF8B5CF6),
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
                            isEditing
                                ? "Edit Product (#$displayId - ${_editingProduct!.productname})"
                                : "Create New Product",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: GlassTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEditing
                                  ? "ID: #$displayId"
                                  : "Next Product ID: #$_nextProductId",
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (!isEditing && _lastProductId > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                "Last ID: #$_lastProductId",
                                style: const TextStyle(
                                  color: GlassTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing
                            ? "Modify product parameters and stock classification"
                            : "Assign to category, specify calculation mode (Weight/Rate/Fixed) and stock tracking",
                        style: const TextStyle(
                          fontSize: 12,
                          color: GlassTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: GlassTheme.textPrimary,
                  ),
                  tooltip: "Cancel and Close Form",
                  onPressed: _closeForm,
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFE2E8F0)),

            // Row 1: Product ID (Autogenerated), Category Name, Product Name, and HSN Code
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                // Product ID Display (Autogenerated)
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Product ID (Auto)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "#$displayId",
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: GlassTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Name (List from Category Master)
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Category Name * (from Category Master)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCategoryId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Select Category"),
                        isExpanded: true,
                        items: _categories.map((c) {
                          final metalDisplay =
                              c.metalname != null && c.metalname!.isNotEmpty
                              ? c.metalname!
                              : c.metalid;
                          return DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(
                              "${c.catname} (${c.catcode} - $metalDisplay)",
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategoryId = val),
                        validator: (val) => val == null
                            ? "Category selection is required"
                            : null,
                      ),
                    ],
                  ),
                ),

                // Product Name (VARCHAR 100)
                SizedBox(
                  width: isMobile ? double.infinity : 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Product Name * (VARCHAR 100)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 100,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration(
                          "e.g. Mens Diamond Ring, Gold Necklace",
                        ).copyWith(counterText: ""),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Product Name is required";
                          }
                          final clean = val.trim().toLowerCase();
                          final isDuplicate = _products.any(
                            (p) =>
                                p.productname.trim().toLowerCase() == clean &&
                                (_editingProduct == null ||
                                    p.productid != _editingProduct!.productid),
                          );
                          if (isDuplicate) {
                            return "Product name '${val.trim()}' already exists (Must be unique)";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // HSN Code
                SizedBox(
                  width: isMobile ? double.infinity : 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "HSN Code",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _hsnCodeController,
                        maxLength: 12,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. 7113, 7102")
                            .copyWith(
                              counterText: "",
                              prefixIcon: const Icon(
                                Icons.tag_rounded,
                                size: 18,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Row 2: Calculation Type, Stock Type, Have Sub Product
            const Text(
              "Billing & Stock Tracking Rules",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                // 1. Calculation Type (WEIGHT, RATE, METAL, FIXED)
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Calc Type (calctype) *",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCalcType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Calc Type"),
                        items: const [
                          DropdownMenuItem(
                            value: 'WEIGHT',
                            child: Text(
                              "WEIGHT (By Grams)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'RATE',
                            child: Text(
                              "RATE (Rate Basis)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'METAL',
                            child: Text(
                              "METAL (Metal Purity)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'FIXED',
                            child: Text(
                              "FIXED (Fixed / MRP)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCalcType = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 2. Stock Type (SKU, OPEN)
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Stock Type (stocktype) *",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStockType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Stock Type"),
                        items: const [
                          DropdownMenuItem(
                            value: 'SKU',
                            child: Text(
                              "SKU (Barcode Tagged Item)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'OPEN',
                            child: Text(
                              "OPEN (Bulk Weight Inventory)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStockType = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 3. Have Sub Product (YES, NO)
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Have Sub-Product *",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedHaveSubProduct,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Sub Products?"),
                        items: const [
                          DropdownMenuItem(
                            value: 'YES',
                            child: Text(
                              "YES (Has Parts / Subproducts)",
                              style: TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'NO',
                            child: Text(
                              "NO (Single Item)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedHaveSubProduct = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Row 3: Studded & Diamond/Stone Master Specifications
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD97706,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.diamond_rounded,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Studded Stone & Diamond Classification",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedStudded == 'Y' ||
                          _selectedDiaStone.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD97706,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Studded / Stone Active",
                            style: TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      // 1. STUDDED = Y / N
                      SizedBox(
                        width: isMobile ? double.infinity : 260,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Studded Product (studded = Y/N) *",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedStudded,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: _inputDecoration("Studded?"),
                              items: const [
                                DropdownMenuItem(
                                  value: 'N',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: GlassTheme.textMuted,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "N - Plain Product (No Stones)",
                                        style: TextStyle(
                                          color: GlassTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Y',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.diamond_outlined,
                                        color: Color(0xFFD97706),
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Y - Studded / Stone Product",
                                        style: TextStyle(
                                          color: Color(0xFFD97706),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedStudded = val;
                                    if (val == 'Y') {
                                      _selectedHaveStone = 'YES';
                                      if (_selectedDiaStone.isEmpty) {
                                        _selectedDiaStone = 'S';
                                      }
                                    } else {
                                      _selectedHaveStone = 'NO';
                                      _selectedDiaStone = '';
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // 2. DIASTONE = D (Diamond) / S (Stone) / P (Precious)
                      SizedBox(
                        width: isMobile ? double.infinity : 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Stone Type (DIASTONE = D / S / P)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDiaStone,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: _inputDecoration("Diamond / Stone"),
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    "None (Plain Metal)",
                                    style: TextStyle(
                                      color: GlassTheme.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'D',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.diamond_rounded,
                                        color: Color(0xFF0284C7),
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "D - Diamond",
                                        style: TextStyle(
                                          color: Color(0xFF0284C7),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'S',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.blur_on_rounded,
                                        color: Color(0xFF059669),
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "S - Stone (Synthetic / Semi-Precious)",
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'P',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "P - Precious Stone (Ruby, Emerald, etc.)",
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedDiaStone = val;
                                    if (val.isNotEmpty) {
                                      _selectedStudded = 'Y';
                                      _selectedHaveStone = 'YES';
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      // 3. Stone Unit (Carat / Gram)
                      SizedBox(
                        width: isMobile ? double.infinity : 260,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Stone Unit (stoneunit: Carat / Gram)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedStoneUnit,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: _inputDecoration("Stone Unit"),
                              items: const [
                                DropdownMenuItem(
                                  value: 'CARAT',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.scale_rounded,
                                        color: Color(0xFF8B5CF6),
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "CARAT (CTS - 1 Cts = 0.200g)",
                                        style: TextStyle(
                                          color: GlassTheme.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'GRAM',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.balance_rounded,
                                        color: Color(0xFF10B981),
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "GRAM (GMS - Direct Grams)",
                                        style: TextStyle(
                                          color: GlassTheme.textPrimary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged:
                                  (_selectedStudded == 'Y' ||
                                      _selectedDiaStone.isNotEmpty)
                                  ? (val) {
                                      if (val != null) {
                                        setState(
                                          () => _selectedStoneUnit = val,
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassSecondaryButton(
                  label: "Clear Fields",
                  icon: Icons.refresh_rounded,
                  onPressed: _resetFormFields,
                ),
                const SizedBox(width: 12),
                GlassSecondaryButton(label: "Cancel", onPressed: _closeForm),
                const SizedBox(width: 12),
                GlassButton(
                  label: isEditing ? "Update Product" : "Save Product",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  isLoading: _isSaving,
                  onPressed: _saveProductForm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: GlassTheme.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GlassTheme.accentRose, width: 1.5),
      ),
    );
  }

  // ================= SEARCH TOOLBAR =================
  Widget _buildSearchToolbar(bool isMobile) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _applyFilter(val)),
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: GlassTheme.textSecondary,
                  size: 20,
                ),
                hintText:
                    "Search products by ID, name, category, metal, or stock type...",
                hintStyle: const TextStyle(
                  color: GlassTheme.textMuted,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
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
                    color: Color(0xFF8B5CF6),
                    width: 1.5,
                  ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: GlassTheme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applyFilter(''));
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Icon(
                Icons.category_rounded,
                size: 48,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching products found"
                  : "No Products configured yet",
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query."
                  : "Get started by adding jewellery products mapped to your categories.",
              style: const TextStyle(
                color: GlassTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  "Create Product",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openForm(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================= CARD GRID VIEW =================
  Widget _buildCardsGridView(
    BuildContext context,
    AuthProvider auth,
    bool isMobile,
  ) {
    final double cardWidth = isMobile ? 320 : 360;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _filteredProducts.map((prod) {
            return SizedBox(
              width: isMobile ? constraints.maxWidth : cardWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            prod.productname,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: GlassTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: "#${prod.productid ?? '-'}",
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow(
                      "Category",
                      "${prod.catname ?? '-'} (${prod.catcode ?? ''})",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Metal",
                      prod.metalname ?? prod.metalid ?? '-',
                    ),
                    if (prod.hsncode.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow("HSN Code", prod.hsncode),
                    ],
                    const SizedBox(height: 6),
                    _buildInfoRow("Calculation Type", prod.calctype),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Stock Tracking",
                      prod.stocktype == 'SKU' ? "SKU (Tagged)" : "OPEN (Bulk)",
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Studded / Stone",
                          style: TextStyle(
                            fontSize: 12,
                            color: GlassTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (prod.studded == 'Y'
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF64748B))
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            prod.studded == 'Y'
                                ? "YES (Studded)"
                                : "NO (Plain)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: prod.studded == 'Y'
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (prod.diastone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        "Stone Type",
                        prod.diastone == 'D'
                            ? "D - Diamond"
                            : (prod.diastone == 'S'
                                  ? "S - Synthetic/Stone"
                                  : (prod.diastone == 'P'
                                        ? "P - Precious Stone"
                                        : prod.diastone)),
                      ),
                    ],
                    if (prod.stoneunit.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        "Stone Unit",
                        prod.stoneunit == 'CARAT'
                            ? "CARAT (CTS)"
                            : "GRAM (GMS)",
                      ),
                    ],
                    const SizedBox(height: 6),
                    _buildInfoRow("Sub-Product Parts", prod.havesubproduct),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF8B5CF6),
                            size: 20,
                          ),
                          tooltip: "Edit Product",
                          onPressed: () => _openForm(prod),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          tooltip: "Delete Product",
                          onPressed: () => _confirmDelete(prod),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: GlassTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: GlassTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ================= TABLE VIEW =================
  Widget _buildTableView(BuildContext context, AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            dataRowColor: WidgetStateProperty.all(Colors.white),
            columns: const [
              DataColumn(
                label: Text(
                  "PROD ID",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "PRODUCT NAME",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CATEGORY",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "HSN CODE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "STUDDED",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "DIA/STONE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "STONE UNIT",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CALC TYPE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "STOCK TYPE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "SUB PROD",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "ACTIONS",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            rows: _filteredProducts.map((prod) {
              final isStudded = prod.studded == 'Y';
              String diaLabel = '-';
              Color diaColor = GlassTheme.textMuted;
              if (prod.diastone == 'D') {
                diaLabel = 'D (Diamond)';
                diaColor = const Color(0xFF0284C7);
              } else if (prod.diastone == 'S') {
                diaLabel = 'S (Stone)';
                diaColor = const Color(0xFF059669);
              } else if (prod.diastone == 'P') {
                diaLabel = 'P (Precious)';
                diaColor = const Color(0xFFDC2626);
              }

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      "#${prod.productid ?? '-'}",
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      prod.productname,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${prod.catname ?? '-'} (${prod.catcode ?? ''})",
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      prod.hsncode.isNotEmpty ? prod.hsncode : '-',
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isStudded
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF64748B))
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isStudded ? "Y" : "N",
                        style: TextStyle(
                          color: isStudded
                              ? const Color(0xFFD97706)
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      diaLabel,
                      style: TextStyle(
                        color: diaColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      prod.stoneunit.isNotEmpty
                          ? (prod.stoneunit == 'CARAT'
                                ? 'Carat (Cts)'
                                : 'Gram (Gms)')
                          : '-',
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        prod.calctype,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
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
                            (prod.stocktype == 'SKU'
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFF59E0B))
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        prod.stocktype,
                        style: TextStyle(
                          color: prod.stocktype == 'SKU'
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFD97706),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      prod.havesubproduct,
                      style: TextStyle(
                        color: prod.havesubproduct == 'YES'
                            ? const Color(0xFF8B5CF6)
                            : GlassTheme.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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
                            color: Color(0xFF8B5CF6),
                            size: 18,
                          ),
                          tooltip: "Edit",
                          onPressed: () => _openForm(prod),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 18,
                          ),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(prod),
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

  // ================= DELETE CONFIRMATION =================
  void _confirmDelete(ProductRecord prod) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: GlassTheme.accentRose,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              "Delete Product",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete product '#${prod.productid} - ${prod.productname}'?",
          style: const TextStyle(
            color: GlassTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: GlassTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (prod.productid == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteProduct(token, prod.productid!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? "Product deleted",
                    ),
                    backgroundColor: isOk
                        ? GlassTheme.accentEmerald
                        : GlassTheme.accentRose,
                  ),
                );
                if (isOk) _loadData();
              }
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class SubProductMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SubProductMasterScreen({super.key, this.onBack});

  @override
  State<SubProductMasterScreen> createState() => _SubProductMasterScreenState();
}

class _SubProductMasterScreenState extends State<SubProductMasterScreen> {
  final ApiService _api = ApiService();

  List<SubProductRecord> _subProducts = [];
  List<SubProductRecord> _filteredSubProducts = [];
  List<ProductRecord> _eligibleProducts =
      []; // Only products with havesubproduct == 'YES'

  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  int _lastSubProductId = 0;
  int _nextSubProductId = 1;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  SubProductRecord? _editingSubProduct;
  final _formKey = GlobalKey<FormState>();

  int? _selectedProductId;
  final _nameController = TextEditingController();
  String _selectedHaveStone = 'NO';
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
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getSubProductsData(token),
        _api.getProducts(token),
      ]);

      if (mounted) {
        final subProductsData = results[0] as Map<String, dynamic>;
        final products = results[1] as List<ProductRecord>;

        setState(() {
          _subProducts =
              subProductsData['subproducts'] as List<SubProductRecord>? ?? [];
          _lastSubProductId =
              int.tryParse(
                subProductsData['last_subproductid']?.toString() ?? '0',
              ) ??
              0;
          _nextSubProductId =
              int.tryParse(
                subProductsData['next_subproductid']?.toString() ?? '1',
              ) ??
              1;

          // Filter only products where havesubproduct == 'YES'
          _eligibleProducts = products
              .where((p) => p.havesubproduct.toUpperCase() == 'YES')
              .toList();

          _applyFilter(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading sub-products: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredSubProducts = List.from(_subProducts);
    } else {
      _filteredSubProducts = _subProducts.where((s) {
        return s.subproductname.toLowerCase().contains(_searchQuery) ||
            s.subproductid.toString().contains(_searchQuery) ||
            (s.productname ?? '').toLowerCase().contains(_searchQuery) ||
            (s.catname ?? '').toLowerCase().contains(_searchQuery) ||
            (s.metalname ?? '').toLowerCase().contains(_searchQuery) ||
            s.havestoneDiamond.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  void _openForm([SubProductRecord? existing]) {
    setState(() {
      _editingSubProduct = existing;
      _showForm = true;
      if (existing != null) {
        _selectedProductId = existing.productid;
        _nameController.text = existing.subproductname;
        _selectedHaveStone = existing.havestoneDiamond;
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _selectedProductId = _eligibleProducts.isNotEmpty
        ? _eligibleProducts.first.productid
        : null;
    _nameController.clear();
    _selectedHaveStone = 'NO';
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingSubProduct = null;
      _resetFormFields();
    });
  }

  Future<void> _saveSubProductForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Parent Product"),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();

      final record = SubProductRecord(
        subproductid: _editingSubProduct?.subproductid,
        productid: _selectedProductId!,
        subproductname: name,
        havestoneDiamond: _selectedHaveStone,
      );

      final isEditing =
          _editingSubProduct != null &&
          _editingSubProduct!.subproductid != null;
      final response = isEditing
          ? await _api.updateSubProduct(
              token,
              _editingSubProduct!.subproductid!,
              record,
            )
          : await _api.createSubProduct(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? "Sub-Product '$name' updated successfully!"
                    : "Sub-Product '$name' created successfully!",
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
                response['message']?.toString() ?? "Failed to save sub-product",
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
        else if (_filteredSubProducts.isEmpty)
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
                    colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
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
                        "Sub-Product Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(
                        label: "5th Master",
                        color: Color(0xFFEC4899),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Define sub-assembly components for parent products (where Have Sub-Product = YES)",
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
                tooltip: "Reload Sub-Products",
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm
                      ? const Color(0xFF334155)
                      : const Color(0xFFEC4899),
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
                  _showForm ? "Close Form" : "Add Sub-Product",
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
    final isEditing = _editingSubProduct != null;
    final displayId = isEditing
        ? _editingSubProduct!.subproductid
        : _nextSubProductId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEC4899).withValues(alpha: 0.5),
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
                    color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_circle_outline_rounded,
                    color: const Color(0xFFEC4899),
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
                                ? "Edit Sub-Product (#$displayId - ${_editingSubProduct!.subproductname})"
                                : "Create New Sub-Product",
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
                                0xFFEC4899,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEditing
                                  ? "ID: #$displayId"
                                  : "Next Sub-Product ID: #$_nextSubProductId",
                              style: const TextStyle(
                                color: Color(0xFFEC4899),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (!isEditing && _lastSubProductId > 0) ...[
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
                                "Last ID: #$_lastSubProductId",
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
                      const Text(
                        "Map sub-part to a parent product where Have Sub-Product = YES. Sub-product name is unique within the product.",
                        style: TextStyle(
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

            // If no products have havesubproduct == 'YES', display a warning helper
            if (_eligibleProducts.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Note: No parent products have 'Have Sub-Product = YES' enabled yet. To add sub-products, please edit a product in 'Product Master' and set 'HAVE SUB-PRODUCT' to 'YES'.",
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Input Fields
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                // 1. Sub-Product ID Display (Autogenerated)
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sub-Product ID (Auto)",
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
                                color: Color(0xFFEC4899),
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

                // 2. Parent Product Selection (from ProductMaster where havesubproduct == 'YES')
                SizedBox(
                  width: isMobile ? double.infinity : 340,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Parent Product * (Have Sub-Product = YES)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedProductId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Select Parent Product"),
                        isExpanded: true,
                        items: _eligibleProducts.map((p) {
                          return DropdownMenuItem<int>(
                            value: p.productid,
                            child: Text(
                              "#${p.productid} - ${p.productname} (${p.catname ?? ''})",
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedProductId = val),
                        validator: (val) =>
                            val == null ? "Parent Product is required" : null,
                      ),
                    ],
                  ),
                ),

                // 3. Sub-Product Name (VARCHAR 100, unique within parent product)
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sub-Product Name * (Unique per Product)",
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
                          "e.g. Center Solitaire Pendant, Side Earring Drop",
                        ).copyWith(counterText: ""),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Sub-Product Name is required";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // 4. Have Stone / Diamond (YES, NO)
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Have Stone / Diamond *",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedHaveStone,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Have Stone?"),
                        items: const [
                          DropdownMenuItem(
                            value: 'YES',
                            child: Text(
                              "YES (With Stones)",
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'NO',
                            child: Text(
                              "NO (Plain Metal)",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedHaveStone = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
                  label: isEditing ? "Update Sub-Product" : "Save Sub-Product",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
                  ),
                  isLoading: _isSaving,
                  onPressed: _saveSubProductForm,
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
        borderSide: const BorderSide(color: Color(0xFFEC4899), width: 2.0),
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
                    "Search sub-products by ID, name, parent product, category...",
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
                    color: Color(0xFFEC4899),
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
                Icons.account_tree_rounded,
                size: 48,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching sub-products found"
                  : "No Sub-Products configured yet",
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
                  : "Add component parts for your multi-piece jewellery products.",
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
                  backgroundColor: const Color(0xFFEC4899),
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
                  "Create Sub-Product",
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
          children: _filteredSubProducts.map((sub) {
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
                            sub.subproductname,
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
                          label: "#${sub.subproductid ?? '-'}",
                          color: const Color(0xFFEC4899),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow(
                      "Parent Product",
                      "${sub.productname ?? '-'} (#${sub.productid})",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Category",
                      "${sub.catname ?? '-'} (${sub.catcode ?? ''})",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow("Metal", sub.metalname ?? sub.metalid ?? '-'),
                    const SizedBox(height: 6),
                    _buildInfoRow("Stone / Diamond", sub.havestoneDiamond),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFFEC4899),
                            size: 20,
                          ),
                          tooltip: "Edit Sub-Product",
                          onPressed: () => _openForm(sub),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          tooltip: "Delete Sub-Product",
                          onPressed: () => _confirmDelete(sub),
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
                  "SUB ID",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "SUB-PRODUCT NAME",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "PARENT PRODUCT",
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
                  "STONE/DIA",
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
            rows: _filteredSubProducts.map((sub) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      "#${sub.subproductid ?? '-'}",
                      style: const TextStyle(
                        color: Color(0xFFEC4899),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      sub.subproductname,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${sub.productname ?? '-'} (#${sub.productid})",
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${sub.catname ?? '-'} (${sub.catcode ?? ''})",
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      sub.havestoneDiamond,
                      style: TextStyle(
                        color: sub.havestoneDiamond == 'YES'
                            ? const Color(0xFF10B981)
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
                            color: Color(0xFFEC4899),
                            size: 18,
                          ),
                          tooltip: "Edit",
                          onPressed: () => _openForm(sub),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 18,
                          ),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(sub),
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
  void _confirmDelete(SubProductRecord sub) {
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
              "Delete Sub-Product",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete sub-product '#${sub.subproductid} - ${sub.subproductname}' under parent product '${sub.productname}'?",
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
              if (sub.subproductid == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteSubProduct(token, sub.subproductid!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? "Sub-Product deleted",
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

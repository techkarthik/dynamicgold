import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class StyleMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const StyleMasterScreen({super.key, this.onBack});

  @override
  State<StyleMasterScreen> createState() => _StyleMasterScreenState();
}

class _StyleMasterScreenState extends State<StyleMasterScreen> {
  final ApiService _api = ApiService();

  List<StyleRecord> _styles = [];
  List<StyleRecord> _filteredStyles = [];
  List<ProductRecord> _allProducts = [];

  bool _isLoading = false;
  String _searchQuery = '';
  int? _filterProductId;
  bool _isTableView = false;

  int _lastStyleId = 0;
  int _nextStyleId = 1;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  StyleRecord? _editingStyle;
  final _formKey = GlobalKey<FormState>();

  int? _selectedProductId;
  final _nameController = TextEditingController();
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
        _api.getStylesData(token),
        _api.getProducts(token),
      ]);

      if (mounted) {
        final stylesData = results[0] as Map<String, dynamic>;
        final products = results[1] as List<ProductRecord>;

        setState(() {
          _styles = stylesData['styles'] as List<StyleRecord>? ?? [];
          _lastStyleId =
              int.tryParse(stylesData['last_styleid']?.toString() ?? '0') ?? 0;
          _nextStyleId =
              int.tryParse(stylesData['next_styleid']?.toString() ?? '1') ?? 1;
          _allProducts = products;

          if ((_selectedProductId == null ||
                  !_allProducts.any(
                    (p) => p.productid == _selectedProductId,
                  )) &&
              _allProducts.isNotEmpty) {
            _selectedProductId = _allProducts.first.productid;
          }

          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading styles: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    final q = _searchQuery.trim().toLowerCase();
    _filteredStyles = _styles.where((s) {
      final matchesProductFilter =
          _filterProductId == null || s.productid == _filterProductId;
      if (!matchesProductFilter) return false;

      if (q.isEmpty) return true;

      return s.stylename.toLowerCase().contains(q) ||
          s.styleid.toString().contains(q) ||
          (s.productname ?? '').toLowerCase().contains(q) ||
          (s.catname ?? '').toLowerCase().contains(q) ||
          (s.metalname ?? '').toLowerCase().contains(q) ||
          (s.catcode ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openForm([StyleRecord? existing]) {
    setState(() {
      _editingStyle = existing;
      _showForm = true;
      if (existing != null) {
        _selectedProductId = existing.productid;
        _nameController.text = existing.stylename;
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _selectedProductId = _allProducts.isNotEmpty
        ? _allProducts.first.productid
        : null;
    _nameController.clear();
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingStyle = null;
      _resetFormFields();
    });
  }

  Future<void> _saveStyleForm() async {
    if (!_formKey.currentState!.validate()) return;

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

    final effectiveProductId =
        (_selectedProductId != null &&
            _allProducts.any((p) => p.productid == _selectedProductId))
        ? _selectedProductId!
        : (_allProducts.isNotEmpty ? _allProducts.first.productid! : null);

    if (effectiveProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a Product from Product Master."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();

      final record = StyleRecord(
        styleid: _editingStyle?.styleid,
        productid: effectiveProductId,
        stylename: name,
      );

      final isEditing = _editingStyle != null && _editingStyle!.styleid != null;
      final response = isEditing
          ? await _api.updateStyle(token, _editingStyle!.styleid!, record)
          : await _api.createStyle(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? "Style '$name' updated successfully!"
                    : "Style '$name' created successfully!",
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
                response['message']?.toString() ?? "Failed to save style",
              ),
              backgroundColor: GlassTheme.accentRose,
              duration: const Duration(seconds: 4),
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

        // Search and Filter Bar
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Body
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
            ),
          )
        else if (_filteredStyles.isEmpty)
          _buildEmptyState(context, auth)
        else
          _isTableView
              ? _buildTableView(context, auth)
              : _buildCardsGridView(context, auth, isMobile),
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
          if (widget.onBack != null)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: GlassTheme.textPrimary,
              ),
              tooltip: "Back to Item Master",
              onPressed: widget.onBack,
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.style_rounded,
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
                      "Style Master",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: GlassTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    StatusBadge(
                      label: "Inventory Master #6",
                      color: Color(0xFF06B6D4),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Define design styles, models, and variant names for every jewellery product",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.style_outlined,
                    size: 14,
                    color: Color(0xFF0891B2),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Total: ${_styles.length} | Last ID: #$_lastStyleId",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0891B2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (!_showForm)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
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
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                "New Style",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: () => _openForm(),
            ),
        ],
      ),
    );
  }

  // ================= IN-PAGE ENTRY FORM COMPONENT =================
  Widget _buildInPageEntryForm(bool isMobile) {
    final isEditing = _editingStyle != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.5),
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
            // Form Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isEditing
                          ? Icons.edit_note_rounded
                          : Icons.add_circle_outline_rounded,
                      color: const Color(0xFF06B6D4),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? "Edit Style Record #${_editingStyle?.styleid}"
                          : "Add New Style",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 14,
                        color: Color(0xFF0891B2),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isEditing
                            ? "Style ID: #${_editingStyle?.styleid}"
                            : "Next Auto ID: #$_nextStyleId",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0891B2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Select the parent Product from Product Master and enter the design Style Name (max 100 characters).",
              style: TextStyle(
                fontSize: 12,
                color: GlassTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 18),

            Wrap(
              spacing: 20,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // Field 1: Product Dropdown (from Product Master)
                SizedBox(
                  width: isMobile ? double.infinity : 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.category_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Product Name (from Product Master) *",
                            style: TextStyle(
                              color: GlassTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_allProducts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Text(
                            "No Products found. Please create Products in Product Master first.",
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<int>(
                          initialValue:
                              (_selectedProductId != null &&
                                  _allProducts.any(
                                    (p) => p.productid == _selectedProductId,
                                  ))
                              ? _selectedProductId
                              : (_allProducts.isNotEmpty
                                    ? _allProducts.first.productid
                                    : null),
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            color: GlassTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _inputDecoration("Select Product"),
                          isExpanded: true,
                          items: _allProducts.map((p) {
                            final categoryInfo = p.catname != null
                                ? " (${p.catname})"
                                : "";
                            return DropdownMenuItem<int>(
                              value: p.productid,
                              child: Text(
                                "${p.productname}$categoryInfo",
                                style: const TextStyle(
                                  color: GlassTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedProductId = val);
                          },
                          validator: (val) =>
                              val == null ? "Please select a Product" : null,
                        ),
                    ],
                  ),
                ),

                // Field 2: Style Name (Varchar 100)
                SizedBox(
                  width: isMobile ? double.infinity : 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.drive_file_rename_outline_rounded,
                            color: Color(0xFF06B6D4),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Style Name (VARCHAR 100) *",
                            style: TextStyle(
                              color: GlassTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        maxLength: 100,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration(
                          "e.g. Antique Traditional, Floral Pattern, Temple Casting",
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Style Name is required";
                          }
                          if (val.trim().length > 100) {
                            return "Max length is 100 characters";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassSecondaryButton(
                  label: "Clear",
                  icon: Icons.refresh_rounded,
                  onPressed: _resetFormFields,
                ),
                const SizedBox(width: 12),
                GlassSecondaryButton(label: "Cancel", onPressed: _closeForm),
                const SizedBox(width: 12),
                GlassButton(
                  label: isEditing ? "Update Style" : "Save Style",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                  ),
                  isLoading: _isSaving,
                  onPressed: _saveStyleForm,
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
        borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GlassTheme.accentRose, width: 1.5),
      ),
    );
  }

  // ================= SEARCH & FILTER TOOLBAR =================
  Widget _buildSearchToolbar(bool isMobile) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilter();
                });
              },
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
                    "Search styles by name, style ID, product name, or category...",
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
                    color: Color(0xFF06B6D4),
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
                          setState(() {
                            _searchQuery = '';
                            _applyFilter();
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filter by Product Dropdown
          if (_allProducts.isNotEmpty && !isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _filterProductId,
                  hint: const Text(
                    "All Products",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        "All Products",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ..._allProducts.map(
                      (p) => DropdownMenuItem<int?>(
                        value: p.productid,
                        child: Text(
                          "${p.productname} (${p.catname ?? ''})",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
            ),
          const SizedBox(width: 12),

          // View Toggle: Grid vs Table
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.grid_view_rounded,
                    size: 18,
                    color: !_isTableView
                        ? const Color(0xFF06B6D4)
                        : GlassTheme.textMuted,
                  ),
                  tooltip: "Card Grid View",
                  onPressed: () => setState(() => _isTableView = false),
                ),
                IconButton(
                  icon: Icon(
                    Icons.table_rows_rounded,
                    size: 18,
                    color: _isTableView
                        ? const Color(0xFF06B6D4)
                        : GlassTheme.textMuted,
                  ),
                  tooltip: "Table View",
                  onPressed: () => setState(() => _isTableView = true),
                ),
              ],
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
                Icons.style_rounded,
                size: 48,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching styles found"
                  : "No Product Styles created yet",
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query or product filter."
                  : "Add design styles (e.g. Traditional, Antique, Contemporary, Floral, Temple) for your products.",
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
                  backgroundColor: const Color(0xFF06B6D4),
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
                  "Create First Style",
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
          children: _filteredStyles.map((style) {
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
                            style.stylename,
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
                          label: "#${style.styleid}",
                          color: const Color(0xFF06B6D4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow(
                      "Parent Product",
                      style.productname ?? "Product #${style.productid}",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow("Category", style.catname ?? "-"),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Base Metal",
                      style.metalname != null
                          ? "${style.metalname} (${style.metalid})"
                          : "-",
                    ),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: GlassTheme.primaryNeon,
                            size: 20,
                          ),
                          tooltip: "Edit Style",
                          onPressed: () => _openForm(style),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          tooltip: "Delete Style",
                          onPressed: () => _confirmDelete(style),
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
                  "STYLE ID",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "STYLE NAME",
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
                  "METAL",
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
            rows: _filteredStyles.map((style) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      "#${style.styleid}",
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      style.stylename,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        style.productname ?? "Product #${style.productid}",
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      style.catname ?? "-",
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      style.metalname != null
                          ? "${style.metalname} (${style.metalid})"
                          : "-",
                      style: const TextStyle(
                        color: GlassTheme.primaryNeon,
                        fontWeight: FontWeight.w700,
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
                            color: GlassTheme.primaryNeon,
                            size: 18,
                          ),
                          tooltip: "Edit",
                          onPressed: () => _openForm(style),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 18,
                          ),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(style),
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
  void _confirmDelete(StyleRecord style) {
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
              "Delete Style",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete style '${style.stylename}' (ID #${style.styleid}) under product '${style.productname ?? ''}'?",
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
              if (style.styleid == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteStyle(token, style.styleid!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? "Style deleted",
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/inventory_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class DesignerMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DesignerMasterScreen({super.key, this.onBack});

  @override
  State<DesignerMasterScreen> createState() => _DesignerMasterScreenState();
}

class _DesignerMasterScreenState extends State<DesignerMasterScreen> {
  final ApiService _api = ApiService();

  List<DesignerRecord> _designers = [];
  List<DesignerRecord> _filteredDesigners = [];
  List<Map<String, dynamic>> _allDealersAndSmiths = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _showForm = false;
  bool _isTableView = true;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterAccountType = 'ALL'; // 'ALL', 'DEALER', 'SMITH'

  // Form State
  final _formKey = GlobalKey<FormState>();
  DesignerRecord? _editingRecord;

  String? _selectedAccode;
  final TextEditingController _designerNameController = TextEditingController();
  final TextEditingController _designerShortNameController =
      TextEditingController();

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
    _designerNameController.dispose();
    _designerShortNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getDesignersData(token),
        _api.getPriceSettingDealers(token),
      ]);

      if (mounted) {
        final designersData = results[0] as Map<String, dynamic>;
        final dealersAndSmiths = results[1] as List<Map<String, dynamic>>;

        setState(() {
          _designers =
              designersData['designers'] as List<DesignerRecord>? ?? [];
          _allDealersAndSmiths = dealersAndSmiths;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load designers: $e');
      }
    }
  }

  void _applyFilter() {
    List<DesignerRecord> filtered = List.from(_designers);

    // Filter by Account Type
    if (_filterAccountType != 'ALL') {
      filtered = filtered
          .where(
            (d) => (d.accounttype ?? '').toUpperCase() == _filterAccountType,
          )
          .toList();
    }

    // Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((d) {
        final nameMatch = d.designername.toLowerCase().contains(q);
        final shortMatch = d.designershortname.toLowerCase().contains(q);
        final accodeMatch = d.accode.toLowerCase().contains(q);
        final accountNameMatch = (d.accountname ?? '').toLowerCase().contains(
          q,
        );
        final idMatch = (d.designerid?.toString() ?? '').contains(q);
        return nameMatch ||
            shortMatch ||
            accodeMatch ||
            accountNameMatch ||
            idMatch;
      }).toList();
    }

    setState(() {
      _filteredDesigners = filtered;
    });
  }

  void _openCreateForm() {
    setState(() {
      _editingRecord = null;
      _selectedAccode = _allDealersAndSmiths.isNotEmpty
          ? _allDealersAndSmiths.first['accode']?.toString()
          : null;
      _designerNameController.clear();
      _designerShortNameController.clear();
      _showForm = true;
    });
  }

  void _openEditForm(DesignerRecord record) {
    setState(() {
      _editingRecord = record;
      _selectedAccode = record.accode;
      _designerNameController.text = record.designername;
      _designerShortNameController.text = record.designershortname;
      _showForm = true;
    });
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingRecord = null;
    });
  }

  Future<void> _saveDesigner() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccode == null || _selectedAccode!.isEmpty) {
      _showErrorSnackBar('Please select an Account Head (Smith / Dealer)');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    final trimmedName = _designerNameController.text.trim();
    final trimmedShortName = _designerShortNameController.text
        .trim()
        .toUpperCase();

    // Check duplicate designer name locally
    final isDuplicateName = _designers.any(
      (d) =>
          d.designername.trim().toLowerCase() == trimmedName.toLowerCase() &&
          (_editingRecord == null ||
              d.designerid != _editingRecord!.designerid),
    );

    if (isDuplicateName) {
      _showErrorSnackBar('A designer with name "$trimmedName" already exists');
      return;
    }

    final record = DesignerRecord(
      designerid: _editingRecord?.designerid,
      accode: _selectedAccode!,
      designername: trimmedName,
      designershortname: trimmedShortName,
    );

    setState(() => _isSaving = true);

    try {
      if (_editingRecord == null) {
        final res = await _api.createDesigner(token, record);
        if (res['success'] != true) {
          throw Exception(res['message'] ?? 'Failed to create designer');
        }
        if (mounted) {
          _showSuccessSnackBar('Designer "$trimmedName" created successfully');
        }
      } else {
        final res = await _api.updateDesigner(
          token,
          _editingRecord!.designerid ?? 0,
          record,
        );
        if (res['success'] != true) {
          throw Exception(res['message'] ?? 'Failed to update designer');
        }
        if (mounted) {
          _showSuccessSnackBar('Designer "$trimmedName" updated successfully');
        }
      }

      if (mounted) {
        _closeForm();
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Save failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete(DesignerRecord record) async {
    if (record.designerid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: GlassTheme.accentRose,
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Delete Designer',
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete designer "${record.designername}"?',
              style: const TextStyle(
                color: GlassTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Designer ID: ',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '#${record.designerid}',
                        style: const TextStyle(
                          color: Color(0xFFE11D48),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Linked Account: ',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${record.accountname ?? record.accode} (${record.accounttype ?? "N/A"})',
                          style: const TextStyle(
                            color: GlassTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: GlassTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.authToken;
      if (token == null) return;

      setState(() => _isLoading = true);
      try {
        final res = await _api.deleteDesigner(token, record.designerid!);
        if (res['success'] != true) {
          throw Exception(res['message'] ?? 'Failed to delete designer');
        }
        if (mounted) {
          _showSuccessSnackBar('Designer "${record.designername}" deleted');
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Delete failed: $e');
        }
      }
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.normal,
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: GlassTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: GlassTheme.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
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
        borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GlassTheme.accentRose, width: 1.5),
      ),
    );
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Bar
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // 2. Summary Metric Cards
        _buildSummaryStats(),
        const SizedBox(height: 18),

        // 3. In-page Entry Form
        if (_showForm) ...[
          _buildInPageEntryForm(isMobile),
          const SizedBox(height: 20),
        ],

        // 4. Search & Filter Toolbar
        _buildSearchToolbar(),
        const SizedBox(height: 18),

        // 5. Main Content Area
        if (_isLoading && _designers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFE11D48)),
            ),
          )
        else if (_filteredDesigners.isEmpty)
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
                        colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.brush_rounded,
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
                        const Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              "Designer Master",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: GlassTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            StatusBadge(
                              label: "Artisans & Smiths",
                              color: Color(0xFFE11D48),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Manage jewellery designers and link them directly to Smiths & Dealers",
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
                                  ? const Color(0xFFE11D48)
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
                                  ? const Color(0xFFE11D48)
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
                            : const Color(0xFFE11D48),
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
                      label: Text(_showForm ? "Close Form" : "Add Designer"),
                      onPressed: () {
                        if (_showForm) {
                          _closeForm();
                        } else {
                          _openCreateForm();
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
                                  ? const Color(0xFFE11D48)
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
                                  ? const Color(0xFFE11D48)
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
                            : const Color(0xFFE11D48),
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
                      label: Text(_showForm ? "Close Form" : "Add Designer"),
                      onPressed: () {
                        if (_showForm) {
                          _closeForm();
                        } else {
                          _openCreateForm();
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

  // ================= SUMMARY METRICS =================
  Widget _buildSummaryStats() {
    final total = _designers.length;
    final smiths = _designers
        .where((d) => (d.accounttype ?? '').toUpperCase() == 'SMITH')
        .length;
    final dealers = _designers
        .where((d) => (d.accounttype ?? '').toUpperCase() == 'DEALER')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              "Total Designers",
              total.toString(),
              Icons.brush_rounded,
              const Color(0xFFE11D48),
              cardWidth,
            ),
            _buildStatCard(
              "Linked Smiths",
              smiths.toString(),
              Icons.engineering_rounded,
              const Color(0xFFF59E0B),
              cardWidth,
            ),
            _buildStatCard(
              "Linked Dealers",
              dealers.toString(),
              Icons.storefront_rounded,
              const Color(0xFF6366F1),
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
                    fontSize: 18,
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
  Widget _buildInPageEntryForm(bool isMobile) {
    final isEditing = _editingRecord != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.08),
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
            // Form Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFFE11D48),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isEditing
                      ? "Edit Designer (ID: ${_editingRecord!.designerid})"
                      : "Add New Designer",
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

            // Form Fields
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // 1. Account Head Dropdown (Smith / Dealer)
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: _buildAccountHeadField(),
                ),

                // 2. Designer ID (Auto Info)
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: _buildDesignerIdField(),
                ),

                // 3. Designer Name (Unique, VARCHAR 50)
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: _buildDesignerNameField(),
                ),

                // 4. Designer Short Name (VARCHAR 10)
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: _buildDesignerShortNameField(),
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
                    backgroundColor: const Color(0xFFE11D48),
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
                        : (isEditing ? "Update Designer" : "Save Designer"),
                  ),
                  onPressed: _isSaving ? null : _saveDesigner,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHeadField() {
    final bool isSelectedInList =
        _selectedAccode != null &&
        _allDealersAndSmiths.any(
          (d) => d['accode']?.toString() == _selectedAccode,
        );
    final String? effectiveValue = isSelectedInList
        ? _selectedAccode
        : (_allDealersAndSmiths.isNotEmpty
              ? _allDealersAndSmiths.first['accode']?.toString()
              : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Account Head (Smith / Dealer) *",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GlassTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          isExpanded: true,
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: GlassTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration("Select Account Head"),
          items: _allDealersAndSmiths.map((dealer) {
            final code = dealer['accode']?.toString() ?? '';
            final name = dealer['accountname']?.toString() ?? code;
            final type =
                dealer['accounttype']?.toString().toUpperCase() ?? 'DEALER';
            final isSmith = type == 'SMITH';

            return DropdownMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSmith
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSmith
                            ? const Color(0xFFD97706)
                            : const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    ' ($code)',
                    style: const TextStyle(
                      color: GlassTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() => _selectedAccode = val);
          },
          validator: (val) =>
              val == null || val.isEmpty ? "Select an account head" : null,
        ),
        const SizedBox(height: 4),
        const Text(
          "Links by accode only (does not store name directly)",
          style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDesignerIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Designer ID",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GlassTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.tag_rounded, color: Color(0xFFE11D48), size: 18),
              const SizedBox(width: 6),
              Text(
                _editingRecord == null
                    ? "Auto (#)"
                    : "#${_editingRecord!.designerid}",
                style: const TextStyle(
                  color: Color(0xFFE11D48),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesignerNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Designer Name (Unique) *",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GlassTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _designerNameController,
          maxLength: 50,
          style: const TextStyle(
            color: GlassTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration("e.g. Royal Antique Studio, Gold Craft"),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return "Designer name is required";
            }
            if (val.trim().length > 50) {
              return "Maximum 50 characters allowed";
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDesignerShortNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Short Code (Max 10)",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: GlassTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _designerShortNameController,
          maxLength: 10,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_-]')),
          ],
          style: const TextStyle(
            color: Color(0xFF0284C7),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          decoration: _inputDecoration("e.g. RAS, GC01"),
          validator: (val) {
            if (val != null && val.trim().length > 10) {
              return "Max 10 chars";
            }
            return null;
          },
        ),
      ],
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
            width: 280,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: "Search designer, code, smith/dealer...",
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE11D48)),
                ),
              ),
            ),
          ),

          // Account Type Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterChip('ALL', 'All'),
                _buildFilterChip('SMITH', 'Smiths'),
                _buildFilterChip('DEALER', 'Dealers'),
              ],
            ),
          ),

          // Reset Filters Button
          if (_filterAccountType != 'ALL' || _searchQuery.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text("Reset"),
              onPressed: () {
                setState(() {
                  _filterAccountType = 'ALL';
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

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterAccountType == value;
    return InkWell(
      onTap: () {
        setState(() {
          _filterAccountType = value;
          _applyFilter();
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE11D48) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : GlassTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
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
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.brush_rounded,
                size: 44,
                color: Color(0xFFE11D48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? "No Designers Match Your Search"
                  : "No Designers Configured Yet",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: GlassTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query or account type filter."
                  : "Click '+ Add Designer' to create jewellery designer master records linked to Smiths & Dealers.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (!_showForm)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  "Add First Designer",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _openCreateForm,
              ),
          ],
        ),
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
          columnSpacing: 24,
          columns: const [
            DataColumn(
              label: Text(
                "# ID",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "DESIGNER NAME",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "SHORT CODE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "LINKED ACCOUNT HEAD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "ACCOUNT TYPE",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                "ACTIONS",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: GlassTheme.textSecondary,
                ),
              ),
            ),
          ],
          rows: _filteredDesigners.map((d) {
            final isSmith = (d.accounttype ?? '').toUpperCase() == 'SMITH';
            final isDealer = (d.accounttype ?? '').toUpperCase() == 'DEALER';

            return DataRow(
              cells: [
                // ID Badge
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
                      '#${d.designerid ?? "-"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                  ),
                ),

                // Designer Name
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.brush_rounded,
                          size: 14,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        d.designername,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Short Code
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      d.designershortname.isNotEmpty
                          ? d.designershortname
                          : '-',
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),

                // Linked Account Head
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        d.accountname?.isNotEmpty == true
                            ? d.accountname!
                            : d.accode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Code: ${d.accode}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: GlassTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Account Type Badge
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSmith
                          ? const Color(0xFFFEF3C7)
                          : (isDealer
                                ? const Color(0xFFEEF2FF)
                                : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      d.accounttype ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSmith
                            ? const Color(0xFFD97706)
                            : (isDealer
                                  ? const Color(0xFF4F46E5)
                                  : GlassTheme.textSecondary),
                      ),
                    ),
                  ),
                ),

                // Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF0284C7),
                          size: 18,
                        ),
                        tooltip: "Edit Designer",
                        onPressed: () => _openEditForm(d),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: GlassTheme.accentRose,
                          size: 18,
                        ),
                        tooltip: "Delete Designer",
                        onPressed: () => _confirmDelete(d),
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

  // ================= CARD GRID VIEW =================
  Widget _buildCardsGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 300).floor().clamp(1, 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 175,
          ),
          itemCount: _filteredDesigners.length,
          itemBuilder: (context, index) {
            final d = _filteredDesigners[index];
            final isSmith = (d.accounttype ?? '').toUpperCase() == 'SMITH';
            final isDealer = (d.accounttype ?? '').toUpperCase() == 'DEALER';

            return Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.brush_rounded,
                          size: 16,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.designername,
                          style: const TextStyle(
                            color: GlassTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#${d.designerid ?? "-"}',
                          style: const TextStyle(
                            color: GlassTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Short Code: ',
                        style: TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Text(
                          d.designershortname.isNotEmpty
                              ? d.designershortname
                              : '-',
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSmith
                              ? const Color(0xFFFEF3C7)
                              : (isDealer
                                    ? const Color(0xFFEEF2FF)
                                    : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          d.accounttype ?? 'N/A',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSmith
                                ? const Color(0xFFD97706)
                                : (isDealer
                                      ? const Color(0xFF4F46E5)
                                      : GlassTheme.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Linked: ${d.accountname ?? d.accode}',
                    style: const TextStyle(
                      color: GlassTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: Color(0xFF0284C7),
                        ),
                        label: const Text(
                          'Edit',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _openEditForm(d),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color: GlassTheme.accentRose,
                        ),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            color: GlassTheme.accentRose,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _confirmDelete(d),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/tax_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class TaxMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const TaxMasterScreen({super.key, this.onBack});

  @override
  State<TaxMasterScreen> createState() => _TaxMasterScreenState();
}

class _TaxMasterScreenState extends State<TaxMasterScreen> {
  final ApiService _api = ApiService();

  List<TaxRecord> _taxRecords = [];
  List<TaxRecord> _filteredTaxRecords = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  TaxRecord? _editingRecord;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _sgstPerController = TextEditingController(text: '1.50');
  final _cgstPerController = TextEditingController(text: '1.50');
  final _igstPerController = TextEditingController(text: '3.00');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _sgstPerController.dispose();
    _cgstPerController.dispose();
    _igstPerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final records = await _api.getTaxRecords(token);
      if (mounted) {
        setState(() {
          _taxRecords = records;
          _applyFilter(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredTaxRecords = List.from(_taxRecords);
    } else {
      _filteredTaxRecords = _taxRecords.where((t) {
        return t.taxcode.toLowerCase().contains(_searchQuery) ||
            t.taxname.toLowerCase().contains(_searchQuery) ||
            t.sgstPer.toString().contains(_searchQuery) ||
            t.cgstPer.toString().contains(_searchQuery) ||
            t.igstPer.toString().contains(_searchQuery);
      }).toList();
    }
  }

  void _openForm([TaxRecord? existing]) {
    setState(() {
      _editingRecord = existing;
      _showForm = true;
      if (existing != null) {
        _codeController.text = existing.taxcode;
        _nameController.text = existing.taxname;
        _sgstPerController.text = existing.sgstPer.toStringAsFixed(2);
        _cgstPerController.text = existing.cgstPer.toStringAsFixed(2);
        _igstPerController.text = existing.igstPer.toStringAsFixed(2);
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _codeController.clear();
    _nameController.clear();
    _sgstPerController.text = '1.50';
    _cgstPerController.text = '1.50';
    _igstPerController.text = '3.00';
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingRecord = null;
      _resetFormFields();
    });
  }

  void _autoCalculateIgst() {
    final sgst = double.tryParse(_sgstPerController.text.trim()) ?? 0.0;
    final cgst = double.tryParse(_cgstPerController.text.trim()) ?? 0.0;
    _igstPerController.text = (sgst + cgst).toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _saveTaxForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final code = _codeController.text.trim().toUpperCase();
      final name = _nameController.text.trim();
      final sgst = double.tryParse(_sgstPerController.text.trim()) ?? 0.0;
      final cgst = double.tryParse(_cgstPerController.text.trim()) ?? 0.0;
      final igst = double.tryParse(_igstPerController.text.trim()) ?? (sgst + cgst);

      final record = TaxRecord(
        taxcode: code,
        taxname: name,
        sgstPer: sgst,
        cgstPer: cgst,
        igstPer: igst,
      );

      final isEditing = _editingRecord != null && _editingRecord!.taxid != null;
      final response = isEditing
          ? await _api.updateTaxRecord(token, _editingRecord!.taxid!, record)
          : await _api.createTaxRecord(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? "Tax Rule '$code' updated successfully!" : "Tax Rule '$code' created successfully!",
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
              content: Text(response['message']?.toString() ?? "Failed to save tax config"),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, auth),
        const SizedBox(height: 16),

        // In-Page Create / Edit Form
        if (_showForm) ...[
          _buildTaxForm(context, auth, isMobile),
          const SizedBox(height: 20),
        ],

        // Search & View Toggle Toolbar
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Data View
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(60.0),
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
          )
        else if (_filteredTaxRecords.isEmpty)
          _buildEmptyState(context, auth)
        else if (_isTableView)
          _buildTableView(context, auth)
        else
          _buildCardsGridView(context, auth, isMobile),
      ],
    );
  }

  // ================= HEADER & BREADCRUMB =================
  Widget _buildHeader(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Back to Master Hub",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.percent_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tax Master (GST Rates)",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: GlassTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Master Hub > Tax Master",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),

          // Create Tax Config Button & Table Switcher
          Row(
            children: [
              IconButton(
                icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded, color: GlassTheme.textSecondary),
                tooltip: _isTableView ? "Switch to Card View" : "Switch to Table View",
                onPressed: () => setState(() => _isTableView = !_isTableView),
              ),
              const SizedBox(width: 8),
              if (!_showForm)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text("New Tax Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _openForm(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= IN-PAGE ENTRY FORM =================
  Widget _buildTaxForm(BuildContext context, AuthProvider auth, bool isMobile) {
    final isEditing = _editingRecord != null;
    final double sgstVal = double.tryParse(_sgstPerController.text) ?? 0.0;
    final double cgstVal = double.tryParse(_cgstPerController.text) ?? 0.0;
    final double igstVal = double.tryParse(_igstPerController.text) ?? (sgstVal + cgstVal);
    final double totalRate = igstVal > 0 ? igstVal : (sgstVal + cgstVal);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? "Edit Tax Rule (${_editingRecord!.taxcode})" : "Create New Tax Rate Rule",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Define GST rates for jewellery items, stones, making charges, or exempt goods.",
                        style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Cancel and Close Form",
                  onPressed: _closeForm,
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFE2E8F0)),

            // Section 1: Basic Information
            Wrap(
              spacing: 16,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tax Code * (Max 3)",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeController,
                        maxLength: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          TextInputFormatter.withFunction(
                            (oldVal, newVal) => newVal.copyWith(text: newVal.text.toUpperCase()),
                          ),
                        ],
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                        decoration: _inputDecoration("e.g. G03").copyWith(counterText: ""),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Code required";
                          if (val.trim().length > 3) return "Max 3 chars";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tax Rule Description / Name *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: _inputDecoration("e.g. GST 3.00% (Gold & Silver Jewellery)"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Tax Name is required";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Section 2: GST Rate Breakdown
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calculate_rounded, color: Color(0xFF10B981), size: 20),
                          SizedBox(width: 8),
                          Text(
                            "GST Percentage Breakdown",
                            style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Total GST: ${totalRate.toStringAsFixed(2)}%",
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: isMobile ? double.infinity : 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SGST Rate % *", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _sgstPerController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("1.50"),
                              onChanged: (_) => _autoCalculateIgst(),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return "Required";
                                if (double.tryParse(val) == null) return "Invalid";
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CGST Rate % *", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _cgstPerController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("1.50"),
                              onChanged: (_) => _autoCalculateIgst(),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return "Required";
                                if (double.tryParse(val) == null) return "Invalid";
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("IGST Rate % (Inter-state)", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _igstPerController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("3.00"),
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return "Required";
                                if (double.tryParse(val) == null) return "Invalid";
                                return null;
                              },
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
                GlassSecondaryButton(
                  label: "Cancel",
                  onPressed: _closeForm,
                ),
                const SizedBox(width: 12),
                GlassButton(
                  label: isEditing ? "Update Tax Rate" : "Save Tax Rate",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  isLoading: _isSaving,
                  onPressed: _saveTaxForm,
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
      hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 13, fontWeight: FontWeight.normal),
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
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2.0),
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
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: GlassTheme.textSecondary, size: 20),
                hintText: "Search tax rules by code, description, or rates...",
                hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: GlassTheme.textSecondary, size: 18),
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
              child: const Icon(Icons.percent_rounded, size: 48, color: GlassTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching tax rates found" : "No Tax Master rules configured yet",
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query."
                  : "Get started by adding your GST tax slabs (e.g. GST 3%, GST 18%, Exempt).",
              style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Create Tax Rule", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _openForm(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================= CARD GRID VIEW =================
  Widget _buildCardsGridView(BuildContext context, AuthProvider auth, bool isMobile) {
    final double cardWidth = isMobile ? 320 : 360;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _filteredTaxRecords.map((tax) {
            final totalRate = tax.igstPer > 0 ? tax.igstPer : (tax.sgstPer + tax.cgstPer);

            return SizedBox(
              width: isMobile ? constraints.maxWidth : cardWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
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
                            tax.taxname,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: tax.taxcode, color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),

                    // Tax Rates
                    _buildTaxRateRow("SGST Rate", "${tax.sgstPer.toStringAsFixed(2)}%"),
                    const SizedBox(height: 6),
                    _buildTaxRateRow("CGST Rate", "${tax.cgstPer.toStringAsFixed(2)}%"),
                    const SizedBox(height: 6),
                    _buildTaxRateRow("IGST Rate", "${tax.igstPer.toStringAsFixed(2)}%"),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Effective Total GST", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF047857))),
                          Text("${totalRate.toStringAsFixed(2)}%", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF047857))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 20),
                          tooltip: "Edit",
                          onPressed: () => _openForm(tax),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 20),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(tax),
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

  Widget _buildTaxRateRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
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
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
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
              DataColumn(label: Text("CODE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("TAX DESCRIPTION / NAME", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("SGST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("CGST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("IGST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("TOTAL GST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
            ],
            rows: _filteredTaxRecords.map((tax) {
              final totalRate = tax.igstPer > 0 ? tax.igstPer : (tax.sgstPer + tax.cgstPer);

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tax.taxcode, style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                  ),
                  DataCell(Text(tax.taxname, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(Text("${tax.sgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(Text("${tax.cgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(Text("${tax.igstPer.toStringAsFixed(2)}%", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${totalRate.toStringAsFixed(2)}%",
                        style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 18),
                          tooltip: "Edit",
                          onPressed: () => _openForm(tax),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(tax),
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
  void _confirmDelete(TaxRecord tax) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose, size: 24),
            SizedBox(width: 8),
            Text(
              "Delete Tax Config",
              style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete tax configuration '${tax.taxcode} - ${tax.taxname}'?",
          style: const TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (tax.taxid == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteTaxRecord(token, tax.taxid!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? "Tax record deleted"),
                    backgroundColor: isOk ? GlassTheme.accentEmerald : GlassTheme.accentRose,
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

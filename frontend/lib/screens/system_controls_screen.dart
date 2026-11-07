import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/system_control_model.dart';
import '../models/branch_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class SystemControlsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SystemControlsScreen({super.key, this.onBack});

  @override
  State<SystemControlsScreen> createState() => _SystemControlsScreenState();
}

class _SystemControlsScreenState extends State<SystemControlsScreen> {
  final ApiService _api = ApiService();

  List<SystemControlRecord> _controls = [];
  List<SystemControlRecord> _filteredControls = [];
  List<Branch> _branches = [];

  bool _isLoading = false;
  String _searchQuery = '';
  String _moduleFilter = 'ALL';
  bool _isTableView = false;

  int _lastSno = 0;
  int _nextSno = 1;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  SystemControlRecord? _editingControl;
  final _formKey = GlobalKey<FormState>();

  final _ctlidController = TextEditingController();
  final _ctlnameController = TextEditingController();
  final _ctlvalueController = TextEditingController();
  String _selectedModule = 'POS';
  String _selectedBranchId = 'ALL';
  bool _isSaving = false;

  final List<String> _moduleOptions = [
    'MASTER',
    'STOCK',
    'POS',
    'REPORTS',
    'DIGIGOLD',
    'CRM',
    'SETTINGS',
    'GENERAL',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ctlidController.dispose();
    _ctlnameController.dispose();
    _ctlvalueController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getSystemControlsData(token),
        _api.getBranches(token, companyId: auth.activeCompanyId),
      ]);

      if (mounted) {
        final controlsData = results[0] as Map<String, dynamic>;
        final branchesList = results[1] as List<Branch>;

        setState(() {
          _controls =
              controlsData['controls'] as List<SystemControlRecord>? ?? [];
          _lastSno =
              int.tryParse(controlsData['last_sno']?.toString() ?? '0') ?? 0;
          _nextSno =
              int.tryParse(controlsData['next_sno']?.toString() ?? '1') ?? 1;
          _branches = branchesList;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading system controls: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredControls = _controls.where((c) {
      final matchesModule =
          _moduleFilter == 'ALL' || c.module.toUpperCase() == _moduleFilter;
      if (!matchesModule) return false;

      if (query.isEmpty) return true;
      return c.ctlid.toLowerCase().contains(query) ||
          c.ctlname.toLowerCase().contains(query) ||
          c.ctlvalue.toLowerCase().contains(query) ||
          c.sno.toString().contains(query) ||
          c.module.toLowerCase().contains(query) ||
          c.branchId.toLowerCase().contains(query) ||
          (c.branchname ?? '').toLowerCase().contains(query);
    }).toList();
  }

  void _openForm([SystemControlRecord? existing]) {
    setState(() {
      _editingControl = existing;
      _showForm = true;
      if (existing != null) {
        _ctlidController.text = existing.ctlid;
        _ctlnameController.text = existing.ctlname;
        _ctlvalueController.text = existing.ctlvalue;
        _selectedModule = _moduleOptions.contains(existing.module.toUpperCase())
            ? existing.module.toUpperCase()
            : 'GENERAL';
        _selectedBranchId = existing.branchId;
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _ctlidController.clear();
    _ctlnameController.clear();
    _ctlvalueController.clear();
    _selectedModule = 'POS';
    _selectedBranchId = 'ALL';
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingControl = null;
      _resetFormFields();
    });
  }

  Future<void> _saveSystemControlForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final ctlid = _ctlidController.text.trim().toUpperCase();
      final ctlname = _ctlnameController.text.trim();
      final ctlvalue = _ctlvalueController.text.trim();

      final record = SystemControlRecord(
        sno: _editingControl?.sno,
        ctlid: ctlid,
        ctlname: ctlname,
        ctlvalue: ctlvalue,
        module: _selectedModule,
        branchId: _selectedBranchId,
      );

      final isEditing = _editingControl != null && _editingControl!.sno != null;
      final response = isEditing
          ? await _api.updateSystemControl(token, _editingControl!.sno!, record)
          : await _api.createSystemControl(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? "Control '$ctlid' updated successfully!"
                    : "Control '$ctlid' created successfully!",
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
                response['message']?.toString() ?? "Failed to save control",
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

        // Module Filter Chips & Search Toolbar
        _buildFilterToolbar(isMobile),
        const SizedBox(height: 16),

        // Body
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: GlassTheme.primaryNeon),
            ),
          )
        else if (_filteredControls.isEmpty)
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
                  tooltip: "Back to Settings Menu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.tune_rounded,
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
                        "System Controls",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(
                        label: "Settings 4th Menu",
                        color: Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Configure module runtime parameters, global defaults, and branch-specific business flags",
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
                tooltip: "Reload Controls",
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm
                      ? const Color(0xFF334155)
                      : const Color(0xFFF59E0B),
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
                  _showForm ? "Close Form" : "Add Control",
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
    final isEditing = _editingControl != null;
    final displaySno = isEditing ? _editingControl!.sno : _nextSno;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
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
            // Top Bar with SNo indicators
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.tune_rounded,
                    color: const Color(0xFFF59E0B),
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
                                ? "Edit System Control (SNo: #$displaySno - ${_editingControl!.ctlid})"
                                : "Create System Control",
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
                                0xFFF59E0B,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isEditing
                                  ? "SNo: #$displaySno"
                                  : "Next SNo: #$_nextSno",
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (!isEditing && _lastSno > 0) ...[
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
                                "Last SNo: #$_lastSno",
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
                        "Set system behavior flags, module calculation formulas, or branch-specific billing parameters",
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

            // Row 1: SNo (Auto), Control ID (ctlid), Module Dropdown, Branch Dropdown
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                // 1. SNo Display (Autogenerated)
                SizedBox(
                  width: isMobile ? double.infinity : 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "S.No (Auto)",
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
                              "#$displaySno",
                              style: const TextStyle(
                                color: Color(0xFFD97706),
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

                // 2. Control ID (ctlid - VARCHAR 30)
                SizedBox(
                  width: isMobile ? double.infinity : 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Control ID * (ctlid: max 30)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ctlidController,
                        maxLength: 30,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: _inputDecoration(
                          "e.g. ENABLE_BARCODE_TAG",
                        ).copyWith(counterText: ""),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Control ID is required";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // 3. Module Dropdown (for which main menu)
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Target Module * (module)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedModule,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Module"),
                        items: _moduleOptions.map((mod) {
                          return DropdownMenuItem(
                            value: mod,
                            child: Text(
                              mod,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedModule = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 4. Branch Dropdown (from branch master)
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Branch Scope * (branch master)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBranchId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Branch"),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: 'ALL',
                            child: Text(
                              "ALL BRANCHES (Global Default)",
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          ..._branches.map((b) {
                            return DropdownMenuItem(
                              value: b.branchId,
                              child: Text(
                                "${b.branchId} - ${b.branchName}",
                                style: const TextStyle(
                                  color: GlassTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBranchId = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 2: Control Name (ctlname - VARCHAR 150)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Control Name / Description * (ctlname: max 150)",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _ctlnameController,
                  maxLength: 150,
                  style: const TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration(
                    "e.g. Auto-Calculate Round-Off on Invoice Net Amount",
                  ).copyWith(counterText: ""),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Control Name is required";
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 3: Control Value (ctlvalue - VARCHAR 500)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Control Value / Configuration * (ctlvalue: max 500)",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _ctlvalueController,
                  maxLength: 500,
                  maxLines: 2,
                  style: const TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _inputDecoration(
                    "e.g. YES, 5.0, NEAREST_10, or configuration string/JSON",
                  ).copyWith(counterText: ""),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Control Value is required";
                    }
                    return null;
                  },
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
                  label: isEditing ? "Update Control" : "Save Control",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  isLoading: _isSaving,
                  onPressed: _saveSystemControlForm,
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
        borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GlassTheme.accentRose, width: 1.5),
      ),
    );
  }

  // ================= FILTER & SEARCH TOOLBAR =================
  Widget _buildFilterToolbar(bool isMobile) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("ALL", "All Modules"),
                const SizedBox(width: 8),
                ..._moduleOptions.map((mod) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(mod, mod),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          TextField(
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
                  "Search controls by SNo, Control ID, Name, Value, Module, or Branch...",
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
                  color: Color(0xFFF59E0B),
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
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _moduleFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isSelected ? Colors.white : GlassTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFF59E0B),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _moduleFilter = value;
            _applyFilter();
          });
        }
      },
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
                Icons.tune_rounded,
                size: 48,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching system controls found"
                  : "No System Controls configured yet",
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query or module filter."
                  : "Add runtime configuration parameters and business rule flags for your store.",
              style: const TextStyle(
                color: GlassTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty && _moduleFilter == 'ALL') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
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
                  "Create Control",
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
          children: _filteredControls.map((ctl) {
            final branchDisplay = ctl.branchId == 'ALL'
                ? 'ALL BRANCHES (Global)'
                : (ctl.branchname ?? ctl.branchId);

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ctl.ctlid,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD97706),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ctl.ctlname,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: GlassTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: "SNo: #${ctl.sno ?? '-'}",
                          color: const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    // Value Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CONTROL VALUE",
                            style: TextStyle(
                              fontSize: 10,
                              color: GlassTheme.textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ctl.ctlvalue,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: GlassTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildInfoRow("Target Module", ctl.module),
                    const SizedBox(height: 6),
                    _buildInfoRow("Branch Scope", branchDisplay),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                          tooltip: "Edit Control",
                          onPressed: () => _openForm(ctl),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          tooltip: "Delete Control",
                          onPressed: () => _confirmDelete(ctl),
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
                  "SNO",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CTL ID",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CONTROL NAME",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CONTROL VALUE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "MODULE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "BRANCH",
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
            rows: _filteredControls.map((ctl) {
              final branchDisplay = ctl.branchId == 'ALL'
                  ? 'ALL (Global)'
                  : (ctl.branchname ?? ctl.branchId);

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      "#${ctl.sno ?? '-'}",
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      ctl.ctlid,
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      ctl.ctlname,
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ctl.ctlvalue,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ctl.module,
                        style: const TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      branchDisplay,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
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
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          tooltip: "Edit",
                          onPressed: () => _openForm(ctl),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 18,
                          ),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(ctl),
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
  void _confirmDelete(SystemControlRecord ctl) {
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
              "Delete System Control",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete system control '#${ctl.sno} - ${ctl.ctlid} (${ctl.ctlname})'?",
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
              if (ctl.sno == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteSystemControl(token, ctl.sno!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? "System Control deleted",
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/branch_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/menu_tree_view.dart';

class UserMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const UserMasterScreen({super.key, this.onBack});

  @override
  State<UserMasterScreen> createState() => _UserMasterScreenState();
}

class _UserMasterScreenState extends State<UserMasterScreen> {
  final ApiService _api = ApiService();

  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  List<Branch> _dbBranches = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  // Filter States
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE
  String _centLoginFilter = 'ALL'; // ALL, YES, NO
  final String _branchFilter = 'ALL'; // ALL or branchId

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  AppUser? _editingUser;
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedBranchId = '';
  bool _isActive = true;
  bool _isCentLogin = false;
  bool _obscurePassword = true;
  bool _showRightsInForm = false;
  List<String> _formSelectedMenus = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getUsers(token),
      _api.getBranches(token, companyId: auth.activeCompanyId),
    ]);

    if (mounted) {
      setState(() {
        _users = results[0] as List<AppUser>;
        _dbBranches = results[1] as List<Branch>;
        _applyFilter();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredUsers = _users.where((u) {
      final matchesSearch =
          query.isEmpty ||
          u.userId.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.branchId.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_statusFilter == 'ACTIVE' && !u.isActive) return false;
      if (_statusFilter == 'INACTIVE' && u.isActive) return false;

      if (_centLoginFilter == 'YES' && !u.isCentralLogin) return false;
      if (_centLoginFilter == 'NO' && u.isCentralLogin) return false;

      if (_branchFilter != 'ALL' &&
          u.branchId.toUpperCase() != _branchFilter.toUpperCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  String _getBranchName(String branchId) {
    if (branchId.isEmpty) return 'Global / All Branches';
    final match = _dbBranches
        .where((b) => b.branchId.toUpperCase() == branchId.toUpperCase())
        .firstOrNull;
    return match != null ? "${match.branchId} - ${match.branchName}" : branchId;
  }

  void _openForm([AppUser? existing]) {
    setState(() {
      _editingUser = existing;
      _showForm = true;
      _showRightsInForm = false;
      if (existing != null) {
        _idController.text = existing.userId;
        _nameController.text = existing.username;
        _emailController.text = existing.email;
        _passwordController.clear();
        _selectedBranchId = existing.branchId;
        _isActive = existing.isActive;
        _isCentLogin = existing.isCentralLogin;
        _formSelectedMenus = List.from(existing.allowedMenus);
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _idController.clear();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _selectedBranchId = _dbBranches.isNotEmpty
        ? _dbBranches.first.branchId
        : '';
    _isActive = true;
    _isCentLogin = false;
    _obscurePassword = true;
    _showRightsInForm = false;
    _formSelectedMenus = List.from(MenuTreeRegistry.allLeafCodes);
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingUser = null;
      _resetFormFields();
    });
  }

  Future<void> _saveUserForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final isEditing = _editingUser != null;
      final userId = _idController.text.trim().toUpperCase();
      final username = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      Map<String, dynamic> response;
      if (isEditing) {
        final updatedUser = _editingUser!.copyWith(
          username: username,
          email: email,
          branchId: _selectedBranchId,
          isActive: _isActive,
          centlogin: _isCentLogin ? 'YES' : 'NO',
          allowedMenus: _formSelectedMenus,
        );
        response = await _api.updateUser(
          token,
          _editingUser!.userId,
          updatedUser,
        );
      } else {
        final newUser = AppUser(
          userId: userId,
          username: username,
          email: email,
          branchId: _selectedBranchId,
          isActive: _isActive,
          centlogin: _isCentLogin ? 'YES' : 'NO',
          allowedMenus: _formSelectedMenus,
        );
        response = await _api.createUser(token, newUser, password);
      }

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? "User '$username' updated successfully!"
                    : "User '$username' created successfully!",
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
                response['message']?.toString() ?? "Failed to save user",
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
        // 1. Header Bar
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // 2. Embedded In-Page Form
        if (_showForm) ...[
          _buildInPageEntryForm(isMobile),
          const SizedBox(height: 20),
        ],

        // 3. Quick Metrics Row
        _buildMetricsRow(isMobile),
        const SizedBox(height: 16),

        // 4. Search & Filter Toolbar
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // 5. Main Content Area
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: GlassTheme.primaryNeon),
            ),
          )
        else if (_filteredUsers.isEmpty)
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
                  tooltip: "Back to Master Menu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: GlassTheme.cyanGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.accentCyan.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
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
                        "User Master & Security",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(
                        label: "Access Control",
                        color: GlassTheme.accentCyan,
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manage login accounts, central login & .NET tree view menu permissions",
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
                          size: 18,
                          color: !_isTableView
                              ? GlassTheme.primaryNeon
                              : GlassTheme.textMuted,
                        ),
                        tooltip: "Card View",
                        onPressed: () => setState(() => _isTableView = false),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.table_rows_rounded,
                          size: 18,
                          color: _isTableView
                              ? GlassTheme.primaryNeon
                              : GlassTheme.textMuted,
                        ),
                        tooltip: "Table View",
                        onPressed: () => setState(() => _isTableView = true),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Refresh List",
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: GlassTheme.textPrimary,
                ),
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm
                      ? const Color(0xFF334155)
                      : GlassTheme.primaryNeon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  _showForm ? Icons.close_rounded : Icons.person_add_rounded,
                  size: 18,
                ),
                label: Text(
                  _showForm ? "Close Form" : "New User",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
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

  // ================= METRICS ROW =================
  Widget _buildMetricsRow(bool isMobile) {
    final total = _users.length;
    final active = _users.where((u) => u.isActive).length;
    final central = _users.where((u) => u.isCentralLogin).length;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            "Total Users",
            "$total",
            Icons.group_rounded,
            GlassTheme.primaryNeon,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            "Active Logins",
            "$active",
            Icons.check_circle_rounded,
            GlassTheme.accentEmerald,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            "Central Logins",
            "$central",
            Icons.hub_rounded,
            GlassTheme.accentCyan,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: GlassTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
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

  // ================= IN-PAGE ENTRY FORM COMPONENT =================
  Widget _buildInPageEntryForm(bool isMobile) {
    final isEditing = _editingUser != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: GlassTheme.primaryNeon.withValues(alpha: 0.5),
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
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlassTheme.primaryNeon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing
                        ? Icons.manage_accounts_rounded
                        : Icons.person_add_rounded,
                    color: GlassTheme.primaryNeon,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing
                            ? "Edit Operator Login (${_editingUser!.userId} - ${_editingUser!.username})"
                            : "Create New Operator Account",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing
                            ? "Update login username, branch, and menu access rights"
                            : "Define operator login ID, secure password, branch assignment, and permission access",
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

            // Row 1: User ID & Full Name & Email
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "User ID (Login Key) *",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _idController,
                        enabled: !isEditing,
                        style: TextStyle(
                          color: !isEditing
                              ? GlassTheme.textPrimary
                              : GlassTheme.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. USR01, CASHIER1"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "ID required";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Full Name / Title *",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration(
                          "e.g. Rajesh Kumar (Store Mgr)",
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Name required";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Email Address",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("user@progold.com"),
                      ),
                    ],
                  ),
                ),
                if (!isEditing)
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Login Password *",
                          style: TextStyle(
                            color: GlassTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            color: GlassTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: "Enter password",
                            hintStyle: const TextStyle(
                              color: GlassTheme.textMuted,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                                color: GlassTheme.textSecondary,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: GlassTheme.primaryNeon,
                                width: 2.0,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.length < 4) {
                              return "Min 4 chars";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Row 2: Branch & Toggles
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Assigned Branch",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _dbBranches.any(
                              (b) => b.branchId == _selectedBranchId,
                            )
                            ? _selectedBranchId
                            : (_dbBranches.isNotEmpty
                                  ? _dbBranches.first.branchId
                                  : ''),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Branch"),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text(
                              "Global / All Branches",
                              style: TextStyle(
                                color: GlassTheme.primaryNeon,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ..._dbBranches.map((b) {
                            return DropdownMenuItem(
                              value: b.branchId,
                              child: Text(
                                "${b.branchName} (${b.branchId})",
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
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Active Status",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
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
                              _isActive ? "ACTIVE" : "INACTIVE",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _isActive
                                    ? GlassTheme.accentEmerald
                                    : GlassTheme.accentRose,
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              activeThumbColor: GlassTheme.accentEmerald,
                              onChanged: (val) =>
                                  setState(() => _isActive = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Central Login Access",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
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
                              _isCentLogin ? "ENABLED" : "DISABLED",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _isCentLogin
                                    ? GlassTheme.accentCyan
                                    : GlassTheme.textMuted,
                              ),
                            ),
                            Switch(
                              value: _isCentLogin,
                              activeThumbColor: GlassTheme.accentCyan,
                              onChanged: (val) =>
                                  setState(() => _isCentLogin = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Menu Permissions",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GlassTheme.primaryNeon,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          _showRightsInForm
                              ? Icons.expand_less_rounded
                              : Icons.account_tree_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _showRightsInForm
                              ? "Hide Tree Rights"
                              : "Configure Tree Rights (${_formSelectedMenus.length})",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => setState(
                          () => _showRightsInForm = !_showRightsInForm,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Embedded Menu Tree View if expanded
            if (_showRightsInForm) ...[
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: MenuPermissionsTreeView(
                  initialSelectedMenus: _formSelectedMenus,
                  onPermissionsChanged: (newCodes) =>
                      setState(() => _formSelectedMenus = newCodes),
                ),
              ),
            ],

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
                  label: isEditing ? "Update User" : "Save User",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: GlassTheme.primaryGradient,
                  isLoading: _isSaving,
                  onPressed: _saveUserForm,
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
        borderSide: const BorderSide(color: GlassTheme.primaryNeon, width: 2.0),
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
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 320,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                setState(() => _applyFilter());
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
                hintText: "Search by ID, name, email...",
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
                    color: GlassTheme.primaryNeon,
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
                          _searchQuery = '';
                          setState(() => _applyFilter());
                        },
                      )
                    : null,
              ),
            ),
          ),
          DropdownButton<String>(
            value: _statusFilter,
            dropdownColor: Colors.white,
            style: const TextStyle(
              color: GlassTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text("Status: All")),
              DropdownMenuItem(
                value: 'ACTIVE',
                child: Text("Status: Active Only"),
              ),
              DropdownMenuItem(
                value: 'INACTIVE',
                child: Text("Status: Inactive Only"),
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
          DropdownButton<String>(
            value: _centLoginFilter,
            dropdownColor: Colors.white,
            style: const TextStyle(
              color: GlassTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text("Central: All")),
              DropdownMenuItem(value: 'YES', child: Text("Central: Yes")),
              DropdownMenuItem(value: 'NO', child: Text("Central: No")),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _centLoginFilter = val;
                  _applyFilter();
                });
              }
            },
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
                Icons.admin_panel_settings_rounded,
                size: 48,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching operators found"
                  : "No Operator Users registered yet",
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query or status filter."
                  : "Get started by adding login accounts for your billing operators and store managers.",
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
                  backgroundColor: GlassTheme.primaryNeon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text(
                  "Create First User",
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
          children: _filteredUsers.map((u) {
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
                            u.username,
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
                          label: u.isActive ? "ACTIVE" : "INACTIVE",
                          color: u.isActive
                              ? GlassTheme.accentEmerald
                              : GlassTheme.accentRose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow("Login ID", u.userId),
                    const SizedBox(height: 6),
                    _buildInfoRow("Branch", _getBranchName(u.branchId)),
                    const SizedBox(height: 6),
                    _buildInfoRow("Email", u.email.isNotEmpty ? u.email : "-"),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Central Login",
                      u.isCentralLogin
                          ? "Yes (Global)"
                          : "No (Branch Restricted)",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Menus Assigned",
                      "${u.allowedMenus.length} features",
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
                          tooltip: "Edit User & Rights",
                          onPressed: () => _openForm(u),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.password_rounded,
                            color: GlassTheme.accentAmber,
                            size: 20,
                          ),
                          tooltip: "Reset Password",
                          onPressed: () => _showPasswordResetDialog(u),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          tooltip: "Delete User",
                          onPressed: () => _confirmDelete(u),
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
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: GlassTheme.textPrimary,
            fontWeight: FontWeight.w800,
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
                  "USER ID",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "USERNAME",
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
                  "EMAIL",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CENTRAL",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "STATUS",
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
            rows: _filteredUsers.map((u) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      u.userId,
                      style: const TextStyle(
                        color: GlassTheme.primaryNeon,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      u.username,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _getBranchName(u.branchId),
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      u.email.isNotEmpty ? u.email : "-",
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      u.isCentralLogin ? "Yes" : "No",
                      style: TextStyle(
                        color: u.isCentralLogin
                            ? GlassTheme.accentCyan
                            : GlassTheme.textMuted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    StatusBadge(
                      label: u.isActive ? "Active" : "Inactive",
                      color: u.isActive
                          ? GlassTheme.accentEmerald
                          : GlassTheme.accentRose,
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
                          onPressed: () => _openForm(u),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.password_rounded,
                            color: GlassTheme.accentAmber,
                            size: 18,
                          ),
                          tooltip: "Reset Password",
                          onPressed: () => _showPasswordResetDialog(u),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 18,
                          ),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(u),
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

  // ================= PASSWORD RESET MODAL =================
  void _showPasswordResetDialog(AppUser user) {
    final passCtrl = TextEditingController();
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.lock_reset_rounded,
                color: GlassTheme.accentAmber,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                "Reset Password: ${user.username}",
                style: const TextStyle(
                  color: GlassTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter new password for this operator:",
                style: TextStyle(
                  color: GlassTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(
                  color: GlassTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: "New password (min 4 chars)",
                  hintStyle: const TextStyle(
                    color: GlassTheme.textMuted,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ],
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
                backgroundColor: GlassTheme.accentAmber,
                foregroundColor: Colors.white,
              ),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Update Password",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
              onPressed: () async {
                final newPass = passCtrl.text.trim();
                if (newPass.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password must be at least 4 characters"),
                    ),
                  );
                  return;
                }
                setDlgState(() => saving = true);
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final token = auth.authToken;
                if (token != null) {
                  final res = await _api.changeUserPassword(
                    token,
                    user.userId,
                    newPass,
                  );
                  if (mounted) {
                    final isOk = res['success'] == true;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          res['message']?.toString() ?? "Password updated",
                        ),
                        backgroundColor: isOk
                            ? GlassTheme.accentEmerald
                            : GlassTheme.accentRose,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= DELETE CONFIRMATION =================
  void _confirmDelete(AppUser user) {
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
              "Delete Operator User",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete user '${user.userId} - ${user.username}'?",
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
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteUser(token, user.userId);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? "User deleted"),
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

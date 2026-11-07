import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/branch_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/menu_tree_view.dart';

class UserMenuRightsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final String? initialSelectedUserId;

  const UserMenuRightsScreen({
    super.key,
    this.onBack,
    this.initialSelectedUserId,
  });

  @override
  State<UserMenuRightsScreen> createState() => _UserMenuRightsScreenState();
}

class _UserMenuRightsScreenState extends State<UserMenuRightsScreen> {
  final ApiService _api = ApiService();

  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  List<Branch> _dbBranches = [];
  bool _isLoading = false;
  bool _isSaving = false;

  AppUser? _selectedUser;
  List<String> _currentSelectedMenus = [];
  bool _hasUnsavedChanges = false;

  String _userSearch = '';
  final String _branchFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final usersList = results[0] as List<AppUser>;
      final branchesList = results[1] as List<Branch>;

      AppUser? initialUser;
      if (widget.initialSelectedUserId != null) {
        initialUser = usersList.firstWhere(
          (u) =>
              u.userId.toUpperCase() ==
              widget.initialSelectedUserId!.toUpperCase(),
          orElse: () =>
              usersList.isNotEmpty ? usersList.first : usersList.first,
        );
      } else if (usersList.isNotEmpty) {
        initialUser = usersList.first;
      }

      setState(() {
        _users = usersList;
        _dbBranches = branchesList;
        _applyUserFilter();
        if (initialUser != null) {
          _selectUser(initialUser);
        }
        _isLoading = false;
      });
    }
  }

  void _applyUserFilter() {
    final query = _userSearch.trim().toLowerCase();
    _filteredUsers = _users.where((u) {
      final matchesSearch =
          query.isEmpty ||
          u.userId.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.branchId.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_branchFilter != 'ALL' &&
          u.branchId.toUpperCase() != _branchFilter.toUpperCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  void _selectUser(AppUser user) {
    setState(() {
      _selectedUser = user;
      _currentSelectedMenus = List.from(user.allowedMenus);
      _hasUnsavedChanges = false;
    });
  }

  String _getBranchName(String branchId) {
    if (branchId.isEmpty) return 'Global / All Branches';
    final match = _dbBranches.firstWhere(
      (b) => b.branchId.toUpperCase() == branchId.toUpperCase(),
      orElse: () =>
          Branch(branchId: branchId, branchName: branchId, companyId: ''),
    );
    return "${match.branchId} - ${match.branchName}";
  }

  Future<void> _saveCurrentPermissions() async {
    if (_selectedUser == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    final updatedUser = _selectedUser!.copyWith(
      allowedMenus: _currentSelectedMenus,
    );

    final res = await _api.updateUser(
      token,
      _selectedUser!.userId,
      updatedUser,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        // Update local state in list
        final index = _users.indexWhere(
          (u) => u.userId == _selectedUser!.userId,
        );
        if (index != -1) {
          _users[index] = updatedUser;
          _applyUserFilter();
        }
        setState(() {
          _selectedUser = updatedUser;
          _hasUnsavedChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  "Menu rights updated for ${_selectedUser!.username} (${_selectedUser!.userId})",
                ),
              ],
            ),
            backgroundColor: GlassTheme.accentEmerald,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Failed to save permissions"),
            backgroundColor: GlassTheme.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCopyPermissionsDialog() {
    if (_selectedUser == null) return;
    AppUser? sourceUser;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setCopyState) {
            final otherUsers = _users
                .where((u) => u.userId != _selectedUser!.userId)
                .toList();

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.copy_all_rounded,
                    color: GlassTheme.primaryNeon,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Copy Menu Rights From User",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Copy all assigned menu rights from an existing user into ${_selectedUser!.username} (${_selectedUser!.userId}):",
                    style: const TextStyle(
                      fontSize: 13,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AppUser>(
                    initialValue: sourceUser,
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Source User",
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: GlassTheme.primaryNeon,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: otherUsers.map((u) {
                      return DropdownMenuItem(
                        value: u,
                        child: Text(
                          "${u.userId} - ${u.username} (${u.allowedMenus.length} Menus)",
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setCopyState(() => sourceUser = val);
                    },
                  ),
                  if (sourceUser != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: GlassTheme.primaryNeon,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Will copy ${sourceUser!.allowedMenus.length} menu permissions from ${sourceUser!.username}.",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: GlassTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.primaryNeon,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: sourceUser == null
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          setState(() {
                            _currentSelectedMenus = List.from(
                              sourceUser!.allowedMenus,
                            );
                            _hasUnsavedChanges = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Permissions copied from ${sourceUser!.username}. Click 'Save Permissions' to persist.",
                              ),
                              backgroundColor: GlassTheme.accentCyan,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  child: const Text("Apply Rights"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Bar
        _buildHeaderBar(isDesktop),
        const SizedBox(height: 16),

        // 2. Main Content (Loading / Empty / Master-Detail Layout)
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: GlassTheme.primaryNeon),
            ),
          )
        else if (_users.isEmpty)
          _buildNoUsersState()
        else if (isDesktop)
          _buildDesktopLayout()
        else
          _buildMobileLayout(),
      ],
    );
  }

  // ================= HEADER BAR =================
  Widget _buildHeaderBar(bool isDesktop) {
    final totalMenus = MenuTreeRegistry.totalMenuItemsCount;
    final currentCount = _currentSelectedMenus.length;

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
                  tooltip: "Back to Organization",
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
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.security_rounded,
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
                        "Assign Menus to User",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(
                        label: "User Menu Rights",
                        color: Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Control module visibility & permissions per user via .NET Tree View",
                    style: TextStyle(
                      fontSize: 12,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Header Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedUser != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.copy_all_rounded,
                    size: 16,
                    color: GlassTheme.primaryNeon,
                  ),
                  label: const Text(
                    "Copy Rights",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _showCopyPermissionsDialog,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasUnsavedChanges
                        ? GlassTheme.accentEmerald
                        : GlassTheme.primaryNeon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: _hasUnsavedChanges ? 3 : 1,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _hasUnsavedChanges
                              ? Icons.save_rounded
                              : Icons.check_circle_rounded,
                          size: 16,
                        ),
                  label: Text(
                    _isSaving
                        ? "Saving..."
                        : _hasUnsavedChanges
                        ? "Save Permissions *"
                        : "Save Permissions ($currentCount/$totalMenus)",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveCurrentPermissions,
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Refresh List",
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: GlassTheme.primaryNeon,
                ),
                onPressed: _loadData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= DESKTOP SPLIT MASTER-DETAIL LAYOUT =================
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left User Selector List (310px)
        SizedBox(width: 310, child: _buildUserListPanel()),
        const SizedBox(width: 16),

        // Right Permission Workspace
        Expanded(child: _buildPermissionWorkspace()),
      ],
    );
  }

  // ================= MOBILE LAYOUT =================
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // User Selector Dropdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<AppUser>(
            initialValue: _selectedUser,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: "Select User to Configure",
              prefixIcon: const Icon(
                Icons.person_rounded,
                color: GlassTheme.primaryNeon,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: _users.map((u) {
              return DropdownMenuItem(
                value: u,
                child: Text(
                  "${u.userId} - ${u.username} (${u.allowedMenus.length} Menus)",
                ),
              );
            }).toList(),
            onChanged: (u) {
              if (u != null) _selectUser(u);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Workspace
        _buildPermissionWorkspace(),
      ],
    );
  }

  // ================= LEFT USER LIST PANEL =================
  Widget _buildUserListPanel() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Header & Search
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select User Account",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${_filteredUsers.length} Users",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    _userSearch = val;
                    setState(() => _applyUserFilter());
                  },
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Search user ID or name...",
                    hintStyle: const TextStyle(
                      fontSize: 11,
                      color: GlassTheme.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: GlassTheme.textMuted,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // User Cards List
          Container(
            constraints: const BoxConstraints(maxHeight: 520),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _filteredUsers.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF8FAFC)),
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                final isSelected = _selectedUser?.userId == user.userId;

                return InkWell(
                  onTap: () => _selectUser(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? GlassTheme.primaryNeon.withValues(alpha: 0.08)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isSelected
                              ? GlassTheme.primaryNeon
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected
                              ? GlassTheme.primaryNeon
                              : GlassTheme.accentCyan.withValues(alpha: 0.15),
                          child: Text(
                            user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : GlassTheme.accentCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Name & ID
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.username,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? GlassTheme.primaryNeon
                                      : GlassTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    user.userId,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: GlassTheme.textMuted,
                                    ),
                                  ),
                                  if (user.branchId.isNotEmpty) ...[
                                    const Text(
                                      " • ",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: GlassTheme.textMuted,
                                      ),
                                    ),
                                    Text(
                                      user.branchId,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: GlassTheme.accentEmerald,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Permission count badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: user.allowedMenus.isNotEmpty
                                ? GlassTheme.primaryNeon.withValues(alpha: 0.1)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${user.allowedMenus.length}",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: user.allowedMenus.isNotEmpty
                                  ? GlassTheme.primaryNeon
                                  : GlassTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= RIGHT PERMISSION WORKSPACE =================
  Widget _buildPermissionWorkspace() {
    if (_selectedUser == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            "Please select a user from the left to configure menu rights.",
            style: TextStyle(color: GlassTheme.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final totalMenus = MenuTreeRegistry.totalMenuItemsCount;
    final selectedCount = _currentSelectedMenus.length;
    final percent = totalMenus > 0 ? (selectedCount / totalMenus) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active User Profile Card Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasUnsavedChanges
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFE2E8F0),
              width: _hasUnsavedChanges ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: GlassTheme.primaryNeon.withValues(
                      alpha: 0.12,
                    ),
                    child: Text(
                      _selectedUser!.username.isNotEmpty
                          ? _selectedUser!.username[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: GlassTheme.primaryNeon,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                              _selectedUser!.username,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: GlassTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: GlassTheme.accentCyan.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: GlassTheme.accentCyan.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                _selectedUser!.userId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: GlassTheme.accentCyan,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedUser!.isCentralLogin
                                    ? GlassTheme.primaryNeon.withValues(
                                        alpha: 0.1,
                                      )
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _selectedUser!.isCentralLogin
                                    ? "CentLogin: YES"
                                    : "CentLogin: NO",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedUser!.isCentralLogin
                                      ? GlassTheme.primaryNeon
                                      : GlassTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Branch: ${_getBranchName(_selectedUser!.branchId)}${_selectedUser!.email.isNotEmpty ? ' • Email: ${_selectedUser!.email}' : ''}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: GlassTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Permission Percentage Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: percent > 75
                          ? GlassTheme.accentEmerald.withValues(alpha: 0.1)
                          : percent > 30
                          ? GlassTheme.primaryNeon.withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${percent.toStringAsFixed(0)}% Access ($selectedCount/$totalMenus)",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: percent > 75
                            ? GlassTheme.accentEmerald
                            : percent > 30
                            ? GlassTheme.primaryNeon
                            : GlassTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),

              if (_hasUnsavedChanges) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: Color(0xFFB45309),
                      ),
                      SizedBox(width: 6),
                      Text(
                        "You have unsaved menu permission changes for this user. Click 'Save Permissions' above.",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Interactive .NET Tree View Component
        MenuPermissionsTreeView(
          key: ValueKey(_selectedUser!.userId),
          initialSelectedMenus: _currentSelectedMenus,
          onPermissionsChanged: (newMenus) {
            setState(() {
              _currentSelectedMenus = newMenus;
              _hasUnsavedChanges = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNoUsersState() {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: GlassTheme.accentCyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: GlassTheme.accentCyan,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "No User Accounts Found",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: GlassTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Create user accounts first in User Master before assigning menu rights.",
              style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

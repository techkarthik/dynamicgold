import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/tenant_model.dart';
import '../providers/auth_provider.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import 'company_master_screen.dart';
import 'branch_master_screen.dart';
import 'user_master_screen.dart';
import 'user_menu_rights_screen.dart';
import 'account_head_master_screen.dart';
import 'tax_master_screen.dart';
import 'metal_master_screen.dart';
import 'purity_master_screen.dart';
import 'category_master_screen.dart';
import 'designer_master_screen.dart';
import 'product_master_screen.dart';
import 'subproduct_master_screen.dart';
import 'style_master_screen.dart';
import 'size_master_screen.dart';
import 'price_setting_screen.dart';
import 'diamond_price_setting_screen.dart';
import 'database_status_screen.dart';
import 'system_controls_screen.dart';
import 'estimate_screen.dart';
import 'employee_master_screen.dart';
import 'sales_and_price_screen.dart';
import 'smith_purchase_screen.dart';
import 'prepare_sku_screen.dart';
import 'barcode_template_designer_screen.dart';
import 'stock_barcode_tagging_screen.dart';
import '../services/api_service.dart';
import '../constants/menu_registry.dart';
import '../constants/app_version.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasAccess(AuthProvider auth, String menuCode) {
    if (auth.isAdmin) return true;
    final user = auth.currentUser;
    if (user == null) return true;
    if (user.allowedMenus.isEmpty) return true;
    if (user.hasMenuAccess(menuCode)) return true;

    // Check parent hierarchy e.g. M_MASTER.INVENTORY grants M_MASTER.INVENTORY.PRODUCTS
    final parts = menuCode.split('.');
    for (int i = parts.length - 1; i >= 1; i--) {
      final parentCode = parts.sublist(0, i).join('.');
      if (user.allowedMenus.contains(parentCode)) return true;
    }

    // Auto-grant access to new core Estimate, Smith Purchase, or Stock modules/submenus
    if ((menuCode.startsWith('M_ESTIMATE') || menuCode.startsWith('M_SMITH_PURCHASE') || menuCode.startsWith('M_STOCK')) &&
        user.allowedMenus.any((c) => c.startsWith('M_POS') || c.startsWith('M_STOCK') || c.startsWith('M_MASTER'))) {
      return true;
    }

    return user.allowedMenus.any((code) => code.startsWith('$menuCode.'));
  }

  String _selectedModule = "HOME"; // e.g. MenuRegistry.MENU_MASTER, etc.
  String _masterSubmenu = "HUB"; // e.g. MenuRegistry.MASTER_ORGANIZATION, etc.
  String _stockSubmenu = "HUB"; // e.g. "PREPARE_SKU" or "HUB"
  String _settingsSubmenu = "HUB"; // e.g. "DB_STATUS" or "HUB"

  final ApiService _api = ApiService();

  // Live gold & silver rate states
  double _gold24k = 7450.0;
  double _gold22k = 6850.0;
  double _silver = 92.50;
  String _lastRateUpdated = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLiveRates();
    });
  }

  Future<void> _loadLiveRates() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    try {
      final summary = await _api.getLatestRates(token);
      if (mounted) {
        setState(() {
          if (summary.gold24k > 0) _gold24k = summary.gold24k;
          if (summary.gold22k > 0) _gold22k = summary.gold22k;
          if (summary.silver > 0) _silver = summary.silver;
          _lastRateUpdated = summary.lastUpdatedAt;
        });
      }
    } catch (_) {}
  }

  Future<void> _launchDigiGoldUrl() async {
    final uri = Uri.parse('https://digigold360.vercel.app/');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not open DigiGold at https://digigold360.vercel.app/"),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to open DigiGold: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final tenant = auth.currentTenant;

    if (tenant == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: GlassTheme.bgDark,
      drawer: _buildLeftDrawer(context, auth, tenant),
      appBar: _buildAppBar(context, auth, tenant),
      body: Stack(
        children: [
          // Ambient neon glow backgrounds
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.primaryNeon.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.accentEmerald.withValues(alpha: 0.06),
              ),
            ),
          ),

          // Main Screen Content
          SafeArea(
            child: _selectedModule == "HOME"
                ? _buildMobileRoundMenuLauncher(context, auth, tenant)
                : _buildModuleWorkspace(context, auth, tenant, _selectedModule),
          ),
        ],
      ),
    );
  }

  // ================= APP BAR =================
  PreferredSizeWidget _buildAppBar(BuildContext context, AuthProvider auth, Tenant tenant) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: GlassTheme.textPrimary, size: 26),
          tooltip: "Open Navigation Menu",
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          // Business Logo Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: GlassTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: GlassTheme.primaryNeon.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: tenant.businessLogo.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        tenant.businessLogo,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.diamond_rounded, size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tenant.businessName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: GlassTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: GlassTheme.accentEmerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "Billing Software • Valid until ${tenant.validTo}",
                    style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Active Company Indicator & Switcher Pill
        if (auth.activeCompany != null || auth.availableCompanies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: InkWell(
              onTap: () => _showCompanySwitcherDialog(context, auth),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.corporate_fare_rounded, size: 16, color: GlassTheme.primaryNeon),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        auth.activeCompany != null
                            ? "${auth.activeCompany!.companyName} (${auth.activeCompany!.companyId})"
                            : "Select Company",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: GlassTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
        if (_selectedModule != "HOME")
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: GlassTheme.primaryNeon),
            icon: const Icon(Icons.apps_rounded, size: 18),
            label: const Text("Main Menu", style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () {
              setState(() {
                _selectedModule = "HOME";
                _masterSubmenu = "HUB";
              });
            },
          ),
        IconButton(
          tooltip: "Business Profile",
          icon: const Icon(Icons.account_circle_outlined, color: GlassTheme.textPrimary, size: 24),
          onPressed: () => _showProfileDialog(context, auth, tenant),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ================= LEFT DRAWER WITH BUSINESS PROFILE & SUBMENUS =================
  Widget _buildLeftDrawer(BuildContext context, AuthProvider auth, Tenant tenant) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header: Business Profile & Logo
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GlassTheme.primaryNeon.withValues(alpha: 0.08),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Glowing Business Logo Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: GlassTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: GlassTheme.primaryNeon.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: tenant.businessLogo.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  tenant.businessLogo,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 28, color: Colors.white),
                                ),
                              )
                            : const Icon(Icons.diamond_rounded, size: 28, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant.businessName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: GlassTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          StatusBadge(label: "Tenant ID #${tenant.id}", color: GlassTheme.primaryNeon),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Subscription Validity Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: GlassTheme.accentEmerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GlassTheme.accentEmerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 16, color: GlassTheme.accentEmerald),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Active Subscription: ${tenant.daysRemaining} days remaining (Expires ${tenant.validTo})",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: GlassTheme.accentEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Active Company Card in Drawer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.corporate_fare_rounded, size: 16, color: GlassTheme.primaryNeon),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "ACTIVE OPERATING COMPANY",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: GlassTheme.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              auth.activeCompany != null
                                  ? "${auth.activeCompany!.companyName} (${auth.activeCompany!.companyId})"
                                  : "No Company Selected",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: GlassTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (auth.availableCompanies.length > 1)
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showCompanySwitcherDialog(context, auth);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: GlassTheme.primaryNeon.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, size: 16, color: GlassTheme.primaryNeon),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation Modules List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  title: "Main Dashboard",
                  subtitle: "Mobile app launcher view",
                  isSelected: _selectedModule == "HOME",
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedModule = "HOME";
                      _masterSubmenu = "HUB";
                    });
                  },
                ),
                if (_hasAccess(auth, MenuRegistry.MENU_MASTER)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.folder_special_rounded,
                    title: "Master Menu",
                    subtitle: "5 core master sub-modules",
                    isSelected: _selectedModule == "MASTER",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedModule = "MASTER";
                        _masterSubmenu = "HUB";
                      });
                    },
                  ),
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_SMITH_PURCHASE)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.diamond_rounded,
                    title: "Smith Purchase",
                    subtitle: "Gold bar & ornament purchases",
                    isSelected: _selectedModule == "SMITH_PURCHASE",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedModule = "SMITH_PURCHASE");
                    },
                  ),
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_STOCK)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: "Stock Management",
                    subtitle: "Ornament tags, SKU lots & weights",
                    isSelected: _selectedModule == "STOCK" && _stockSubmenu == "HUB",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedModule = "STOCK";
                        _stockSubmenu = "HUB";
                      });
                    },
                  ),
                  if (_hasAccess(auth, MenuRegistry.STOCK_PREPARE_FOR_SKU)) ...[
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      icon: Icons.post_add_rounded,
                      title: "Prepare for SKU",
                      subtitle: "SKU lot creation & numbering",
                      isSelected: _selectedModule == "STOCK" && _stockSubmenu == "PREPARE_SKU",
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedModule = "STOCK";
                          _stockSubmenu = "PREPARE_SKU";
                        });
                      },
                    ),
                  ],
                  if (_hasAccess(auth, MenuRegistry.STOCK_BARCODE_TAGS)) ...[
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      icon: Icons.qr_code_2_rounded,
                      title: "Barcode & RFID Tagging",
                      subtitle: "Lot tagging, costing & printing",
                      isSelected: _selectedModule == "STOCK" && _stockSubmenu == "BARCODE_TAGS",
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedModule = "STOCK";
                          _stockSubmenu = "BARCODE_TAGS";
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.design_services_rounded,
                    title: "Barcode Template Designer",
                    subtitle: "Visual tag & label layout editor",
                    isSelected: _selectedModule == "STOCK" && _stockSubmenu == "TEMPLATE_DESIGNER",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedModule = "STOCK";
                        _stockSubmenu = "TEMPLATE_DESIGNER";
                      });
                    },
                  ),
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_ESTIMATE)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.request_quote_rounded,
                    title: "Estimate & Quotation",
                    subtitle: "Pre-sale gold quotes & print slips",
                    isSelected: _selectedModule == "ESTIMATE",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedModule = "ESTIMATE");
                    },
                  ),
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_POS)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.point_of_sale_rounded,
                    title: "POS Billing",
                    subtitle: "Tax invoice & counter sales",
                    isSelected: _selectedModule == "POS",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedModule = "POS");
                    },
                  ),
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_REPORT)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.analytics_rounded,
                    title: "Reports & Day Book",
                    subtitle: "Sales register & GST reports",
                    isSelected: _selectedModule == "REPORT",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedModule = "REPORT");
                    },
                  ),
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_DIGIGOLD)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.monetization_on_rounded,
                    title: "DigiGold Module",
                    subtitle: "Vault, buy/sell & SIP (External)",
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      _launchDigiGoldUrl();
                    },
                  ),
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_SETTINGS)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: "Settings & Config",
                    subtitle: "System preferences & print templates",
                    isSelected: _selectedModule == "SETTINGS" && _settingsSubmenu == "HUB",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedModule = "SETTINGS";
                        _settingsSubmenu = "HUB";
                      });
                    },
                  ),
                  if (_hasAccess(auth, MenuRegistry.SETTINGS_DB_STATUS)) ...[
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      icon: Icons.pie_chart_rounded,
                      title: "Database Status",
                      subtitle: "PostgreSQL schema and table health",
                      isSelected: _selectedModule == "SETTINGS" && _settingsSubmenu == "DB_STATUS",
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedModule = "SETTINGS";
                          _settingsSubmenu = "DB_STATUS";
                        });
                      },
                    ),
                  ],
                  if (_hasAccess(auth, MenuRegistry.SETTINGS_SYSTEM_CONTROLS)) ...[
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      icon: Icons.tune_rounded,
                      title: "System Controls",
                      subtitle: "Module parameters & branch overrides",
                      isSelected: _selectedModule == "SETTINGS" && _settingsSubmenu == "SYSTEM_CONTROLS",
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedModule = "SETTINGS";
                          _settingsSubmenu = "SYSTEM_CONTROLS";
                        });
                      },
                    ),
                  ],
                  if (_hasAccess(auth, MenuRegistry.SETTINGS_REINSTALL_SYNC)) ...[
                    const SizedBox(height: 4),
                    _buildDrawerItem(
                      icon: Icons.system_update_rounded,
                      title: "Reinstall / Sync Schema",
                      subtitle: "Sync missing tables & barcode templates",
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        _showReinstallSchemaDialog(context, auth);
                      },
                    ),
                  ],
                ],
                if (_hasAccess(auth, MenuRegistry.MENU_CRM)) ...[
                  const SizedBox(height: 4),
                  _buildDrawerItem(
                    icon: Icons.groups_rounded,
                    title: "CRM & Gold Schemes",
                    subtitle: "Customer passbooks & alerts",
                    isSelected: _selectedModule == "CRM",
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedModule = "CRM");
                    },
                  ),
                ],
              ],
            ),
          ),

          // Drawer Footer with Version and Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: GlassTheme.accentEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppVersion.drawerVersion,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: GlassTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: GlassTheme.accentRose,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      auth.logout();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: isSelected ? GlassTheme.primaryNeon.withValues(alpha: 0.1) : Colors.transparent,
      leading: Icon(
        icon,
        color: isSelected ? GlassTheme.primaryNeon : GlassTheme.textSecondary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          color: isSelected ? GlassTheme.primaryNeon : GlassTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted, fontWeight: FontWeight.w500),
      ),
      trailing: isSelected
          ? const Icon(Icons.chevron_right_rounded, color: GlassTheme.primaryNeon, size: 18)
          : null,
    );
  }

  // ================= MOBILE PHONE STYLE ROUND MENU LAUNCHER =================
  Widget _buildMobileRoundMenuLauncher(BuildContext context, AuthProvider auth, Tenant tenant) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final List<Map<String, dynamic>> menuItems = [
      {
        "id": "MASTER",
        "name": "MASTER",
        "desc": "Foundational Setup",
        "icon": Icons.account_balance_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4338CA)]),
        "glow": const Color(0xFF6366F1),
        "badge": "5 Hubs",
      },
      {
        "id": "SMITH_PURCHASE",
        "name": "SMITH PURCHASE",
        "desc": "Gold Bar & Ornaments",
        "icon": Icons.diamond_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)]),
        "glow": const Color(0xFFF59E0B),
        "badge": null,
      },
      {
        "id": "STOCK",
        "name": "STOCK",
        "desc": "Inventory & Barcode",
        "icon": Icons.inventory_2_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)]),
        "glow": const Color(0xFF10B981),
        "badge": null,
      },
      {
        "id": "ESTIMATE",
        "name": "ESTIMATE",
        "desc": "Quotation & Preview",
        "icon": Icons.request_quote_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFC2410C)]),
        "glow": const Color(0xFFF97316),
        "badge": "3rd Menu",
      },
      {
        "id": "POS",
        "name": "POS BILLING",
        "desc": "Sales Counter",
        "icon": Icons.point_of_sale_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFBE185D)]),
        "glow": const Color(0xFFEC4899),
        "badge": "Quick",
      },
      {
        "id": "REPORT",
        "name": "REPORTS",
        "desc": "Ledger & GST",
        "icon": Icons.analytics_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFB45309)]),
        "glow": const Color(0xFFF59E0B),
        "badge": null,
      },
      {
        "id": "DIGIGOLD",
        "name": "DIGI GOLD",
        "desc": "Vault & SIP",
        "icon": Icons.monetization_on_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFD97706)]),
        "glow": const Color(0xFFFFD700),
        "badge": "24K",
      },
      {
        "id": "SETTINGS",
        "name": "SETTINGS",
        "desc": "System Config",
        "icon": Icons.settings_suggest_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0E7490)]),
        "glow": const Color(0xFF06B6D4),
        "badge": null,
      },
      {
        "id": "CRM",
        "name": "CRM",
        "desc": "Customer Schemes",
        "icon": Icons.groups_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
        "glow": const Color(0xFF8B5CF6),
        "badge": null,
      },
      {
        "id": "ADD_MORE",
        "name": "ADD MORE",
        "desc": "Marketplace",
        "icon": Icons.add_circle_outline_rounded,
        "gradient": const LinearGradient(colors: [Color(0xFF475569), Color(0xFF1E293B)]),
        "glow": const Color(0xFF64748B),
        "badge": "+",
      },
    ];

    final filteredMenuItems = menuItems.where((item) {
      if (item["id"] == "ADD_MORE") return true;
      String menuCode = '';
      switch (item["id"]) {
        case "MASTER":
          menuCode = MenuRegistry.MENU_MASTER;
          break;
        case "SMITH_PURCHASE":
          menuCode = MenuRegistry.MENU_SMITH_PURCHASE;
          break;
        case "STOCK":
          menuCode = MenuRegistry.MENU_STOCK;
          break;
        case "ESTIMATE":
          menuCode = MenuRegistry.MENU_ESTIMATE;
          break;
        case "POS":
          menuCode = MenuRegistry.MENU_POS;
          break;
        case "REPORT":
          menuCode = MenuRegistry.MENU_REPORT;
          break;
        case "DIGIGOLD":
          menuCode = MenuRegistry.MENU_DIGIGOLD;
          break;
        case "SETTINGS":
          menuCode = MenuRegistry.MENU_SETTINGS;
          break;
        case "CRM":
          menuCode = MenuRegistry.MENU_CRM;
          break;
        default:
          return false;
      }
      return _hasAccess(auth, menuCode);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gold Rate Live Ticker Banner
              _buildRateTicker(),
              const SizedBox(height: 28),

              // Title Section
              Text(
                "Welcome to ${tenant.businessName}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: GlassTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                "Jewellery Retail ERP & Multi-Tenant Billing System",
                style: TextStyle(fontSize: 14, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 36),

              // Mobile Phone Style Round Icons Grid
              Wrap(
                spacing: isDesktop ? 36 : 24,
                runSpacing: isDesktop ? 36 : 28,
                alignment: WrapAlignment.center,
                children: filteredMenuItems.map((item) {
                  return _buildRoundAppIcon(
                    item: item,
                    onTap: () {
                      if (item["id"] == "ADD_MORE") {
                        _showAddModuleDialog(context);
                      } else if (item["id"] == "DIGIGOLD") {
                        _launchDigiGoldUrl();
                      } else {
                        setState(() {
                          _selectedModule = item["id"];
                          _masterSubmenu = "HUB";
                        });
                      }
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 48),

              // Version and Build Date Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: GlassTheme.accentEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppVersion.badgeVersion,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ================= RATE TICKER BANNER =================
  Widget _buildRateTicker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x0C0F172A), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRateItem("GOLD 24K", "₹${_gold24k.round()}/g", Icons.trending_up_rounded, GlassTheme.accentEmerald),
          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
          _buildRateItem("GOLD 22K (916)", "₹${_gold22k.round()}/g", Icons.trending_up_rounded, GlassTheme.accentEmerald),
          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
          _buildRateItem("SILVER (92.5)", "₹${_silver % 1 == 0 ? _silver.toInt().toString() : _silver.toStringAsFixed(2)}/g", Icons.trending_flat_rounded, GlassTheme.accentCyan),
          if (_lastRateUpdated.isNotEmpty) ...[
            Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: GlassTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  "Updated: ${_lastRateUpdated.contains('T') ? _lastRateUpdated.split('T').first : _lastRateUpdated}",
                  style: const TextStyle(fontSize: 10, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateItem(String title, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: GlassTheme.textSecondary, fontWeight: FontWeight.w800)),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
          ],
        ),
      ],
    );
  }

  // ================= ROUND APP ICON WIDGET =================
  Widget _buildRoundAppIcon({
    required Map<String, dynamic> item,
    required VoidCallback onTap,
  }) {
    final String name = item["name"];
    final String desc = item["desc"];
    final IconData icon = item["icon"];
    final Gradient gradient = item["gradient"];
    final Color glow = item["glow"];
    final String? badge = item["badge"];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Round Icon Badge with Glow Shadow
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      const BoxShadow(
                        color: Color(0x100F172A),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white,
                      width: 2.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, size: 34, color: Colors.white),
                  ),
                ),

                // Optional Mini Status Badge
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: glow,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Name
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: GlassTheme.textPrimary,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            // Description
            Text(
              desc,
              style: const TextStyle(
                fontSize: 11,
                color: GlassTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= MODULE WORKSPACE ROUTER =================
  Widget _buildModuleWorkspace(BuildContext context, AuthProvider auth, Tenant tenant, String module) {
    String menuCode = '';
    switch (module) {
      case "MASTER":
        menuCode = MenuRegistry.MENU_MASTER;
        break;
      case "SMITH_PURCHASE":
        menuCode = MenuRegistry.MENU_SMITH_PURCHASE;
        break;
      case "STOCK":
        menuCode = MenuRegistry.MENU_STOCK;
        break;
      case "ESTIMATE":
        menuCode = MenuRegistry.MENU_ESTIMATE;
        break;
      case "POS":
        menuCode = MenuRegistry.MENU_POS;
        break;
      case "REPORT":
        menuCode = MenuRegistry.MENU_REPORT;
        break;
      case "DIGIGOLD":
        menuCode = MenuRegistry.MENU_DIGIGOLD;
        break;
      case "SETTINGS":
        menuCode = MenuRegistry.MENU_SETTINGS;
        break;
      case "CRM":
        menuCode = MenuRegistry.MENU_CRM;
        break;
    }

    if (menuCode.isNotEmpty && !_hasAccess(auth, menuCode)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: GlassContainer(
            borderRadius: 16,
            padding: EdgeInsets.all(24),
            child: Text(
              "Access Denied: You do not have permissions for this workspace.",
              style: TextStyle(color: GlassTheme.accentRose, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Check for full-screen workspace screens that have their own Scaffolds/headers/Flex layouts
    final bool isFullScreenView = (module == "SMITH_PURCHASE") ||
        (module == "ESTIMATE") ||
        (module == "STOCK" &&
            (_stockSubmenu == "PREPARE_SKU" ||
                _stockSubmenu == "BARCODE_TAGS" ||
                _stockSubmenu == "TEMPLATE_DESIGNER"));

    if (isFullScreenView) {
      return _buildModuleSpecificContent(module, auth, tenant);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Module Breadcrumb
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
                    onPressed: () {
                      if (module == "MASTER" && _masterSubmenu != "HUB") {
                        setState(() => _masterSubmenu = "HUB");
                      } else if (module == "SETTINGS" && _settingsSubmenu != "HUB") {
                        setState(() => _settingsSubmenu = "HUB");
                      } else if (module == "STOCK" && _stockSubmenu != "HUB") {
                        setState(() => _stockSubmenu = "HUB");
                      } else {
                        setState(() => _selectedModule = "HOME");
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    module == "MASTER" && _masterSubmenu != "HUB"
                        ? "MASTER > $_masterSubmenu"
                        : (module == "SETTINGS" && _settingsSubmenu != "HUB"
                            ? "SETTINGS > ${_settingsSubmenu == 'DB_STATUS' ? 'Database Status' : (_settingsSubmenu == 'SYSTEM_CONTROLS' ? 'System Controls' : _settingsSubmenu)}"
                            : (module == "STOCK" && _stockSubmenu != "HUB"
                                ? "STOCK > ${_stockSubmenu == 'PREPARE_SKU' ? 'Prepare for SKU' : (_stockSubmenu == 'BARCODE_TAGS' ? 'Barcode & RFID Tagging' : (_stockSubmenu == 'TEMPLATE_DESIGNER' ? 'Barcode Template Designer' : _stockSubmenu))}"
                                : (module == "ESTIMATE" ? "ESTIMATE & QUOTATION DESK" : "$module Workspace"))),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                  ),
                  const Spacer(),
                  const StatusBadge(label: "Jewellery Billing Core", color: GlassTheme.accentEmerald),
                ],
              ),
              const SizedBox(height: 20),

              // Dynamic Module Content Panel
              _buildModuleSpecificContent(module, auth, tenant),
            ],
          ),
        ),
      ),
    );
  }

  // Specific Workspace Content for each module
  Widget _buildModuleSpecificContent(String module, AuthProvider auth, Tenant tenant) {
    switch (module) {
      case "MASTER":
        return _buildMasterHubWithSubmenus(auth, tenant);
      case "SMITH_PURCHASE":
        return SmithPurchaseScreen(
          onBack: () => setState(() => _selectedModule = "HOME"),
          onNavigateModule: (m) => setState(() => _selectedModule = m),
        );
      case "STOCK":
        if (_stockSubmenu == "PREPARE_SKU") {
          return PrepareSkuScreen(
            onBack: () => setState(() => _stockSubmenu = "HUB"),
          );
        }
        if (_stockSubmenu == "BARCODE_TAGS") {
          return StockBarcodeTaggingScreen(
            onBack: () => setState(() => _stockSubmenu = "HUB"),
          );
        }
        if (_stockSubmenu == "TEMPLATE_DESIGNER") {
          return BarcodeTemplateDesignerScreen(
            onBack: () => setState(() => _stockSubmenu = "HUB"),
          );
        }
        return _buildStockWorkspace(auth);
      case "ESTIMATE":
        return EstimateScreen(
          onBack: () => setState(() => _selectedModule = "HOME"),
          onNavigateModule: (m) => setState(() => _selectedModule = m),
        );
      case "POS":
        return _buildPosWorkspace(auth);
      case "REPORT":
        return _buildReportWorkspace(auth);
      case "DIGIGOLD":
        return _buildDigiGoldWorkspace(auth);
      case "SETTINGS":
        if (_settingsSubmenu == "DB_STATUS") {
          return DatabaseStatusScreen(onBack: () => setState(() => _settingsSubmenu = "HUB"));
        }
        if (_settingsSubmenu == "SYSTEM_CONTROLS") {
          return SystemControlsScreen(onBack: () => setState(() => _settingsSubmenu = "HUB"));
        }
        return _buildSettingsWorkspace(auth, tenant);
      case "CRM":
        return _buildCrmWorkspace(auth);
      default:
        return GlassContainer(
          borderRadius: 16,
          child: Center(
            child: Text("Workspace for $module is active.", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
          ),
        );
    }
  }

  // ================= MASTER HUB & 5 SUB-MENUS =================
  Widget _buildMasterHubWithSubmenus(AuthProvider auth, Tenant tenant) {
    String submenuCode = '';
    switch (_masterSubmenu) {
      case "COMPANY":
        submenuCode = MenuRegistry.MASTER_ORGANIZATION_COMPANY;
        break;
      case "BRANCHES":
        submenuCode = MenuRegistry.MASTER_ORGANIZATION_BRANCHES;
        break;
      case "USER_RIGHTS":
        submenuCode = MenuRegistry.MASTER_ORGANIZATION_USER_RIGHTS;
        break;
      case "STORE_PROFILE":
        submenuCode = MenuRegistry.MASTER_ORGANIZATION;
        break;
      case "ORGANIZATION":
        submenuCode = MenuRegistry.MASTER_ORGANIZATION;
        break;
      case "INVENTORY":
        submenuCode = MenuRegistry.MASTER_INVENTORY;
        break;
      case "SALESANDPRICE":
        submenuCode = MenuRegistry.MASTER_SALES_AND_PRICE;
        break;
      case "LOGINUSERS":
        submenuCode = MenuRegistry.MASTER_LOGIN_USERS;
        break;
      case "EMPLOYEES":
        submenuCode = MenuRegistry.MASTER_EMPLOYEES;
        break;
      case "ACCOUNTHEAD":
        submenuCode = MenuRegistry.MASTER_ACCOUNT_HEAD;
        break;
      case "TAXMASTER":
        submenuCode = MenuRegistry.MASTER_TAX_MASTER;
        break;
      case "METAL":
        submenuCode = MenuRegistry.MASTER_INVENTORY_METAL;
        break;
      case "PURITY":
        submenuCode = MenuRegistry.MASTER_INVENTORY_PURITY;
        break;
      case "CATEGORY":
        submenuCode = MenuRegistry.MASTER_INVENTORY_CATEGORY;
        break;
      case "DESIGNERS":
        submenuCode = MenuRegistry.MASTER_INVENTORY_DESIGNERS;
        break;
      case "PRODUCTS":
        submenuCode = MenuRegistry.MASTER_INVENTORY_PRODUCTS;
        break;
      case "SUBPRODUCTS":
        submenuCode = MenuRegistry.MASTER_INVENTORY_SUBPRODUCTS;
        break;
      case "STYLES":
        submenuCode = MenuRegistry.MASTER_INVENTORY_STYLES;
        break;
      case "SIZES":
        submenuCode = MenuRegistry.MASTER_INVENTORY_SIZES;
        break;
      case "PRICESETTING":
        submenuCode = MenuRegistry.MASTER_INVENTORY_PRICE_SETTING;
        break;
      case "DIAMONDPRICESETTING":
        submenuCode = MenuRegistry.MASTER_INVENTORY_DIAMOND_PRICE_SETTING;
        break;
    }

    if (submenuCode.isNotEmpty && !_hasAccess(auth, submenuCode)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: GlassContainer(
            borderRadius: 16,
            padding: EdgeInsets.all(24),
            child: Text(
              "Access Denied: You do not have permissions for this master category.",
              style: TextStyle(color: GlassTheme.accentRose, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    switch (_masterSubmenu) {
      case "COMPANY":
        return CompanyMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "ORGANIZATION"),
        );
      case "BRANCHES":
        return BranchMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "ORGANIZATION"),
        );
      case "USER_RIGHTS":
        return UserMenuRightsScreen(
          onBack: () => setState(() => _masterSubmenu = "ORGANIZATION"),
        );
      case "STORE_PROFILE":
        return _buildStoreProfileWorkspace(auth, tenant);
      case "ORGANIZATION":
        return _buildOrganizationSubmenu(auth, tenant);
      case "INVENTORY":
        return _buildInventorySubmenu(auth);
      case "SALESANDPRICE":
        return SalesAndPriceScreen(
          onBack: () {
            setState(() => _masterSubmenu = "HUB");
            _loadLiveRates();
          },
        );
      case "LOGINUSERS":
        return UserMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "HUB"),
        );
      case "EMPLOYEES":
        return EmployeeMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "HUB"),
        );
      case "ACCOUNTHEAD":
        return AccountHeadMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "HUB"),
        );
      case "TAXMASTER":
        return TaxMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "HUB"),
        );
      case "METAL":
        return MetalMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "PURITY":
        return PurityMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "CATEGORY":
        return CategoryMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "DESIGNERS":
        return DesignerMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "PRODUCTS":
        return ProductMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "SUBPRODUCTS":
        return SubProductMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "STYLES":
        return StyleMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "SIZES":
        return SizeMasterScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "PRICESETTING":
        return PriceSettingScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "DIAMONDPRICESETTING":
        return DiamondPriceSettingScreen(
          onBack: () => setState(() => _masterSubmenu = "INVENTORY"),
        );
      case "HUB":
      default:
        return _buildMasterSubmenuGrid(auth);
    }
  }

  // Master 5 Sub-menu Cards Hub
  Widget _buildMasterSubmenuGrid(AuthProvider auth) {
    final List<Map<String, dynamic>> submenus = [
      {
        "id": "ORGANIZATION",
        "name": "ORGANIZATION",
        "title": "Organization Setup",
        "desc": "Manage Companies, Branches & User Rights",
        "icon": Icons.business_rounded,
        "color": GlassTheme.primaryNeon,
      },
      {
        "id": "INVENTORY",
        "name": "INVENTORY",
        "title": "Item Master",
        "desc": "Ornaments, purities & purities rules",
        "icon": Icons.category_rounded,
        "color": GlassTheme.accentEmerald,
      },
      {
        "id": "SALESANDPRICE",
        "name": "RATE MASTER",
        "title": "Rate Master",
        "desc": "Purity-based daily board rates, metal rates & history",
        "icon": Icons.price_change_rounded,
        "color": GlassTheme.accentAmber,
      },
      {
        "id": "LOGINUSERS",
        "name": "LOGIN USERS",
        "title": "User Master",
        "desc": "Manage operator accounts & permissions",
        "icon": Icons.admin_panel_settings_rounded,
        "color": GlassTheme.accentCyan,
      },
      {
        "id": "EMPLOYEES",
        "name": "EMPLOYEES",
        "title": "Employee Master",
        "desc": "Staff profiles, branch assignment & employee directory",
        "icon": Icons.badge_rounded,
        "color": GlassTheme.secondaryNeon,
      },
      {
        "id": "ACCOUNTHEAD",
        "name": "ACCOUNT HEAD",
        "title": "Account Head Master",
        "desc": "Manage ledger accounts, groupings, and contact info",
        "icon": Icons.account_balance_wallet_rounded,
        "color": GlassTheme.accentRose,
      },
      {
        "id": "TAXMASTER",
        "name": "TAX MASTER",
        "title": "Tax Master Setup",
        "desc": "Configure SGST, CGST, IGST rates for jewellery & bullion",
        "icon": Icons.percent_rounded,
        "color": GlassTheme.accentEmerald,
      },
    ];

    final filteredSubmenus = submenus.where((submenu) {
      String code = '';
      switch (submenu["id"]) {
        case "ORGANIZATION":
          code = MenuRegistry.MASTER_ORGANIZATION;
          break;
        case "INVENTORY":
          code = MenuRegistry.MASTER_INVENTORY;
          break;
        case "SALESANDPRICE":
          code = MenuRegistry.MASTER_SALES_AND_PRICE;
          break;
        case "LOGINUSERS":
          code = MenuRegistry.MASTER_LOGIN_USERS;
          break;
        case "EMPLOYEES":
          code = MenuRegistry.MASTER_EMPLOYEES;
          break;
        case "ACCOUNTHEAD":
          code = MenuRegistry.MASTER_ACCOUNT_HEAD;
          break;
        case "TAXMASTER":
          code = MenuRegistry.MASTER_TAX_MASTER;
          break;
        default:
          return false;
      }
      return _hasAccess(auth, code);
    }).toList();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select a master category to manage foundational data for your jewellery billing & retail operations:",
          style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = isDesktop ? 3 : 2;
            final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: filteredSubmenus.map((item) {
                final Color col = item["color"];
                return SizedBox(
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => setState(() => _masterSubmenu = item["id"]),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: col.withValues(alpha: 0.35)),
                              ),
                              child: Icon(item["icon"], color: col, size: 28),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item["name"],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: col,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item["title"],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: GlassTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item["desc"],
                              style: const TextStyle(
                                fontSize: 11,
                                color: GlassTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // 1. SUBMENU: ORGANIZATION
  Widget _buildOrganizationSubmenu(AuthProvider auth, Tenant tenant) {
    final List<Map<String, dynamic>> items = [
      {
        "id": "COMPANY",
        "name": "COMPANY MASTER",
        "title": "Corporate Entity",
        "desc": "Manage corporate details, state registrations & financial settings",
        "icon": Icons.apartment_rounded,
        "color": GlassTheme.primaryNeon,
        "code": MenuRegistry.MASTER_ORGANIZATION_COMPANY,
      },
      {
        "id": "BRANCHES",
        "name": "BRANCH MASTER",
        "title": "Store & Outlets",
        "desc": "Configure retail counters, branch offices & regional stores",
        "icon": Icons.storefront_rounded,
        "color": GlassTheme.accentEmerald,
        "code": MenuRegistry.MASTER_ORGANIZATION_BRANCHES,
      },
      {
        "id": "USER_RIGHTS",
        "name": "USER MENU RIGHTS",
        "title": "Assign Permissions",
        "desc": "Assign menu rights & security parameters to operator logins",
        "icon": Icons.security_rounded,
        "color": const Color(0xFF8B5CF6),
        "code": MenuRegistry.MASTER_ORGANIZATION_USER_RIGHTS,
      },
      {
        "id": "STORE_PROFILE",
        "name": "STORE PROFILE",
        "title": "Head Office Profile",
        "desc": "Overview of business info, contacts & billing terminals",
        "icon": Icons.settings_suggest_rounded,
        "color": GlassTheme.accentCyan,
        "code": MenuRegistry.MASTER_ORGANIZATION,
      },
    ];

    final filteredItems = items.where((item) => _hasAccess(auth, item["code"])).toList();
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
              onPressed: () => setState(() => _masterSubmenu = "HUB"),
            ),
            const SizedBox(width: 8),
            const Text(
              "Back to Master Menu",
              style: TextStyle(fontSize: 14, color: GlassTheme.textSecondary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = isDesktop ? 2 : 2;
            final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: filteredItems.map((item) {
                final Color col = item["color"];
                return SizedBox(
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => setState(() => _masterSubmenu = item["id"]),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: col.withValues(alpha: 0.35)),
                              ),
                              child: Icon(item["icon"], color: col, size: 28),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item["name"],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: col,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item["title"],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: GlassTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item["desc"],
                              style: const TextStyle(
                                fontSize: 11,
                                color: GlassTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // 1b. WORKSPACE: STORE PROFILE
  Widget _buildStoreProfileWorkspace(AuthProvider auth, Tenant tenant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
              onPressed: () => setState(() => _masterSubmenu = "ORGANIZATION"),
            ),
            const SizedBox(width: 8),
            const Text(
              "Store Profile Setup",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStoreProfileContent(tenant),
      ],
    );
  }

  // Store Profile & Counters Content
  Widget _buildStoreProfileContent(Tenant tenant) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront_rounded, color: GlassTheme.accentCyan, size: 24),
              SizedBox(width: 10),
              Text(
                "STORE & BILLING COUNTER SETUP",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
              ),
              Spacer(),
              StatusBadge(label: "Head Office", color: GlassTheme.accentEmerald),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Overview of default head office store details, contact information, and billing terminal configuration:",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // Current Tenant Store Overview Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tenant.businessName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                    StatusBadge(label: "ID #${tenant.id}", color: GlassTheme.accentCyan),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 14, color: GlassTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text("Contact: ${tenant.contactNumber}", style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 20),
                    const Icon(Icons.email_rounded, size: 14, color: GlassTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text("Registered Email: ${tenant.email}", style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.point_of_sale_rounded, size: 16, color: GlassTheme.accentCyan),
                    SizedBox(width: 8),
                    Text(
                      "Configured Billing Counters: Counter 01 (Gold/Diamond), Counter 02 (Silver/Coins)",
                      style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. SUBMENU: INVENTORY
  Widget _buildInventorySubmenu(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
                tooltip: "Back to Master Hub",
                onPressed: () => setState(() => _masterSubmenu = "HUB"),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.category_rounded, color: GlassTheme.accentEmerald, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Inventory Configurations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                  Text("Configure metals, purities, and item categories", style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_METAL))
                _buildSubmenuGridCard(
                  title: "Metal Master",
                  desc: "Configure metals (Gold, Silver, Platinum)",
                  icon: Icons.grid_view_rounded,
                  color: GlassTheme.accentAmber,
                  onTap: () => setState(() => _masterSubmenu = "METAL"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_PURITY))
                _buildSubmenuGridCard(
                  title: "Purity Master",
                  desc: "Define purity percentages & Karats (e.g. 22K 91.6)",
                  icon: Icons.star_rounded,
                  color: GlassTheme.accentCyan,
                  onTap: () => setState(() => _masterSubmenu = "PURITY"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_CATEGORY))
                _buildSubmenuGridCard(
                  title: "Category Master",
                  desc: "Manage item categories & posting ledger accounts",
                  icon: Icons.shopping_bag_rounded,
                  color: GlassTheme.accentRose,
                  onTap: () => setState(() => _masterSubmenu = "CATEGORY"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_DESIGNERS))
                _buildSubmenuGridCard(
                  title: "Designer Master",
                  desc: "Manage jewellery designers, linked smiths & dealers",
                  icon: Icons.brush_rounded,
                  color: const Color(0xFFE11D48),
                  onTap: () => setState(() => _masterSubmenu = "DESIGNERS"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_PRODUCTS))
                _buildSubmenuGridCard(
                  title: "Product Master",
                  desc: "Define products, calc types (Weight/Rate/Fixed) & stock tracking",
                  icon: Icons.category_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => setState(() => _masterSubmenu = "PRODUCTS"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_SUBPRODUCTS))
                _buildSubmenuGridCard(
                  title: "Sub-Product Master",
                  desc: "Manage multi-part jewellery assemblies & sub-products",
                  icon: Icons.account_tree_rounded,
                  color: const Color(0xFFEC4899),
                  onTap: () => setState(() => _masterSubmenu = "SUBPRODUCTS"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_STYLES))
                _buildSubmenuGridCard(
                  title: "Style Master",
                  desc: "Define product design styles, models & variant patterns",
                  icon: Icons.style_rounded,
                  color: const Color(0xFF06B6D4),
                  onTap: () => setState(() => _masterSubmenu = "STYLES"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_SIZES))
                _buildSubmenuGridCard(
                  title: "Size Master",
                  desc: "Define ring sizes, bangle diameters & chain length dimensions",
                  icon: Icons.straighten_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => setState(() => _masterSubmenu = "SIZES"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_PRICE_SETTING))
                _buildSubmenuGridCard(
                  title: "Price Setting",
                  desc: "Configure weight-wise VA%, wastage & making charges per dealer",
                  icon: Icons.price_change_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => setState(() => _masterSubmenu = "PRICESETTING"),
                ),
              if (_hasAccess(auth, MenuRegistry.MASTER_INVENTORY_DIAMOND_PRICE_SETTING))
                _buildSubmenuGridCard(
                  title: "Diamond Price Setting",
                  desc: "Configure cent weight ranges & cent rates for diamond/stone products",
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFF0284C7),
                  onTap: () => setState(() => _masterSubmenu = "DIAMONDPRICESETTING"),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmenuGridCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ================= OTHER MODULE WORKSPACES =================
  // 1. STOCK WORKSPACE
  Widget _buildStockWorkspace(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GlassTheme.accentEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: GlassTheme.accentEmerald, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Stock Inventory & Barcode Tracking", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text("Manage item gross weights, net gold weights, stone charges, and RFID/Barcode tag assignments.", style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 20),

          // Stock Submodules Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (_hasAccess(auth, MenuRegistry.STOCK_PREPARE_FOR_SKU))
                _buildSubmenuGridCard(
                  title: "Prepare for SKU",
                  desc: "Prepare and group ornament lots, purity rates, stones & diamonds for SKU generation with auto lot numbers",
                  icon: Icons.post_add_rounded,
                  color: const Color(0xFF4F46E5),
                  onTap: () => setState(() => _stockSubmenu = "PREPARE_SKU"),
                ),
              if (_hasAccess(auth, MenuRegistry.STOCK_LIVE_INVENTORY))
                _buildSubmenuGridCard(
                  title: "Live Stock & Tray Balance",
                  desc: "Real-time gross/net gold & stone inventory balance across counters",
                  icon: Icons.grid_view_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Live Stock Inventory module active")),
                    );
                  },
                ),
              if (_hasAccess(auth, MenuRegistry.STOCK_ENTRY))
                _buildSubmenuGridCard(
                  title: "Stock Inward & Invoicing",
                  desc: "Receive manufactured ornaments and gold bars from bullion dealers / karigars",
                  icon: Icons.add_box_rounded,
                  color: const Color(0xFFD97706),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Stock Inward module active")),
                    );
                  },
                ),
              if (_hasAccess(auth, MenuRegistry.STOCK_BARCODE_TAGS))
                _buildSubmenuGridCard(
                  title: "Barcode & RFID Tagging",
                  desc: "Lot-based SKU tagging, VA lookup, purchase costing & 1-click printing",
                  icon: Icons.qr_code_2_rounded,
                  color: const Color(0xFF06B6D4),
                  onTap: () {
                    setState(() => _stockSubmenu = "BARCODE_TAGS");
                  },
                ),
              _buildSubmenuGridCard(
                title: "Barcode Template Designer",
                desc: "Design dynamic multi-column jewelry tags & roll labels with live preview",
                icon: Icons.design_services_rounded,
                color: const Color(0xFFEAB308),
                onTap: () {
                  setState(() => _stockSubmenu = "TEMPLATE_DESIGNER");
                },
              ),
              if (_hasAccess(auth, MenuRegistry.STOCK_AUDIT))
                _buildSubmenuGridCard(
                  title: "Physical Stock Audit",
                  desc: "Tray-wise physical barcode scanning & variance check",
                  icon: Icons.fact_check_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Physical Stock Audit module active")),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. POS WORKSPACE
  Widget _buildPosWorkspace(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: GlassTheme.accentRose, size: 24),
              SizedBox(width: 10),
              Text("Point of Sale (POS) Billing & Invoicing", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Generate instant tax invoices with making charges, wastage calculation, hallmarking charges, and GST breakdown.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: "New Jewellery Billing Invoice",
            icon: Icons.receipt_long_rounded,
            gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF9333EA)]),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // 3. REPORT WORKSPACE
  Widget _buildReportWorkspace(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: GlassTheme.accentAmber, size: 24),
              SizedBox(width: 10),
              Text("Business Reports & Financial Ledger", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Access Day Book summaries, Sales Registers, Metal Stock Balance Reports, and GST GSTR-1 summaries.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // 4. DIGIGOLD WORKSPACE
  Widget _buildDigiGoldWorkspace(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text("DigiGold Digital Vault & Micro-SIP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                      SizedBox(width: 8),
                      StatusBadge(label: "External Portal", color: Color(0xFFD97706)),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text("24K 99.9% pure digital gold accumulation, SIPs & wallet balance", style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "Access the full DigiGold 360 cloud platform to manage customer gold vaults, daily SIP buy/sell orders, physical delivery redemptions, and gold savings passbooks.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text("Launch DigiGold 360 (https://digigold360.vercel.app/)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            onPressed: _launchDigiGoldUrl,
          ),
        ],
      ),
    );
  }

  // 5. SETTINGS WORKSPACE
  Widget _buildSettingsWorkspace(AuthProvider auth, Tenant tenant) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0E7490)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "System Settings & Management",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Administration", color: Color(0xFF06B6D4)),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Database monitoring, storage quotas, hardware configuration, and store profile",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Settings Submenu Action Cards
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // 1. Database Status
              _buildSubmenuGridCard(
                title: "Database Status",
                desc: "Check PostgreSQL connectivity and tenant table row counts",
                icon: Icons.pie_chart_rounded,
                color: const Color(0xFF06B6D4),
                onTap: () => setState(() => _settingsSubmenu = "DB_STATUS"),
              ),

              // 2. Store Profile
              _buildSubmenuGridCard(
                title: "Store Profile & Setup",
                desc: "Configure business branding, contact numbers, and invoice headers",
                icon: Icons.store_mall_directory_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => _showProfileDialog(context, auth, tenant),
              ),

              // 3. PostgreSQL Query Tool
              _buildSubmenuGridCard(
                title: "PostgreSQL Schema & Query",
                desc: "PostgreSQL schema health, live SQL console & table inspector",
                icon: Icons.cloud_sync_rounded,
                color: const Color(0xFF10B981),
                onTap: () => setState(() => _settingsSubmenu = "DB_STATUS"),
              ),

              // 4. System Controls
              _buildSubmenuGridCard(
                title: "System Controls",
                desc: "Module runtime parameters, global configuration values & branch overrides",
                icon: Icons.tune_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => setState(() => _settingsSubmenu = "SYSTEM_CONTROLS"),
              ),

              // 5. Reinstall / Sync Schema
              _buildSubmenuGridCard(
                title: "Reinstall / Sync Schema",
                desc: "Synchronize new database tables, missing columns, and system migrations safely",
                icon: Icons.system_update_rounded,
                color: const Color(0xFF6366F1),
                onTap: () => _showReinstallSchemaDialog(context, auth),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Tenant Profile Summary Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tenant.businessName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                    StatusBadge(label: "Tenant #${tenant.id}", color: const Color(0xFF06B6D4)),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Registered Email: ${tenant.email}", style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text("Subscription License: ${tenant.validFrom} to ${tenant.validTo} (${tenant.daysRemaining} days remaining)", style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. CRM WORKSPACE
  Widget _buildCrmWorkspace(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_rounded, color: GlassTheme.secondaryNeon, size: 24),
              SizedBox(width: 10),
              Text("CRM, Gold Schemes & Customer Directory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Track customer purchase histories, 11-month gold savings schemes, automated WhatsApp/SMS birthday & anniversary reminders.",
            style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ================= PROFILE & LOGO MODAL DIALOG =================
  void _showProfileDialog(BuildContext context, AuthProvider auth, Tenant tenant) {
    final nameCtrl = TextEditingController(text: tenant.businessName);
    final logoCtrl = TextEditingController(text: tenant.businessLogo);
    final phoneCtrl = TextEditingController(text: tenant.contactNumber);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.business_center_rounded, color: GlassTheme.primaryNeon, size: 22),
                  SizedBox(width: 10),
                  Text("Business Profile & Branding", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassTextField(
                      controller: nameCtrl,
                      label: "Business / Store Name",
                      hint: "e.g. TechKarthik Jewellers",
                      prefixIcon: Icons.store_rounded,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      controller: logoCtrl,
                      label: "Business Logo Image URL",
                      hint: "https://example.com/logo.png",
                      prefixIcon: Icons.image_rounded,
                    ),
                    const SizedBox(height: 14),
                    GlassTextField(
                      controller: phoneCtrl,
                      label: "Contact Number",
                      hint: "+91 9876543210",
                      prefixIcon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Tenant Email: ${tenant.email}", style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text("Subscription: ${tenant.validFrom} to ${tenant.validTo} (${tenant.daysRemaining} days remaining)",
                              style: const TextStyle(fontSize: 11, color: GlassTheme.accentEmerald, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.primaryNeon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await auth.updateBusinessProfile(
                      businessName: nameCtrl.text.trim(),
                      businessLogo: logoCtrl.text.trim(),
                      contactNumber: phoneCtrl.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Business profile updated successfully!", style: TextStyle(fontWeight: FontWeight.w700))),
                      );
                    }
                  },
                  child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add more module modal dialog
  void _showAddModuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.extension_rounded, color: GlassTheme.accentCyan),
            SizedBox(width: 10),
            Text("Module Marketplace", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          "You can add more specialized business modules here in future releases (e.g. Karatmeter Integration, Hallmarking HUID sync, e-Way Bill, E-Commerce sync, Multi-branch sync).",
          style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Reinstall & Sync Schema Modal Dialog
  void _showReinstallSchemaDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<AuthProvider>(
        builder: (context, authState, _) {
          final isBusy = authState.isReinstallingDb;
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Color(0xFF6366F1), size: 24),
                SizedBox(width: 10),
                Text("Reinstall / Sync Database Schema", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.security_rounded, color: Color(0xFF16A34A), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Safe & Non-Destructive: No existing records, transactions, or products will be altered or deleted.",
                            style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "This operation applies the latest ProGold ERP database structures, newly added master tables (Barcode Templates, Stock Tagging, SKU Lots, Styles, Sizes, Sub-products, System Controls), and new schema columns to your private store database.",
                    style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Whenever the application is updated, simply run this tool once to keep your tenant database 100% in sync with the latest frontend features.",
                    style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isBusy ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: isBusy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(isBusy ? "Synchronizing Schema..." : "Run Reinstall & Sync Now", style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: isBusy
                    ? null
                    : () async {
                        final result = await authState.reinstallDatabase();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          final isSuccess = result['success'] == true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message'] ?? (isSuccess ? "Database schema reinstalled and synchronized successfully!" : "Reinstall failed."),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              backgroundColor: isSuccess ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= COMPANY SWITCHER DIALOG =================
  void _showCompanySwitcherDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: GlassTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Switch Operating Company", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                  Text("Select company to isolate transactions and branch data", style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: auth.availableCompanies.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text("No corporate companies registered yet.", style: TextStyle(color: GlassTheme.textMuted))),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: auth.availableCompanies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final comp = auth.availableCompanies[idx];
                    final isSelected = auth.activeCompanyId.toUpperCase() == comp.companyId.toUpperCase();
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected ? GlassTheme.primaryNeon.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? GlassTheme.primaryNeon : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () {
                          auth.selectCompany(comp);
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Switched active company to ${comp.companyName} (${comp.companyId})"),
                              backgroundColor: GlassTheme.accentEmerald,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? GlassTheme.primaryNeon : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              comp.companyId,
                              style: TextStyle(
                                color: isSelected ? Colors.white : GlassTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          comp.companyName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isSelected ? GlassTheme.primaryNeon : GlassTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (comp.city.isNotEmpty) comp.city,
                            if (comp.state.isNotEmpty) comp.state,
                            if (comp.gstNo.isNotEmpty) "GST: ${comp.gstNo}",
                          ].join(" • ").ifEmpty("Headquarters"),
                          style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: GlassTheme.primaryNeon, size: 22)
                            : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 22),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

extension _HomeStringEmptyHelper on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

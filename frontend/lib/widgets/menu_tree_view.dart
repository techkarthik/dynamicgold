import 'package:flutter/material.dart';
import '../constants/menu_registry.dart';
import '../theme/glass_theme.dart';

/// Represents a node in the .NET-style Menu Permission Tree View
class MenuTreeNode {
  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<MenuTreeNode> children;

  const MenuTreeNode({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.children = const [],
  });

  bool get isLeaf => children.isEmpty;

  /// Returns all leaf codes under this node (or itself if it's a leaf)
  List<String> get allLeafCodes {
    if (isLeaf) return [code];
    final List<String> codes = [];
    for (final child in children) {
      codes.addAll(child.allLeafCodes);
    }
    return codes;
  }
}

/// Predefined ProGold Hierarchy of Menus & Submenus
class MenuTreeRegistry {
  static final List<MenuTreeNode> fullTree = [
    // 1. MASTER MODULE
    const MenuTreeNode(
      code: MenuRegistry.MENU_MASTER,
      title: "Master Configuration",
      subtitle: "Corporate entities, products, pricing & users",
      icon: Icons.account_balance_rounded,
      color: Color(0xFF6366F1),
      children: [
        MenuTreeNode(
          code: MenuRegistry.MASTER_ORGANIZATION_COMPANY,
          title: "Company Master",
          subtitle: "Corporate entity, GSTIN, banking & state setups",
          icon: Icons.apartment_rounded,
          color: Color(0xFF6366F1),
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_ORGANIZATION_BRANCHES,
          title: "Branch Master",
          subtitle: "Store outlets, retail counters & regional branches",
          icon: Icons.storefront_rounded,
          color: Color(0xFF10B981),
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_ORGANIZATION_USER_RIGHTS,
          title: "User Menu Rights",
          subtitle: "Assign .NET tree view menu permissions to users",
          icon: Icons.security_rounded,
          color: Color(0xFF8B5CF6),
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_INVENTORY,
          title: "Item & Ornament Master",
          subtitle: "Metal types, 24K/22K 916 purities & ornament categories",
          icon: Icons.category_rounded,
          color: Color(0xFF10B981),
          children: [
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_METAL,
              title: "Metal Master",
              subtitle: "Configure metals (Gold, Silver, Platinum)",
              icon: Icons.grid_view_rounded,
              color: Color(0xFFF59E0B),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_PURITY,
              title: "Purity Master",
              subtitle: "Define purity percentages & Karats (e.g. 22K 91.6)",
              icon: Icons.star_rounded,
              color: Color(0xFF10B981),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_CATEGORY,
              title: "Category Master",
              subtitle: "Manage item categories & tax percentages",
              icon: Icons.shopping_bag_rounded,
              color: Color(0xFF3B82F6),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_DESIGNERS,
              title: "Designer Master",
              subtitle: "Manage jewellery designers, linked smiths & dealers",
              icon: Icons.brush_rounded,
              color: Color(0xFFE11D48),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_PRODUCTS,
              title: "Product Master",
              subtitle: "Products, calculation types, SKU/Open stock & stone options",
              icon: Icons.category_rounded,
              color: Color(0xFF8B5CF6),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_SUBPRODUCTS,
              title: "Sub-Product Master",
              subtitle: "Sub-assembly parts, stone options & product breakdowns",
              icon: Icons.account_tree_rounded,
              color: Color(0xFFEC4899),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_STYLES,
              title: "Style Master",
              subtitle: "Product styles, design variants & model patterns",
              icon: Icons.style_rounded,
              color: Color(0xFF06B6D4),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_SIZES,
              title: "Size Master",
              subtitle: "Product sizes, dimensions & length specifications",
              icon: Icons.straighten_rounded,
              color: Color(0xFFF59E0B),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_PRICE_SETTING,
              title: "Price Setting",
              subtitle: "Configure weight ranges, VA%, wastage & making charges per dealer",
              icon: Icons.price_change_rounded,
              color: Color(0xFF6366F1),
            ),
            MenuTreeNode(
              code: MenuRegistry.MASTER_INVENTORY_DIAMOND_PRICE_SETTING,
              title: "Diamond Price Setting",
              subtitle: "Configure cent weight ranges & cent rates for diamond/stone products",
              icon: Icons.diamond_rounded,
              color: Color(0xFF0284C7),
            ),
          ],
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_SALES_AND_PRICE,
          title: "Rate Master",
          subtitle: "Purity-based daily board rates, metal rates & rate history",
          icon: Icons.price_change_rounded,
          color: Color(0xFFF59E0B),
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_LOGIN_USERS,
          title: "User Master & Security",
          subtitle: "Login credentials, central login & menu permissions",
          icon: Icons.admin_panel_settings_rounded,
          color: Color(0xFF06B6D4),
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_EMPLOYEES,
          title: "Employee Master",
          subtitle: "Staff directory, branch assignment & contact details",
          icon: Icons.badge_rounded,
          color: Color(0xFF8B5CF6),
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_ACCOUNT_HEAD,
          title: "Account Head Master",
          subtitle: "Ledgers, groupings, and contact info",
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFFEF4444),
        ),
        MenuTreeNode(
          code: MenuRegistry.MASTER_TAX_MASTER,
          title: "Tax Master",
          subtitle: "Configure SGST, CGST, IGST tax rates & slabs",
          icon: Icons.percent_rounded,
          color: Color(0xFF10B981),
        ),
      ],
    ),

    // 1b. SMITH PURCHASE MODULE (Between Master and Stock)
    const MenuTreeNode(
      code: MenuRegistry.MENU_SMITH_PURCHASE,
      title: "Smith Purchase",
      subtitle: "Gold bar & ornament purchases, receipts & smith metal ledger",
      icon: Icons.diamond_rounded,
      color: Color(0xFFD97706),
      children: [
        MenuTreeNode(
          code: MenuRegistry.SMITH_PURCHASE_ENTRY,
          title: "Smith Purchase Entry",
          subtitle: "Gold bar & ornament purchase transaction entry",
          icon: Icons.add_circle_outline_rounded,
          color: Color(0xFFD97706),
        ),
        MenuTreeNode(
          code: MenuRegistry.SMITH_PURCHASE_REGISTER,
          title: "Smith Purchase Register",
          subtitle: "View and filter previous smith purchase bills",
          icon: Icons.receipt_long_rounded,
          color: Color(0xFFD97706),
        ),
        MenuTreeNode(
          code: MenuRegistry.SMITH_PURCHASE_RECEIPT,
          title: "Smith Receipt / Inward",
          subtitle: "Receive manufactured ornaments & gold bars from smiths",
          icon: Icons.move_to_inbox_rounded,
          color: Color(0xFFD97706),
        ),
        MenuTreeNode(
          code: MenuRegistry.SMITH_PURCHASE_SMITH_LEDGER,
          title: "Smith Metal & Cash Ledger",
          subtitle: "Smith-wise outstanding pure gold, fine silver & cash balance",
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFFD97706),
        ),
      ],
    ),

    // 2. STOCK MODULE
    const MenuTreeNode(
      code: MenuRegistry.MENU_STOCK,
      title: "Stock & Inventory",
      subtitle: "Live ornament weight, barcoding & physical audit",
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF10B981),
      children: [
        MenuTreeNode(
          code: MenuRegistry.STOCK_PREPARE_FOR_SKU,
          title: "Prepare for SKU",
          subtitle: "Prepare and group ornament lots, purity rates & stones for SKU generation",
          icon: Icons.post_add_rounded,
          color: Color(0xFF4F46E5),
        ),
        MenuTreeNode(
          code: MenuRegistry.STOCK_LIVE_INVENTORY,
          title: "Live Stock & Tray Balance",
          subtitle: "Real-time gross/net gold & stone inventory balance",
          icon: Icons.grid_view_rounded,
          color: Color(0xFF10B981),
        ),
        MenuTreeNode(
          code: MenuRegistry.STOCK_ENTRY,
          title: "Stock Inward & Invoicing",
          subtitle: "Receive ornaments from bullion dealers / karigars",
          icon: Icons.add_box_rounded,
          color: Color(0xFF10B981),
        ),
        MenuTreeNode(
          code: MenuRegistry.STOCK_BARCODE_TAGS,
          title: "Barcode & RFID Tagging",
          subtitle: "Generate jewelry tags with QR codes & gross weight",
          icon: Icons.qr_code_2_rounded,
          color: Color(0xFF06B6D4),
        ),
        MenuTreeNode(
          code: MenuRegistry.STOCK_AUDIT,
          title: "Physical Stock Audit",
          subtitle: "Tray-wise physical barcode scanning & variance check",
          icon: Icons.fact_check_rounded,
          color: Color(0xFFF59E0B),
        ),
      ],
    ),

    // 3. ESTIMATE MODULE (3rd Main Menu)
    const MenuTreeNode(
      code: MenuRegistry.MENU_ESTIMATE,
      title: "Estimate & Quotation",
      subtitle: "Pre-sale ornament estimates, rate lock quotations & slip printing",
      icon: Icons.request_quote_rounded,
      color: Color(0xFFF97316),
      children: [
        MenuTreeNode(
          code: MenuRegistry.ESTIMATE_NEW,
          title: "New Estimate Quotation",
          subtitle: "Calculate live weight, making charges & gold preview",
          icon: Icons.add_circle_outline_rounded,
          color: Color(0xFFF97316),
        ),
        MenuTreeNode(
          code: MenuRegistry.ESTIMATE_REGISTER,
          title: "Estimates Register",
          subtitle: "Browse quotations history, print slips & track conversions",
          icon: Icons.history_edu_rounded,
          color: Color(0xFF10B981),
        ),
        MenuTreeNode(
          code: MenuRegistry.ESTIMATE_CONVERT,
          title: "Convert to POS Invoice",
          subtitle: "Instant conversion of approved estimates into retail GST invoice",
          icon: Icons.transform_rounded,
          color: Color(0xFF6366F1),
        ),
      ],
    ),

    // 4. POS MODULE
    const MenuTreeNode(
      code: MenuRegistry.MENU_POS,
      title: "POS & Retail Billing",
      subtitle: "Retail invoicing, estimation & old gold purchases",
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFFEC4899),
      children: [
        MenuTreeNode(
          code: MenuRegistry.POS_BILLING,
          title: "Retail Sales Billing",
          subtitle: "Fast barcode scan, GST tax invoice & multi-pay modes",
          icon: Icons.receipt_long_rounded,
          color: Color(0xFFEC4899),
        ),
        MenuTreeNode(
          code: MenuRegistry.POS_ESTIMATION,
          title: "Quotation & Estimation",
          subtitle: "Generate pre-sale gold estimates & rate freeze quotes",
          icon: Icons.calculate_rounded,
          color: Color(0xFFF59E0B),
        ),
        MenuTreeNode(
          code: MenuRegistry.POS_RETURN_EXCHANGE,
          title: "Sales Return & Exchange",
          subtitle: "Credit notes, ornament exchanges & buyback deductions",
          icon: Icons.swap_horizontal_circle_rounded,
          color: Color(0xFF06B6D4),
        ),
        MenuTreeNode(
          code: MenuRegistry.POS_OLD_GOLD_PURCHASE,
          title: "Old Gold / Scrap Purchase",
          subtitle: "Melting test, purity appraisal & customer scrap buy",
          icon: Icons.recycling_rounded,
          color: Color(0xFFFFD700),
        ),
      ],
    ),

    // 4. REPORT MODULE
    const MenuTreeNode(
      code: MenuRegistry.MENU_REPORT,
      title: "Reports & GST Filing",
      subtitle: "Sales register, daybook, stock ledger & tax reports",
      icon: Icons.analytics_rounded,
      color: Color(0xFFF59E0B),
      children: [
        MenuTreeNode(
          code: MenuRegistry.REPORT_SALES,
          title: "Daily & Monthly Sales Register",
          subtitle: "Detailed itemized sales, payment summary & cashier audit",
          icon: Icons.bar_chart_rounded,
          color: Color(0xFFF59E0B),
        ),
        MenuTreeNode(
          code: MenuRegistry.REPORT_DAYBOOK,
          title: "Cash & Bank Daybook",
          subtitle: "Cash counter flow, credit card & UPI reconciliation",
          icon: Icons.book_rounded,
          color: Color(0xFF10B981),
        ),
        MenuTreeNode(
          code: MenuRegistry.REPORT_STOCK_LEDGER,
          title: "Metal Stock Ledger",
          subtitle: "Gold weight in/out movement, purity conversion ledger",
          icon: Icons.table_chart_rounded,
          color: Color(0xFF6366F1),
        ),
        MenuTreeNode(
          code: MenuRegistry.REPORT_GST_GSTR1,
          title: "GST GSTR-1 & HSN Summary",
          subtitle: "3% GST tax breakdown, B2B/B2C invoices & JSON export",
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFFEC4899),
        ),
      ],
    ),

    // 5. DIGIGOLD MODULE
    const MenuTreeNode(
      code: MenuRegistry.MENU_DIGIGOLD,
      title: "Digital Gold & Vault",
      subtitle: "24K 99.9% Digital Gold buy/sell & SIP accumulation plans",
      icon: Icons.monetization_on_rounded,
      color: Color(0xFFFFD700),
      children: [
        MenuTreeNode(
          code: MenuRegistry.DIGIGOLD_VAULT,
          title: "Customer DigiGold Vault",
          subtitle: "Fractional 24K pure gold holdings & physical redemption",
          icon: Icons.lock_clock_rounded,
          color: Color(0xFFFFD700),
        ),
        MenuTreeNode(
          code: MenuRegistry.DIGIGOLD_BUY_SELL,
          title: "Live Gold Buy / Sell Desk",
          subtitle: "Instant spot price trading & ledger settlement",
          icon: Icons.currency_exchange_rounded,
          color: Color(0xFF10B981),
        ),
        MenuTreeNode(
          code: MenuRegistry.DIGIGOLD_SIP_PLANS,
          title: "Gold SIP & Monthly Schemes",
          subtitle: "Automated recurring accumulation savings schemes",
          icon: Icons.savings_rounded,
          color: Color(0xFF06B6D4),
        ),
      ],
    ),

    // 6. CRM & SCHEMES MODULE
    const MenuTreeNode(
      code: MenuRegistry.MENU_CRM,
      title: "Customer CRM & Schemes",
      subtitle: "Client profiles, gold chit funds & WhatsApp/SMS alerts",
      icon: Icons.groups_rounded,
      color: Color(0xFF8B5CF6),
      children: [
        MenuTreeNode(
          code: MenuRegistry.CRM_CUSTOMERS,
          title: "Customer Directory & KYC",
          subtitle: "PAN/Aadhaar details, purchase history & loyalty points",
          icon: Icons.person_search_rounded,
          color: Color(0xFF8B5CF6),
        ),
        MenuTreeNode(
          code: MenuRegistry.CRM_GOLD_SCHEMES,
          title: "Gold Savings Chit Schemes",
          subtitle: "11-month installment schemes & bonus redemption",
          icon: Icons.card_giftcard_rounded,
          color: Color(0xFFEC4899),
        ),
        MenuTreeNode(
          code: MenuRegistry.CRM_ALERTS_REMINDERS,
          title: "Alerts, Wishes & Reminders",
          subtitle: "Birthday/Anniversary greetings & payment due reminders",
          icon: Icons.notifications_active_rounded,
          color: Color(0xFFF59E0B),
        ),
      ],
    ),

    // 7. SETTINGS MODULE
    const MenuTreeNode(
      code: MenuRegistry.MENU_SETTINGS,
      title: "Store Settings & System",
      subtitle: "Invoice layout, thermal printer & database sync",
      icon: Icons.settings_suggest_rounded,
      color: Color(0xFF06B6D4),
      children: [
        MenuTreeNode(
          code: MenuRegistry.SETTINGS_STORE,
          title: "Store Profile & Invoicing Setup",
          subtitle: "Store logo, terms & conditions, QR code & header/footer",
          icon: Icons.store_mall_directory_rounded,
          color: Color(0xFF06B6D4),
        ),
        MenuTreeNode(
          code: MenuRegistry.SETTINGS_PRINTER,
          title: "Printer & Hardware Config",
          subtitle: "Thermal slip, A4 laser & jewelry barcode tag printers",
          icon: Icons.print_rounded,
          color: Color(0xFF6366F1),
        ),
        MenuTreeNode(
          code: MenuRegistry.SETTINGS_DB_STATUS,
          title: "Database Status",
          subtitle: "PostgreSQL schema health and table metrics",
          icon: Icons.pie_chart_rounded,
          color: Color(0xFF06B6D4),
        ),
        MenuTreeNode(
          code: MenuRegistry.SETTINGS_SYSTEM_CONTROLS,
          title: "System Controls",
          subtitle: "Module parameters, global configuration values & branch overrides",
          icon: Icons.tune_rounded,
          color: Color(0xFFF59E0B),
        ),
        MenuTreeNode(
          code: MenuRegistry.SETTINGS_TURSO_SYNC,
          title: "PostgreSQL Schema & Query Tool",
          subtitle: "PostgreSQL schema health, latency & SQL console",
          icon: Icons.cloud_sync_rounded,
          color: Color(0xFF10B981),
        ),
        MenuTreeNode(
          code: MenuRegistry.SETTINGS_REINSTALL_SYNC,
          title: "Reinstall / Sync Schema",
          subtitle: "Synchronize missing tables, barcode templates & migrations",
          icon: Icons.system_update_rounded,
          color: Color(0xFF6366F1),
        ),
      ],
    ),
  ];

  /// Returns total number of leaf menu items
  static int get totalMenuItemsCount {
    int count = 0;
    for (final root in fullTree) {
      count += root.allLeafCodes.length;
    }
    return count;
  }

  /// All leaf codes in the entire application
  static List<String> get allLeafCodes {
    final List<String> list = [];
    for (final root in fullTree) {
      list.addAll(root.allLeafCodes);
    }
    return list;
  }
}

/// Interactive .NET-Style Tree View Component for Menu Permissions
class MenuPermissionsTreeView extends StatefulWidget {
  final List<String> initialSelectedMenus;
  final ValueChanged<List<String>> onPermissionsChanged;
  final bool readOnly;

  const MenuPermissionsTreeView({
    super.key,
    required this.initialSelectedMenus,
    required this.onPermissionsChanged,
    this.readOnly = false,
  });

  @override
  State<MenuPermissionsTreeView> createState() => _MenuPermissionsTreeViewState();
}

class _MenuPermissionsTreeViewState extends State<MenuPermissionsTreeView> {
  late Set<String> _selectedCodes;
  final Set<String> _expandedNodes = {};
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCodes = Set.from(widget.initialSelectedMenus);
    // Expand all parent nodes by default
    for (final node in MenuTreeRegistry.fullTree) {
      _expandedNodes.add(node.code);
    }
  }

  @override
  void didUpdateWidget(covariant MenuPermissionsTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedMenus != widget.initialSelectedMenus) {
      _selectedCodes = Set.from(widget.initialSelectedMenus);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onPermissionsChanged(_selectedCodes.toList());
    setState(() {});
  }

  // Check if a parent node is fully selected, partially selected, or unselected
  bool _isNodeFullySelected(MenuTreeNode node) {
    final leafCodes = node.allLeafCodes;
    if (leafCodes.isEmpty) return false;
    return leafCodes.every((code) => _selectedCodes.contains(code));
  }

  bool _isNodePartiallySelected(MenuTreeNode node) {
    final leafCodes = node.allLeafCodes;
    if (leafCodes.isEmpty) return false;
    final selectedCount = leafCodes.where((code) => _selectedCodes.contains(code)).length;
    return selectedCount > 0 && selectedCount < leafCodes.length;
  }

  void _toggleNode(MenuTreeNode node) {
    if (widget.readOnly) return;
    final leafCodes = node.allLeafCodes;
    final fullySelected = _isNodeFullySelected(node);

    if (fullySelected) {
      // Unselect all under this node
      _selectedCodes.removeAll(leafCodes);
    } else {
      // Select all under this node
      _selectedCodes.addAll(leafCodes);
    }
    _notifyChange();
  }

  void _toggleLeaf(String code) {
    if (widget.readOnly) return;
    if (_selectedCodes.contains(code)) {
      _selectedCodes.remove(code);
    } else {
      _selectedCodes.add(code);
    }
    _notifyChange();
  }

  // Quick Preset Actions
  void _selectAll() {
    if (widget.readOnly) return;
    _selectedCodes = Set.from(MenuTreeRegistry.allLeafCodes);
    _notifyChange();
  }

  void _clearAll() {
    if (widget.readOnly) return;
    _selectedCodes.clear();
    _notifyChange();
  }

  void _applyPreset(List<String> codes) {
    if (widget.readOnly) return;
    _selectedCodes = Set.from(codes);
    _notifyChange();
  }

  void _expandAll() {
    setState(() {
      for (final node in MenuTreeRegistry.fullTree) {
        _expandedNodes.add(node.code);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedNodes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalAvailable = MenuTreeRegistry.totalMenuItemsCount;
    final totalSelected = _selectedCodes.where((code) => MenuTreeRegistry.allLeafCodes.contains(code)).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Toolbar (.NET Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: GlassTheme.primaryNeon.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_tree_rounded, size: 18, color: GlassTheme.primaryNeon),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Menu Access Permissions (.NET Tree View)",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: GlassTheme.textPrimary,
                            ),
                          ),
                          Text(
                            "Select which modules and submenus this user is allowed to access",
                            style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),

                    // Counter Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: totalSelected > 0
                            ? GlassTheme.primaryNeon.withValues(alpha: 0.1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: totalSelected > 0
                              ? GlassTheme.primaryNeon.withValues(alpha: 0.3)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        "$totalSelected of $totalAvailable Menus",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: totalSelected > 0 ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),

                if (!widget.readOnly) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // Quick Role Presets & Expand Controls Bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Quick Presets:",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: GlassTheme.textMuted),
                      ),
                      _buildPresetChip("Full Admin", () => _selectAll(), GlassTheme.primaryNeon),
                      _buildPresetChip(
                        "Billing Cashier",
                        () => _applyPreset([
                          MenuRegistry.POS_BILLING,
                          MenuRegistry.POS_ESTIMATION,
                          MenuRegistry.POS_RETURN_EXCHANGE,
                          MenuRegistry.POS_OLD_GOLD_PURCHASE,
                          MenuRegistry.REPORT_SALES,
                          MenuRegistry.CRM_CUSTOMERS,
                        ]),
                        GlassTheme.accentEmerald,
                      ),
                      _buildPresetChip(
                        "Store Manager",
                        () => _applyPreset([
                          MenuRegistry.MASTER_ORGANIZATION_COMPANY,
                          MenuRegistry.MASTER_ORGANIZATION_BRANCHES,
                          MenuRegistry.MASTER_INVENTORY,
                          MenuRegistry.MASTER_SALES_AND_PRICE,
                          MenuRegistry.STOCK_LIVE_INVENTORY,
                          MenuRegistry.STOCK_ENTRY,
                          MenuRegistry.STOCK_BARCODE_TAGS,
                          MenuRegistry.STOCK_AUDIT,
                          MenuRegistry.POS_BILLING,
                          MenuRegistry.POS_ESTIMATION,
                          MenuRegistry.POS_RETURN_EXCHANGE,
                          MenuRegistry.POS_OLD_GOLD_PURCHASE,
                          MenuRegistry.REPORT_SALES,
                          MenuRegistry.REPORT_DAYBOOK,
                          MenuRegistry.REPORT_STOCK_LEDGER,
                          MenuRegistry.CRM_CUSTOMERS,
                          MenuRegistry.CRM_GOLD_SCHEMES,
                        ]),
                        GlassTheme.accentCyan,
                      ),
                      _buildPresetChip(
                        "Accountant / Auditor",
                        () => _applyPreset([
                          MenuRegistry.MASTER_ORGANIZATION_COMPANY,
                          MenuRegistry.REPORT_SALES,
                          MenuRegistry.REPORT_DAYBOOK,
                          MenuRegistry.REPORT_STOCK_LEDGER,
                          MenuRegistry.REPORT_GST_GSTR1,
                          MenuRegistry.POS_BILLING,
                          MenuRegistry.CRM_CUSTOMERS,
                        ]),
                        GlassTheme.accentAmber,
                      ),
                      _buildPresetChip("Clear All", () => _clearAll(), GlassTheme.accentRose),

                      // Expand / Collapse controls
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _expandAll,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text("Expand All", style: TextStyle(fontSize: 11, color: GlassTheme.primaryNeon, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const Text("•", style: TextStyle(color: GlassTheme.textMuted)),
                      InkWell(
                        onTap: _collapseAll,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text("Collapse All", style: TextStyle(fontSize: 11, color: GlassTheme.textMuted, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // Search inside tree
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Filter menu options...",
                    hintStyle: const TextStyle(fontSize: 12, color: GlassTheme.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: GlassTheme.textMuted),
                    suffixIcon: _searchFilter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 14),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchFilter = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

          // Scrollable Tree Structure Content
          Container(
            constraints: const BoxConstraints(maxHeight: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: MenuTreeRegistry.fullTree.map((rootNode) {
                  return _buildTreeNode(rootNode, level: 0);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }

  // Recursive Tree Node Builder
  Widget _buildTreeNode(MenuTreeNode node, {required int level}) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expandedNodes.contains(node.code);

    // If searching, filter nodes
    if (_searchFilter.isNotEmpty) {
      final matchesSearch = node.title.toLowerCase().contains(_searchFilter) ||
          node.subtitle.toLowerCase().contains(_searchFilter) ||
          node.code.toLowerCase().contains(_searchFilter) ||
          node.children.any((child) =>
              child.title.toLowerCase().contains(_searchFilter) ||
              child.subtitle.toLowerCase().contains(_searchFilter) ||
              child.code.toLowerCase().contains(_searchFilter));
      if (!matchesSearch) return const SizedBox.shrink();
    }

    final isFullySelected = hasChildren ? _isNodeFullySelected(node) : _selectedCodes.contains(node.code);
    final isPartiallySelected = hasChildren ? _isNodePartiallySelected(node) : false;

    final selectedChildrenCount = hasChildren
        ? node.allLeafCodes.where((code) => _selectedCodes.contains(code)).length
        : 0;

    return Padding(
      padding: EdgeInsets.only(left: level * 16.0, bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: isFullySelected
              ? node.color.withValues(alpha: 0.04)
              : isPartiallySelected
                  ? node.color.withValues(alpha: 0.02)
                  : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFullySelected
                ? node.color.withValues(alpha: 0.3)
                : isPartiallySelected
                    ? node.color.withValues(alpha: 0.2)
                    : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            // Node Header Tile
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: hasChildren
                  ? () {
                      setState(() {
                        if (isExpanded) {
                          _expandedNodes.remove(node.code);
                        } else {
                          _expandedNodes.add(node.code);
                        }
                      });
                    }
                  : () => _toggleLeaf(node.code),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Expand/Collapse Chevron (for parents)
                    if (hasChildren)
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedNodes.remove(node.code);
                            } else {
                              _expandedNodes.add(node.code);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                            size: 14,
                            color: node.color,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 20),

                    // Custom Tri-State Checkbox
                    InkWell(
                      onTap: () {
                        if (hasChildren) {
                          _toggleNode(node);
                        } else {
                          _toggleLeaf(node.code);
                        }
                      },
                      child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: isFullySelected
                              ? node.color
                              : isPartiallySelected
                                  ? node.color.withValues(alpha: 0.15)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFullySelected || isPartiallySelected
                                ? node.color
                                : const Color(0xFF94A3B8),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isFullySelected
                              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                              : isPartiallySelected
                                  ? Container(
                                      width: 8,
                                      height: 2.5,
                                      decoration: BoxDecoration(
                                        color: node.color,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    )
                                  : null,
                        ),
                      ),
                    ),

                    // Node Icon
                    Icon(node.icon, size: 16, color: node.color),
                    const SizedBox(width: 8),

                    // Node Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                node.title,
                                style: TextStyle(
                                  fontSize: level == 0 ? 13 : 12,
                                  fontWeight: level == 0 ? FontWeight.w800 : FontWeight.w600,
                                  color: GlassTheme.textPrimary,
                                ),
                              ),
                              if (level == 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: node.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "$selectedChildrenCount / ${node.allLeafCodes.length}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: node.color,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (node.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              node.subtitle,
                              style: const TextStyle(fontSize: 10, color: GlassTheme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Node Code Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        node.code,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: GlassTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Children List (if parent and expanded)
            if (hasChildren && isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Column(
                  children: node.children.map((childNode) {
                    return _buildTreeNode(childNode, level: level + 1);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tenant_model.dart';
import '../providers/auth_provider.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _sqlController = TextEditingController(
    text: "SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema() AND table_type = 'BASE TABLE';",
  );

  QueryResult? _queryResult;
  bool _isExecutingQuery = false;
  String? _queryError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _runQuery(AuthProvider auth, String query) async {
    setState(() {
      _isExecutingQuery = true;
      _queryError = null;
    });

    final result = await auth.executeQuery(query);

    setState(() {
      _isExecutingQuery = false;
      _queryResult = result;
      if (!result.success) {
        _queryError = result.message ?? "Query execution failed.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final tenant = auth.currentTenant;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 960;

    if (tenant == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: GlassTheme.bgDark,
      body: Stack(
        children: [
          // Background ambient light gradients
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.primaryNeon.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.accentEmerald.withOpacity(0.1),
              ),
            ),
          ),

          // Main Layout
          SafeArea(
            child: Column(
              children: [
                // Top Glass Navigation Bar
                _buildTopNavBar(context, auth, tenant),

                // Main Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tenant Overview Banner
                        _buildWelcomeBanner(tenant, auth),
                        const SizedBox(height: 20),

                        // 4 Metric Stats Cards Grid
                        _buildStatsGrid(tenant, auth, isDesktop),
                        const SizedBox(height: 24),

                        // Database Management Glass Panel
                        _buildDatabasePanel(auth, isDesktop),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TOP NAV BAR =================
  Widget _buildTopNavBar(BuildContext context, AuthProvider auth, Tenant tenant) {
    return GlassContainer(
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      margin: EdgeInsets.zero,
      borderColor: const Color(0xFFE2E8F0),
      child: Row(
        children: [
          // Brand Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: GlassTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.layers_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "ProGold",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: GlassTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                "Multi-Tenant Portal",
                style: TextStyle(fontSize: 11, color: GlassTheme.textMuted),
              ),
            ],
          ),

          const Spacer(),

          // Validity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tenant.isActive ? GlassTheme.accentEmerald.withValues(alpha: 0.12) : GlassTheme.accentRose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: tenant.isActive ? GlassTheme.accentEmerald.withValues(alpha: 0.4) : GlassTheme.accentRose.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tenant.isActive ? Icons.verified_rounded : Icons.timer_off_rounded,
                  size: 14,
                  color: tenant.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                ),
                const SizedBox(width: 6),
                Text(
                  tenant.isActive
                      ? "Active • ${tenant.daysRemaining} Days Left"
                      : "Subscription Expired",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tenant.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // User Profile Info
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: GlassTheme.primaryNeon.withValues(alpha: 0.15),
                child: Text(
                  tenant.email.isNotEmpty ? tenant.email[0].toUpperCase() : 'T',
                  style: const TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              if (MediaQuery.of(context).size.width > 700)
                Text(
                  tenant.email,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
                ),
            ],
          ),

          const SizedBox(width: 16),

          // Logout Button
          IconButton(
            tooltip: "Logout Tenant",
            icon: const Icon(Icons.logout_rounded, color: GlassTheme.accentRose, size: 20),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
    );
  }

  // ================= WELCOME BANNER =================
  Widget _buildWelcomeBanner(Tenant tenant, AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      gradient: LinearGradient(
        colors: [
          GlassTheme.primaryNeon.withValues(alpha: 0.08),
          GlassTheme.accentCyan.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Tenant Workspace: ",
                      style: TextStyle(fontSize: 14, color: GlassTheme.textSecondary),
                    ),
                    Text(
                      tenant.email,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GlassTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Connected to an isolated PostgreSQL tenant schema",
                  style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Refresh Database Health & Tables",
            icon: const Icon(Icons.refresh_rounded, color: GlassTheme.primaryNeon),
            onPressed: () => auth.fetchTenantDbOverview(),
          ),
        ],
      ),
    );
  }

  // ================= METRICS STATS GRID =================
  Widget _buildStatsGrid(Tenant tenant, AuthProvider auth, bool isDesktop) {
    final health = auth.tenantDbHealth;
    final totalTables = auth.tenantTables.length;
    final totalRows = auth.tenantTables.fold<int>(0, (sum, t) => sum + t.rowCount);

    final cards = [
      _buildStatCard(
        title: "Validation Period",
        value: "${tenant.daysRemaining} Days",
        subtitle: "${tenant.validFrom} to ${tenant.validTo}",
        icon: Icons.calendar_month_rounded,
        accentColor: GlassTheme.accentEmerald,
      ),
      _buildStatCard(
        title: "PostgreSQL Schema",
        value: health?.success == true ? "Connected" : "Online",
        subtitle: health != null ? "${health.latencyMs}ms Latency" : tenant.schemaName,
        icon: Icons.cloud_done_rounded,
        accentColor: GlassTheme.accentCyan,
      ),
      _buildStatCard(
        title: "Tenant Tables",
        value: "$totalTables Tables",
        subtitle: "$totalRows Total Records",
        icon: Icons.table_chart_rounded,
        accentColor: GlassTheme.primaryNeon,
      ),
      _buildStatCard(
        title: "Contact Info",
        value: tenant.contactNumber.isNotEmpty ? tenant.contactNumber : "Verified",
        subtitle: "Tenant ID: #${tenant.id}",
        icon: Icons.contact_phone_rounded,
        accentColor: GlassTheme.accentAmber,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
      );
    } else {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      borderColor: accentColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ================= DATABASE MANAGEMENT PANEL =================
  Widget _buildDatabasePanel(AuthProvider auth, bool isDesktop) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Tab Bar
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, color: GlassTheme.primaryNeon, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    "PostgreSQL Database Console",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reinstall DB Schema Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      backgroundColor: const Color(0xFFECFDF5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: auth.isReinstallingDb
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                          )
                        : const Icon(Icons.published_with_changes_rounded, size: 16),
                    label: Text(
                      auth.isReinstallingDb ? "Reinstalling..." : "Reinstall / Sync Schema",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: auth.isReinstallingDb ? null : () => _showReinstallSchemaDialog(context, auth),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicator: BoxDecoration(
                        gradient: GlassTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: GlassTheme.textSecondary,
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: "SQL Query Editor"),
                        Tab(text: "Tables & Schema"),
                        Tab(text: "Quick Templates"),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tab Content
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSqlQueryTab(auth),
                _buildTablesTab(auth),
                _buildTemplatesTab(auth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: SQL QUERY EDITOR
  Widget _buildSqlQueryTab(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Editor
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Editor toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code_rounded, size: 16, color: GlassTheme.primaryNeon),
                    const SizedBox(width: 8),
                    const Text(
                      "Execute SQL on Tenant Database",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.textSecondary),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      icon: const Icon(Icons.clear_all_rounded, size: 14, color: GlassTheme.textMuted),
                      label: const Text("Clear", style: TextStyle(fontSize: 11, color: GlassTheme.textMuted)),
                      onPressed: () => _sqlController.clear(),
                    ),
                  ],
                ),
              ),
              // SQL Input
              TextField(
                controller: _sqlController,
                maxLines: 4,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  color: GlassTheme.primaryNeon,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: "Enter SQL query (e.g. SELECT * FROM customers;)",
                  hintStyle: TextStyle(color: GlassTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            GlassButton(
              height: 40,
              label: "Execute Query",
              icon: Icons.play_arrow_rounded,
              isLoading: _isExecutingQuery,
              onPressed: () => _runQuery(auth, _sqlController.text.trim()),
            ),
            const SizedBox(width: 12),
            if (_queryResult != null && _queryResult!.success) ...[
              StatusBadge(
                label: "${_queryResult!.executionTimeMs}ms • ${_queryResult!.rows.length} rows returned",
                color: GlassTheme.accentEmerald,
                icon: Icons.timer_outlined,
              ),
            ],
          ],
        ),

        const SizedBox(height: 14),

        // Result Container
        Expanded(
          child: _buildQueryResultView(),
        ),
      ],
    );
  }

  Widget _buildQueryResultView() {
    if (_queryError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GlassTheme.accentRose.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GlassTheme.accentRose.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: GlassTheme.accentRose, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _queryError!,
                style: const TextStyle(color: GlassTheme.accentRose, fontSize: 13, fontFamily: 'Courier'),
              ),
            ),
          ],
        ),
      );
    }

    if (_queryResult == null) {
      return Center(
        child: Text(
          "Run a query to view results here.",
          style: TextStyle(color: GlassTheme.textMuted.withOpacity(0.7), fontSize: 13),
        ),
      );
    }

    if (_queryResult!.columns.isEmpty && _queryResult!.rowsAffected >= 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: GlassTheme.accentEmerald, size: 36),
            const SizedBox(height: 8),
            Text(
              "Statement executed successfully! (${_queryResult!.rowsAffected} rows affected)",
              style: const TextStyle(color: GlassTheme.accentEmerald, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: _queryResult!.columns
                .map(
                  (col) => DataColumn(
                    label: Text(
                      col,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: GlassTheme.primaryNeon,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
            rows: _queryResult!.rows.map((row) {
              List<dynamic> values = [];
              if (row is Map) {
                values = _queryResult!.columns.map((col) => row[col]).toList();
              } else if (row is List) {
                values = row;
              }
              return DataRow(
                cells: values
                    .map(
                      (val) => DataCell(
                        Text(
                          val?.toString() ?? 'NULL',
                          style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary),
                        ),
                      ),
                    )
                    .toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // TAB 2: TABLES & SCHEMA
  Widget _buildTablesTab(AuthProvider auth) {
    if (auth.isLoadingTables) {
      return const Center(child: CircularProgressIndicator());
    }

    if (auth.tenantTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_clear_rounded, size: 40, color: GlassTheme.textMuted),
            const SizedBox(height: 10),
            const Text(
              "No tables found in this tenant database.",
              style: TextStyle(color: GlassTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.published_with_changes_rounded, size: 16),
              label: const Text("Install Complete ProGold ERP Schema", style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => _showReinstallSchemaDialog(context, auth),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text("Or browse sample templates"),
              onPressed: () => _tabController.animateTo(2),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: auth.tenantTables.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final table = auth.tenantTables[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_view_rounded, size: 18, color: GlassTheme.accentEmerald),
                  const SizedBox(width: 8),
                  Text(
                    table.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                  ),
                  const Spacer(),
                  StatusBadge(
                    label: "${table.rowCount} rows",
                    color: GlassTheme.accentCyan,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18, color: GlassTheme.primaryNeon),
                    tooltip: "Query this table",
                    onPressed: () {
                      _sqlController.text = "SELECT * FROM \"${table.name}\" LIMIT 50;";
                      _tabController.animateTo(0);
                      _runQuery(auth, _sqlController.text);
                    },
                  ),
                ],
              ),
              if (table.sql.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    table.sql,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // TAB 3: QUICK TEMPLATES
  Widget _buildTemplatesTab(AuthProvider auth) {
    return ListView(
      children: [
        _buildTemplateItem(
          title: "Customers & Invoices Schema",
          desc: "Creates 'customers' and 'invoices' tables for managing tenant clients and billing.",
          sql: "CREATE TABLE IF NOT EXISTS customers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT UNIQUE, phone TEXT, created_at TEXT);\nCREATE TABLE IF NOT EXISTS invoices (id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id INTEGER, amount REAL, status TEXT DEFAULT 'PENDING', issue_date TEXT);",
          auth: auth,
        ),
        const SizedBox(height: 12),
        _buildTemplateItem(
          title: "Products & Inventory Schema",
          desc: "Creates 'products' and 'inventory_logs' tables with SKU, price, and stock levels.",
          sql: "CREATE TABLE IF NOT EXISTS products (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, sku TEXT UNIQUE, price REAL, stock INTEGER DEFAULT 0);\nCREATE TABLE IF NOT EXISTS inventory_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER, change_amount INTEGER, reason TEXT, timestamp TEXT);",
          auth: auth,
        ),
        const SizedBox(height: 12),
        _buildTemplateItem(
          title: "Insert Demo Data",
          desc: "Populates sample records for testing queries and charts.",
          sql: "INSERT INTO customers (name, email, phone, created_at) VALUES ('Alice Johnson', 'alice@corp.com', '+1-555-0199', NOW()), ('Bob Smith', 'bob@tech.io', '+1-555-0288', NOW());\nINSERT INTO products (title, sku, price, stock) VALUES ('Pro Gold License', 'PGL-01', 499.00, 100), ('PostgreSQL Enterprise Node', 'PEN-02', 1299.00, 50);",
          auth: auth,
        ),
      ],
    );
  }

  Widget _buildTemplateItem({
    required String title,
    required String desc,
    required String sql,
    required AuthProvider auth,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: GlassTheme.accentEmerald,
                  side: const BorderSide(color: GlassTheme.accentEmerald),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text("Run Template", style: TextStyle(fontSize: 12)),
                onPressed: () {
                  _sqlController.text = sql;
                  _tabController.animateTo(0);
                  _runQuery(auth, sql);
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: GlassTheme.textMuted),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text("Load into Editor", style: TextStyle(fontSize: 12)),
                onPressed: () {
                  _sqlController.text = sql;
                  _tabController.animateTo(0);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReinstallSchemaDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.published_with_changes_rounded, color: GlassTheme.accentEmerald, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              "Reinstall Database Schema",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This will verify and synchronize your private PostgreSQL schema with the full ProGold ERP structure (products, categories, live gold rates, inventory, customers, invoices, and payments).",
              style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: GlassTheme.accentEmerald),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Safe & Non-destructive: Existing tenant data (invoices, clients, custom records) will NOT be deleted.",
                      style: TextStyle(fontSize: 11.5, color: GlassTheme.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.build_circle_rounded, size: 16),
            label: const Text("Reinstall Schema Now", style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final result = await auth.reinstallDatabase();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: result['success'] == true ? const Color(0xFF059669) : const Color(0xFFE11D48),
                    content: Text(
                      result['message'] ?? (result['success'] == true ? "Schema reinstalled successfully!" : "Reinstall failed."),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

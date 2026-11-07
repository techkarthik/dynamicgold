import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class DatabaseStatusScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const DatabaseStatusScreen({super.key, this.onBack});

  @override
  State<DatabaseStatusScreen> createState() => _DatabaseStatusScreenState();
}

class _DatabaseStatusScreenState extends State<DatabaseStatusScreen> {
  final ApiService _api = ApiService();

  bool _isLoadingMetrics = false;
  bool _isLoadingTables = false;
  bool _tablesLoaded = false;
  bool _isOptimizing = false;
  bool _isSyncingSchema = false;

  Map<String, dynamic>? _dbStatus;
  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _filteredTables = [];
  String _tableSearch = '';
  int _tablesLoadTimeMs = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDatabaseMetrics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fast query for core storage, quota, engine, and latency metrics
  Future<void> _loadDatabaseMetrics() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoadingMetrics = true);

    try {
      final res = await _api.getTenantDbStatus(token, includeTables: false);
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _dbStatus = res['database'] as Map<String, dynamic>?;
            _isLoadingMetrics = false;
          });
        } else {
          setState(() => _isLoadingMetrics = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Failed to load database status"),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMetrics = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    }
  }

  /// On-demand query to fetch full breakdown of tables, columns, and record counts
  Future<void> _loadDatabaseTables() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoadingTables = true);

    try {
      final startTime = DateTime.now();
      final res = await _api.getTenantDbTables(token);
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      if (mounted) {
        if (res['success'] == true) {
          final tablesList = (res['tables'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
          setState(() {
            _tables = tablesList;
            _tablesLoaded = true;
            _tablesLoadTimeMs = int.tryParse(res['executionTimeMs']?.toString() ?? '$elapsed') ?? elapsed;
            _applyTableFilter(_tableSearch);
            _isLoadingTables = false;
          });
        } else {
          setState(() => _isLoadingTables = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Failed to load tables"),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTables = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading tables: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    }
  }

  void _applyTableFilter(String query) {
    _tableSearch = query.trim().toLowerCase();
    if (_tableSearch.isEmpty) {
      _filteredTables = List.from(_tables);
    } else {
      _filteredTables = _tables.where((t) {
        final name = (t['name'] ?? '').toString().toLowerCase();
        return name.contains(_tableSearch);
      }).toList();
    }
  }

  Future<void> _reinstallDatabaseSchema() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSyncingSchema = true);

    try {
      final res = await _api.reinstallTenantDatabase(token);
      if (mounted) {
        final isOk = res['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? (isOk ? "Schema synchronized successfully!" : "Reinstall failed")),
            backgroundColor: isOk ? GlassTheme.accentEmerald : GlassTheme.accentRose,
            duration: const Duration(seconds: 4),
          ),
        );
        if (isOk) {
          await _loadDatabaseMetrics();
          if (_tablesLoaded) {
            await _loadDatabaseTables();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Schema sync error: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingSchema = false);
    }
  }

  void _showReinstallDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 10),
            Text("Reinstall / Sync Schema", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: const Text(
          "This action safely verifies and synchronizes all provisioned ERP tables, column schemas, and performance indexes into your private tenant database.\n\nAll existing records will remain completely intact.\n\nDo you want to proceed?",
          style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: const Text("Run Schema Sync", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _reinstallDatabaseSchema();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _optimizeDatabase() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isOptimizing = true);

    try {
      final res = await _api.optimizeTenantDb(token);
      if (mounted) {
        final isOk = res['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? (isOk ? "Database optimized successfully!" : "Optimization failed")),
            backgroundColor: isOk ? GlassTheme.accentEmerald : GlassTheme.accentRose,
          ),
        );
        if (isOk) {
          await _loadDatabaseMetrics();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Optimization error: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isOptimizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Bar
        _buildHeaderBar(isMobile),
        const SizedBox(height: 16),

        if (_isLoadingMetrics)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: GlassTheme.primaryNeon),
                  SizedBox(height: 14),
                  Text("Querying live database metrics...", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        else if (_dbStatus == null)
          _buildErrorState()
        else ...[
          // 2. Storage & Quota Hero Gauges (Fast loading)
          _buildStorageGauges(isMobile),
          const SizedBox(height: 16),

          // 3. Database Connection & System Metadata
          _buildConnectionMetadataCard(isMobile),
          const SizedBox(height: 16),

          // 4. Tables Storage Breakdown (On-Demand Loading)
          _buildTablesSection(isMobile),
        ],
      ],
    );
  }

  // ================= HEADER BAR =================
  Widget _buildHeaderBar(bool isMobile) {
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
                  icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Back to Settings Menu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
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
                child: const Icon(Icons.storage_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "PostgreSQL Schema Status",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "PostgreSQL", color: Color(0xFF06B6D4)),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Monitor PostgreSQL connectivity, tenant schema, and table metrics",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
                icon: _isSyncingSchema
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.system_update_rounded, size: 16),
                label: Text(_isSyncingSchema ? "Syncing..." : "Reinstall / Sync Schema", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _isSyncingSchema ? null : _showReinstallDialog,
              ),
              GlassSecondaryButton(
                label: _isOptimizing ? "Optimizing..." : "Optimize DB",
                icon: Icons.auto_fix_high_rounded,
                onPressed: _isOptimizing ? () {} : _optimizeDatabase,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Refresh Metrics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _loadDatabaseMetrics,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= STORAGE & QUOTA HERO GAUGES =================
  Widget _buildStorageGauges(bool isMobile) {
    final totalSizeFormatted = _dbStatus?['total_size_formatted']?.toString() ?? '0.00 KB';
    final latencyMs = int.tryParse(_dbStatus?['latency_ms']?.toString() ?? '0') ?? 0;
    final totalTables = int.tryParse(_dbStatus?['total_tables']?.toString() ?? '0') ?? 0;

    return Column(
      children: [
        // 4 KPI Summary Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 36) / 4;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildKpiCard(
                  width: cardWidth,
                  title: "Tenant Schema Size",
                  value: totalSizeFormatted,
                  subtext: "PostgreSQL relations in this schema",
                  icon: Icons.data_usage_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: "Database Capacity",
                  value: "Shared",
                  subtext: "Capacity managed by Aiven",
                  icon: Icons.cloud_done_rounded,
                  color: const Color(0xFF10B981),
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: "Cloud Connection Latency",
                  value: "$latencyMs ms",
                  subtext: latencyMs < 80 ? "⚡ Ultra Fast" : latencyMs < 150 ? "Normal Latency" : "Fair",
                  icon: Icons.speed_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _buildKpiCard(
                  width: cardWidth,
                  title: "Provisioned Tables",
                  value: "$totalTables Tables",
                  subtext: _tablesLoaded ? "${_tables.fold<int>(0, (sum, t) => sum + (int.tryParse(t['rowCount']?.toString() ?? '0') ?? 0))} Total Records" : "Click below to view breakdown",
                  icon: Icons.table_chart_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // PostgreSQL reports shared database capacity rather than per-schema quotas.
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart_rounded, color: Color(0xFF06B6D4), size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Tenant Schema Storage",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  Text(
                    totalSizeFormatted,
                    style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "This is the size of this tenant's schema. Instance-level capacity and quotas are managed by the PostgreSQL provider.",
                style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: GlassTheme.textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ================= CONNECTION & ENGINE DETAILS =================
  Widget _buildConnectionMetadataCard(bool isMobile) {
    final engine = _dbStatus?['engine'] ?? 'PostgreSQL';
    final postgresVersion = _dbStatus?['postgres_version'] ?? '';
    final schemaName = _dbStatus?['schema_name'] ?? '';
    final status = _dbStatus?['status'] ?? 'ONLINE & HEALTHY';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Color(0xFF6366F1), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Database Engine & Connection Info",
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),

          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _buildMetaField("Database Engine", engine),
              _buildMetaField("PostgreSQL Version", postgresVersion),
              _buildMetaField("Tenant Schema", schemaName),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ================= TABLES STORAGE BREAKDOWN (ON-DEMAND) =================
  Widget _buildTablesSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Action Bar
          Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.table_rows_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Database Tables & Row Metrics",
                          style: TextStyle(color: GlassTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tablesLoaded
                              ? "${_tables.length} provisioned tables (${_tablesLoadTimeMs}ms) • Optional on-demand view"
                              : "Optional diagnostics • Load tables breakdown on demand",
                          style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!_tablesLoaded) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        icon: _isLoadingTables
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.visibility_rounded, size: 16),
                        label: Text(
                          _isLoadingTables ? "Loading Tables..." : "📊 View Database Tables & Metrics",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _isLoadingTables ? null : _loadDatabaseTables,
                      ),
                    ] else ...[
                      SizedBox(
                        width: isMobile ? 160 : 220,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _applyTableFilter(val)),
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: GlassTheme.textSecondary),
                            hintText: "Search tables...",
                            hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF8B5CF6))),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isLoadingTables
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text("Refresh Tables", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: _isLoadingTables ? null : _loadDatabaseTables,
                      ),
                      IconButton(
                        tooltip: "Hide Tables Breakdown",
                        icon: const Icon(Icons.keyboard_arrow_up_rounded, color: GlassTheme.textSecondary),
                        onPressed: () => setState(() => _tablesLoaded = false),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Content Area
          if (!_tablesLoaded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.table_view_rounded, size: 36, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Table Diagnostics are Optional",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "For maximum screen speed, table schema details and record counts are loaded only when requested.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 1,
                      ),
                      icon: _isLoadingTables
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.analytics_rounded, size: 18),
                      label: Text(
                        _isLoadingTables ? "Querying Cloud Tables..." : "Load Database Tables & Metrics",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _isLoadingTables ? null : _loadDatabaseTables,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // DataTable with Provisioned Tables
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  dataRowColor: WidgetStateProperty.all(Colors.white),
                  columns: const [
                    DataColumn(label: Text("TABLE NAME", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                    DataColumn(label: Text("TYPE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                    DataColumn(label: Text("RECORDS / ROWS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                    DataColumn(label: Text("COLUMNS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                    DataColumn(label: Text("ESTIMATED SIZE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                    DataColumn(label: Text("STATUS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
                  ],
                  rows: _filteredTables.map((t) {
                    final name = t['name']?.toString() ?? '';
                    final type = t['type']?.toString() ?? 'table';
                    final rowCount = int.tryParse(t['rowCount']?.toString() ?? '0') ?? 0;
                    final columnCount = int.tryParse(t['columnCount']?.toString() ?? '0') ?? 0;
                    final sizeFormatted = t['estimatedSizeFormatted']?.toString() ?? '4.00 KB';

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF06B6D4)),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                            ],
                          ),
                        ),
                        DataCell(Text(type.toUpperCase(), style: const TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "$rowCount records",
                              style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(Text("$columnCount cols", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
                        DataCell(Text(sizeFormatted, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text("Active", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= ERROR STATE =================
  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: GlassTheme.accentRose),
            const SizedBox(height: 12),
            const Text("Unable to fetch database status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text("Check the backend server connection and PostgreSQL configuration.", style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadDatabaseMetrics,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
              child: const Text("Retry Connection", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

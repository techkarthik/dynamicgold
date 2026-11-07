import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/rate_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';

class SalesAndPriceScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SalesAndPriceScreen({super.key, this.onBack});

  @override
  State<SalesAndPriceScreen> createState() => _SalesAndPriceScreenState();
}

class _SalesAndPriceScreenState extends State<SalesAndPriceScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isAlreadySavedForDate = false;

  // Rate entries for the selected date (controllers mapped by purityid)
  List<PurityRateItem> _purityRates = [];
  final Map<int, TextEditingController> _rateControllers = {};
  final Map<int, TextEditingController> _buyRateControllers = {};
  final Map<int, TextEditingController> _notesControllers = {};

  // Rate History state
  List<RateHistoryRecord> _historyRecords = [];
  bool _isLoadingHistory = false;
  String _historyMetalFilter = 'ALL';
  DateTime? _historyFromDate;
  DateTime? _historyToDate;
  final TextEditingController _historySearchController = TextEditingController();
  String _historySearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRatesForSelectedDate();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeControllers();
    _historySearchController.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _rateControllers.values) {
      c.dispose();
    }
    for (final c in _buyRateControllers.values) {
      c.dispose();
    }
    for (final c in _notesControllers.values) {
      c.dispose();
    }
    _rateControllers.clear();
    _buyRateControllers.clear();
    _notesControllers.clear();
  }

  String _formatDate(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadRatesForSelectedDate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final formatted = _formatDate(_selectedDate);
      final res = await _api.getRatesByDate(token, formatted);

      if (mounted) {
        final rates = res['rates'] as List<PurityRateItem>? ?? [];
        _isAlreadySavedForDate = res['is_already_saved_for_date'] == true;

        _disposeControllers();
        for (final r in rates) {
          // Initialize with rounded whole Rupee values
          _rateControllers[r.purityid] = TextEditingController(
            text: r.rate > 0 ? r.rate.round().toString() : '',
          );
          _buyRateControllers[r.purityid] = TextEditingController(
            text: r.buyRate > 0 ? r.buyRate.round().toString() : '',
          );
          _notesControllers[r.purityid] = TextEditingController(text: r.notes);
        }

        setState(() {
          _purityRates = rates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading purity rates: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  Future<void> _loadHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoadingHistory = true);

    try {
      final records = await _api.getRateHistory(
        token,
        fromDate: _historyFromDate != null ? _formatDate(_historyFromDate!) : null,
        toDate: _historyToDate != null ? _formatDate(_historyToDate!) : null,
        metalId: _historyMetalFilter != 'ALL' ? _historyMetalFilter : null,
        limit: 150,
      );

      if (mounted) {
        setState(() {
          _historyRecords = records;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: GlassTheme.accentAmber,
              onPrimary: Colors.white,
              onSurface: GlassTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadRatesForSelectedDate();
    }
  }

  void _shiftDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadRatesForSelectedDate();
  }

  Future<void> _saveRates() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    final List<PurityRateItem> payloadRates = [];
    for (final p in _purityRates) {
      final rateText = _rateControllers[p.purityid]?.text.trim() ?? '';
      final buyRateText = _buyRateControllers[p.purityid]?.text.trim() ?? '';
      final notesText = _notesControllers[p.purityid]?.text.trim() ?? '';

      // Round to nearest whole Rupee (removes paise)
      final rateVal = (double.tryParse(rateText) ?? 0.0).roundToDouble();
      final buyRateVal = (double.tryParse(buyRateText) ?? 0.0).roundToDouble();

      payloadRates.add(
        p.copyWith(
          rate: rateVal,
          buyRate: buyRateVal,
          sellRate: rateVal,
          notes: notesText,
        ),
      );
    }

    final formatted = _formatDate(_selectedDate);
    final res = await _api.saveBulkRates(token, formatted, payloadRates);

    setState(() => _isSaving = false);

    if (res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(res['message'] ?? "Board rates saved successfully!")),
              ],
            ),
            backgroundColor: GlassTheme.accentEmerald,
          ),
        );
      }
      await _loadRatesForSelectedDate();
      await _loadHistory();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Failed to save board rates."),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  Future<void> _deleteHistoryEntry(RateHistoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Rate Record", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          "Are you sure you want to delete rate for ${record.purityname} on ${record.ratedate} (₹${record.rate.toStringAsFixed(2)})?",
          style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.authToken;
      if (token == null) return;

      final res = await _api.deleteRateRecord(token, record.id);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rate record deleted successfully."), backgroundColor: GlassTheme.accentEmerald),
          );
        }
        await _loadHistory();
        await _loadRatesForSelectedDate();
      }
    }
  }

  void _exportHistoryCsv() {
    if (_historyRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No rate history to export.")),
      );
      return;
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln("Record ID,Batch No,Rate Date,Metal,Purity Name,Purity %,Board Rate (Rs/g),Buy Back (Rs/g),Notes,Recorded Timestamp");

    for (final h in _historyRecords) {
      final safeName = '"${h.purityname.replaceAll('"', '""')}"';
      final safeNotes = '"${h.notes.replaceAll('"', '""')}"';
      final timeStr = h.createdAt.isNotEmpty ? h.createdAt : h.updatedAt;
      buffer.writeln("#${h.id},Batch #${h.batchId},${h.ratedate},${h.metalname},$safeName,${h.purity},${h.rate},${h.buyRate},$safeNotes,$timeStr");
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text("Rate history CSV copied to clipboard successfully!"),
          ],
        ),
        backgroundColor: GlassTheme.accentEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          if (_tabController.index == 0) ...[
            _buildDateAndStatusControlBar(),
            const SizedBox(height: 14),
            _buildManualRateHelpCard(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(60.0),
                  child: CircularProgressIndicator(color: GlassTheme.accentAmber),
                ),
              )
            else if (_purityRates.isEmpty)
              _buildNoPuritiesState()
            else
              _buildPurityRateCards(),
          ] else ...[
            _buildHistoryFilterBar(),
            const SizedBox(height: 16),
            if (_isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(60.0),
                  child: CircularProgressIndicator(color: GlassTheme.accentAmber),
                ),
              )
            else
              _buildHistoryTable(),
          ],
        ],
      ),
    );
  }

  // ================= HEADER & BREADCRUMB =================
  Widget _buildHeader() {
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
              color: GlassTheme.accentAmber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.price_change_rounded, color: GlassTheme.accentAmber, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Master",
                      style: TextStyle(color: GlassTheme.textSecondary.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 14, color: GlassTheme.textSecondary),
                    const Text(
                      "Rate Master",
                      style: TextStyle(color: GlassTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  "Rate Master (Daily Purity Rates)",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Set daily gold, silver & metal board rates based on Purity Master with audit history",
                  style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB BAR =================
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: GlassTheme.accentAmber,
        unselectedLabelColor: GlassTheme.textSecondary,
        indicatorColor: GlassTheme.accentAmber,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        onTap: (index) {
          setState(() {});
          if (index == 1) _loadHistory();
        },
        tabs: const [
          Tab(
            icon: Icon(Icons.edit_calendar_rounded, size: 18),
            text: "Daily Rate Entry & Board Rates",
          ),
          Tab(
            icon: Icon(Icons.history_rounded, size: 18),
            text: "Rate Update History & Logs",
          ),
        ],
      ),
    );
  }

  // ================= DATE & PUBLISH CONTROL BAR =================
  Widget _buildDateAndStatusControlBar() {
    final formattedDate = _formatDate(_selectedDate);
    final isToday = _formatDate(DateTime.now()) == formattedDate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Date Selector Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: GlassTheme.textPrimary),
                tooltip: "Previous Day",
                onPressed: () => _shiftDate(-1),
              ),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GlassTheme.accentAmber.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 18, color: GlassTheme.accentAmber),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GlassTheme.accentEmerald.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "TODAY",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: GlassTheme.accentEmerald),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: GlassTheme.textPrimary),
                tooltip: "Next Day",
                onPressed: () => _shiftDate(1),
              ),
              if (!isToday)
                TextButton.icon(
                  icon: const Icon(Icons.today_rounded, size: 16, color: GlassTheme.accentAmber),
                  label: const Text("Go to Today", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: GlassTheme.accentAmber)),
                  onPressed: () {
                    setState(() => _selectedDate = DateTime.now());
                    _loadRatesForSelectedDate();
                  },
                ),
            ],
          ),

          // Status Badge & Save Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Saved Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isAlreadySavedForDate
                      ? GlassTheme.accentEmerald.withOpacity(0.1)
                      : GlassTheme.accentAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isAlreadySavedForDate
                        ? GlassTheme.accentEmerald.withOpacity(0.4)
                        : GlassTheme.accentAmber.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAlreadySavedForDate ? Icons.verified_rounded : Icons.pending_rounded,
                      size: 16,
                      color: _isAlreadySavedForDate ? GlassTheme.accentEmerald : GlassTheme.accentAmber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAlreadySavedForDate ? "RATES PUBLISHED FOR DATE" : "PENDING RATE UPDATE",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _isAlreadySavedForDate ? GlassTheme.accentEmerald : GlassTheme.accentAmber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentAmber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _isSaving ? "Saving..." : "Save & Publish Rates",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _isSaving ? null : _saveRates,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= MANUAL RATE ENTRY HELP BANNER =================
  Widget _buildManualRateHelpCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: GlassTheme.accentAmber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Enter board rates manually per gram in whole Rupees (₹/g). Rates are automatically rounded to whole Rupee (no paise) and every update is logged in audit history.",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ================= PURITY RATE ENTRY CARDS =================
  Widget _buildPurityRateCards() {
    // Group purities by Metal
    final Map<String, List<PurityRateItem>> grouped = {};
    for (final p in _purityRates) {
      final metalKey = p.metalname.isNotEmpty ? p.metalname : p.metalid;
      grouped.putIfAbsent(metalKey, () => []).add(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final metalName = entry.key;
        final list = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x040F172A), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metal Section Title
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _getMetalColor(list.first.metalid),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$metalName Purities & Board Rates",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    "${list.length} Purity Grades",
                    style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              // Table / Grid of Purities
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  if (isWide) {
                    return _buildDesktopRateTable(list);
                  } else {
                    return _buildMobileRateCards(list);
                  }
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getMetalColor(String metalId) {
    switch (metalId.toUpperCase()) {
      case 'G':
        return GlassTheme.accentAmber;
      case 'S':
        return GlassTheme.accentCyan;
      case 'P':
        return GlassTheme.secondaryNeon;
      default:
        return GlassTheme.primaryNeon;
    }
  }

  Widget _buildDesktopRateTable(List<PurityRateItem> items) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.5), // Purity Name & Short code
        1: FlexColumnWidth(1.2), // Purity %
        2: FlexColumnWidth(1.8), // Last Known Rate
        3: FlexColumnWidth(2.2), // Today's Board Rate Input (₹/g)
        4: FlexColumnWidth(2.0), // Buy Back Rate Input (₹/g)
        5: FlexColumnWidth(2.5), // Notes
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Table Header
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          children: [
            _buildTableHeaderCell("Purity Name"),
            _buildTableHeaderCell("Purity %"),
            _buildTableHeaderCell("Last Known Rate"),
            _buildTableHeaderCell("Board Rate (₹/g) *"),
            _buildTableHeaderCell("Buy Back Rate (₹/g)"),
            _buildTableHeaderCell("Remarks / Notes"),
          ],
        ),
        // Rows
        ...items.map((p) {
          final rateCtrl = _rateControllers[p.purityid]!;
          final buyRateCtrl = _buyRateControllers[p.purityid]!;
          final notesCtrl = _notesControllers[p.purityid]!;

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            children: [
              // Purity Name
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getMetalColor(p.metalid).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.purityshortname.isNotEmpty ? p.purityshortname : p.metalid,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _getMetalColor(p.metalid)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.purityname,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GlassTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

              // Purity %
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${p.purity.toStringAsFixed(1)}%",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Last Known Rate
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.rate > 0 ? "₹${p.rate.round()}" : "No prior rate",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.rate > 0 ? GlassTheme.textPrimary : GlassTheme.textSecondary,
                      ),
                    ),
                    if (p.previousRateDate.isNotEmpty)
                      Text(
                        p.previousRateDate,
                        style: const TextStyle(fontSize: 10, color: GlassTheme.textSecondary),
                      ),
                  ],
                ),
              ),

              // Board Rate Input (₹/g)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GlassTheme.textPrimary),
                    decoration: InputDecoration(
                      prefixText: "₹ ",
                      hintText: "e.g. 7450",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GlassTheme.accentAmber, width: 1.5)),
                    ),
                  ),
                ),
              ),

              // Buy Back Rate Input (₹/g)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: buyRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
                    decoration: InputDecoration(
                      prefixText: "₹ ",
                      hintText: "e.g. 7300",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: GlassTheme.accentAmber)),
                    ),
                  ),
                ),
              ),

              // Remarks / Notes
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: notesCtrl,
                    style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Market note...",
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
      ),
    );
  }

  Widget _buildMobileRateCards(List<PurityRateItem> items) {
    return Column(
      children: items.map((p) {
        final rateCtrl = _rateControllers[p.purityid]!;
        final buyRateCtrl = _buyRateControllers[p.purityid]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(p.purityname, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                    child: Text("${p.purity}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Board Rate (₹/g) *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            decoration: const InputDecoration(
                              prefixText: "₹ ",
                              hintText: "e.g. 7450",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Buy Back (₹/g)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: buyRateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            decoration: const InputDecoration(
                              prefixText: "₹ ",
                              hintText: "e.g. 7300",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ================= RATE HISTORY & AUDIT LOG TAB =================
  Widget _buildHistoryFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x040F172A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search Input
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: _historySearchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "Search history...",
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
              onChanged: (v) => setState(() => _historySearchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Filters (Metal + Date Range + Export)
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Total updates logged pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  "${_historyRecords.length} Total Updates Logged",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                ),
              ),

              // Metal Filter
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _historyMetalFilter,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text("All Metals")),
                      DropdownMenuItem(value: 'G', child: Text("Gold Only")),
                      DropdownMenuItem(value: 'S', child: Text("Silver Only")),
                      DropdownMenuItem(value: 'P', child: Text("Platinum Only")),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _historyMetalFilter = v);
                        _loadHistory();
                      }
                    },
                  ),
                ),
              ),

              // Export CSV
              IconButton(
                icon: const Icon(Icons.download_rounded, color: GlassTheme.accentAmber),
                tooltip: "Copy History CSV",
                onPressed: _exportHistoryCsv,
              ),

              // Refresh
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: GlassTheme.textSecondary),
                tooltip: "Refresh History",
                onPressed: _loadHistory,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable() {
    final filtered = _historyRecords.where((h) {
      if (_historySearchQuery.isEmpty) return true;
      return h.id.toString().contains(_historySearchQuery) ||
          h.batchId.toString().contains(_historySearchQuery) ||
          h.ratedate.contains(_historySearchQuery) ||
          h.purityname.toLowerCase().contains(_historySearchQuery) ||
          h.metalname.toLowerCase().contains(_historySearchQuery) ||
          h.rate.toString().contains(_historySearchQuery) ||
          h.notes.toLowerCase().contains(_historySearchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 40, color: GlassTheme.textSecondary),
            SizedBox(height: 12),
            Text("No historical rate records found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Every published rate update will automatically appear here as an audit log.", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            horizontalMargin: 20,
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text("Rate # / ID", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Rate Date & Time", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Metal", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Purity Grade", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Purity %", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Board Rate (₹/g)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Buy Back (₹/g)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Remarks / Notes", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            ],
            rows: filtered.map((h) {
              String timeDisplay = "";
              if (h.createdAt.contains("T")) {
                final timePart = h.createdAt.split("T")[1];
                timeDisplay = timePart.length >= 8 ? timePart.substring(0, 8) : timePart;
              }

              return DataRow(
                cells: [
                  // Rate # / Unique Integer ID Badge
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "#${h.id}",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF8B5CF6)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "B#${h.batchId}",
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: GlassTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rate Date & Time
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GlassTheme.accentAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            h.ratedate,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: GlassTheme.accentAmber),
                          ),
                        ),
                        if (timeDisplay.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            timeDisplay,
                            style: const TextStyle(fontSize: 10, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Metal
                  DataCell(Text(h.metalname, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),

                  // Purity Grade
                  DataCell(Text(h.purityname, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),

                  // Purity %
                  DataCell(Text("${h.purity}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),

                  // Board Rate (₹/g)
                  DataCell(
                    Text("₹${h.rate.round()}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GlassTheme.textPrimary)),
                  ),

                  // Buy Back (₹/g)
                  DataCell(
                    Text(h.buyRate > 0 ? "₹${h.buyRate.round()}" : "-", style: const TextStyle(fontSize: 12)),
                  ),

                  // Remarks / Notes
                  DataCell(
                    Text(
                      h.notes.isNotEmpty ? h.notes : "-",
                      style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
                    ),
                  ),

                  // Actions
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: GlassTheme.accentRose),
                      tooltip: "Delete rate entry #${h.id}",
                      onPressed: () => _deleteHistoryEntry(h),
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

  // ================= NO PURITIES EMPTY STATE =================
  Widget _buildNoPuritiesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: GlassTheme.accentAmber, size: 40),
          SizedBox(height: 16),
          Text("No Purity Master grades found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text("Please configure your metal purities under Item Master > Purity Master first.", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/location_data.dart';
import '../models/company_model.dart';
import '../models/branch_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class CompanyMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CompanyMasterScreen({super.key, this.onBack});

  @override
  State<CompanyMasterScreen> createState() => _CompanyMasterScreenState();
}

class _CompanyMasterScreenState extends State<CompanyMasterScreen> {
  final ApiService _api = ApiService();

  List<Company> _companies = [];
  List<Company> _filteredCompanies = [];
  List<Branch> _dbBranches = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  Company? _editingCompany;
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _gstController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _accountController = TextEditingController();
  int _selectedCountryId = 1; // India default
  int? _selectedStateId = 33; // Tamil Nadu default
  String? _selectedBranchId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _gstController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getCompanies(token),
      _api.getBranches(token),
    ]);

    if (mounted) {
      setState(() {
        _companies = results[0] as List<Company>;
        _dbBranches = results[1] as List<Branch>;
        _applyFilter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredCompanies = List.from(_companies);
    } else {
      _filteredCompanies = _companies.where((c) {
        return c.companyId.toLowerCase().contains(_searchQuery) ||
            c.companyName.toLowerCase().contains(_searchQuery) ||
            c.gstNo.toLowerCase().contains(_searchQuery) ||
            c.mobileNumber.toLowerCase().contains(_searchQuery) ||
            c.city.toLowerCase().contains(_searchQuery) ||
            c.state.toLowerCase().contains(_searchQuery) ||
            c.country.toLowerCase().contains(_searchQuery) ||
            c.accountName.toLowerCase().contains(_searchQuery) ||
            c.branchId.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  void _openForm([Company? existing]) {
    setState(() {
      _editingCompany = existing;
      _showForm = true;
      if (existing != null) {
        _idController.text = existing.companyId;
        _nameController.text = existing.companyName;
        _gstController.text = existing.gstNo;
        _mobileController.text = existing.mobileNumber;
        _addressController.text = existing.address;
        _cityController.text = existing.city;
        _accountController.text = existing.accountName;

        _selectedCountryId = existing.countryId ?? 1;
        if (LocationData.getCountryById(_selectedCountryId) == null) {
          final cm = LocationData.getCountryByNameOrCode(existing.country);
          _selectedCountryId = cm?.id ?? 1;
        }

        if (existing.stateId != null && existing.stateId! > 0) {
          _selectedStateId = existing.stateId;
        } else if (existing.state.isNotEmpty) {
          final sm = LocationData.getStateByNameOrCode(
            existing.state,
            _selectedCountryId,
          );
          _selectedStateId = sm?.id ?? 33;
        } else {
          _selectedStateId = 33;
        }

        final branchMatches = _dbBranches.where(
          (b) => b.branchId == existing.branchId,
        );
        _selectedBranchId = branchMatches.isNotEmpty ? existing.branchId : null;
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _idController.clear();
    _nameController.clear();
    _gstController.clear();
    _mobileController.clear();
    _addressController.clear();
    _cityController.clear();
    _accountController.clear();
    _selectedCountryId = 1;
    _selectedStateId = 33;
    _selectedBranchId = _dbBranches.isNotEmpty
        ? _dbBranches.first.branchId
        : null;
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingCompany = null;
      _resetFormFields();
    });
  }

  Future<void> _saveCompanyForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final id = _idController.text.trim().toUpperCase();
      final name = _nameController.text.trim();
      final countryObj = LocationData.getCountryById(_selectedCountryId);
      final stateObj = LocationData.getStateById(_selectedStateId ?? 33);

      final record = Company(
        companyId: id,
        companyName: name,
        gstNo: _gstController.text.trim().toUpperCase(),
        mobileNumber: _mobileController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: stateObj?.name ?? 'Tamil Nadu',
        stateId: _selectedStateId ?? 33,
        country: countryObj?.name ?? 'India',
        countryId: _selectedCountryId,
        accountName: _accountController.text.trim(),
        branchId: _selectedBranchId ?? '',
      );

      final isEditing = _editingCompany != null;
      final response = isEditing
          ? await _api.updateCompany(token, _editingCompany!.companyId, record)
          : await _api.createCompany(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? "Company '$name' updated successfully!"
                    : "Company '$name' created successfully!",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
          _closeForm();
          await _loadCompanies();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message']?.toString() ?? "Failed to save company",
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
        // Top Breadcrumb & Actions Bar
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // Embedded In-Page Form
        if (_showForm) ...[
          _buildInPageEntryForm(isMobile),
          const SizedBox(height: 20),
        ],

        // Search & Filter Toolbar
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Main Content Area
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: GlassTheme.primaryNeon),
            ),
          )
        else if (_filteredCompanies.isEmpty)
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
                  tooltip: "Back to Organization Menu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: GlassTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.primaryNeon.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.apartment_rounded,
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
                        "Company Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(
                        label: "Master DB",
                        color: GlassTheme.accentEmerald,
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manage corporate entities, GST, branches & banking details",
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
                onPressed: _loadCompanies,
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
                  _showForm ? Icons.close_rounded : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(
                  _showForm ? "Close Form" : "New Company",
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

  // ================= IN-PAGE ENTRY FORM COMPONENT =================
  Widget _buildInPageEntryForm(bool isMobile) {
    final isEditing = _editingCompany != null;
    final states = LocationData.getStatesForCountry(_selectedCountryId);

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
                        ? Icons.edit_note_rounded
                        : Icons.add_business_rounded,
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
                            ? "Edit Corporate Entity (${_editingCompany!.companyId} - ${_editingCompany!.companyName})"
                            : "Register New Corporate Company",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing
                            ? "Update corporate company registration & address"
                            : "Define corporate business entity, GST number, jurisdiction, and default branch",
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

            // Row 1: Company ID & Company Name
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Company Code *",
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
                        decoration: _inputDecoration("e.g. C01, HO"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Code required";
                          }
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
                        "Company Legal Name *",
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
                          "e.g. Sri Lakshmi Jewellers Pvt Ltd",
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Company name is required";
                          }
                          return null;
                        },
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
                        "GST Number",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _gstController,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. 33AAAAA0000A1Z5"),
                        maxLength: 15,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Row 2: Mobile, City, Country, State
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Mobile / Phone",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. 9876543210"),
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
                        "City",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cityController,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. Chennai"),
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
                        "Country",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCountryId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Country"),
                        items: LocationData.countries.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCountryId = val;
                              final newStates =
                                  LocationData.getStatesForCountry(val);
                              _selectedStateId = newStates.isNotEmpty
                                  ? newStates.first.id
                                  : null;
                            });
                          }
                        },
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
                        "State",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue:
                            _selectedStateId != null &&
                                states.any((s) => s.id == _selectedStateId)
                            ? _selectedStateId
                            : (states.isNotEmpty ? states.first.id : null),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("State"),
                        items: states.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              "${s.name} (${s.code})",
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedStateId = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Row 3: Address & Bank Account & Default Branch
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Corporate Address",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressController,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _inputDecoration(
                          "e.g. 123 Car Street, T Nagar",
                        ),
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
                        "Bank / Account Name",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _accountController,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. HDFC Current A/c"),
                      ),
                    ],
                  ),
                ),
                if (_dbBranches.isNotEmpty)
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Default Branch",
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
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text(
                                "-- None --",
                                style: TextStyle(color: GlassTheme.textMuted),
                              ),
                            ),
                            ..._dbBranches.map(
                              (b) => DropdownMenuItem(
                                value: b.branchId,
                                child: Text(
                                  b.branchName,
                                  style: const TextStyle(
                                    color: GlassTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedBranchId = val),
                        ),
                      ],
                    ),
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
                  label: isEditing ? "Update Company" : "Save Company",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: GlassTheme.primaryGradient,
                  isLoading: _isSaving,
                  onPressed: _saveCompanyForm,
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _applyFilter(val)),
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
                    "Search companies by code, name, GSTIN, city, state, or phone...",
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
              child: const Icon(
                Icons.apartment_rounded,
                size: 48,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching companies found"
                  : "No Companies registered yet",
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query."
                  : "Get started by adding your main company entity and GST details.",
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
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  "Create Company",
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
          children: _filteredCompanies.map((c) {
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
                            c.companyName,
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
                          label: c.companyId,
                          color: GlassTheme.primaryNeon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow(
                      "GST Number",
                      c.gstNo.isNotEmpty ? c.gstNo : "Not provided",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Location",
                      "${c.city.isNotEmpty ? '${c.city}, ' : ''}${c.state}",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Contact Phone",
                      c.mobileNumber.isNotEmpty ? c.mobileNumber : "-",
                    ),
                    if (c.accountName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow("Bank / A/C", c.accountName),
                    ],

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
                          tooltip: "Edit Company",
                          onPressed: () => _openForm(c),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          tooltip: "Delete Company",
                          onPressed: () => _confirmDelete(c),
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
                  "CODE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "COMPANY NAME",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "GSTIN",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "PHONE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CITY",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "STATE",
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
            rows: _filteredCompanies.map((c) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      c.companyId,
                      style: const TextStyle(
                        color: GlassTheme.primaryNeon,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      c.companyName,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      c.gstNo.isNotEmpty ? c.gstNo : "-",
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      c.mobileNumber.isNotEmpty ? c.mobileNumber : "-",
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      c.city,
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      c.state,
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontWeight: FontWeight.w600,
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
                            color: GlassTheme.primaryNeon,
                            size: 18,
                          ),
                          tooltip: "Edit",
                          onPressed: () => _openForm(c),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 18,
                          ),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(c),
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
  void _confirmDelete(Company company) {
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
              "Delete Company",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete company '${company.companyId} - ${company.companyName}'?",
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

              final res = await _api.deleteCompany(token, company.companyId);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? "Company deleted",
                    ),
                    backgroundColor: isOk
                        ? GlassTheme.accentEmerald
                        : GlassTheme.accentRose,
                  ),
                );
                if (isOk) _loadCompanies();
              }
            },
          ),
        ],
      ),
    );
  }
}

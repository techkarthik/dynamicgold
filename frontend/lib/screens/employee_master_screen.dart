import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/employee_model.dart';
import '../models/branch_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';

class EmployeeMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const EmployeeMasterScreen({super.key, this.onBack});

  @override
  State<EmployeeMasterScreen> createState() => _EmployeeMasterScreenState();
}

class _EmployeeMasterScreenState extends State<EmployeeMasterScreen> {
  final ApiService _api = ApiService();

  List<EmployeeRecord> _employees = [];
  List<EmployeeRecord> _filteredEmployees = [];
  List<Branch> _branches = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  // Metadata stats from backend
  int _totalCount = 0;
  int _activeCount = 0;
  int _inactiveCount = 0;
  int _nextEmpId = 1001;

  // Filter States
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE
  String _branchFilter = 'ALL'; // ALL or branchId
  String _bloodGroupFilter = 'ALL'; // ALL, A+, B+, etc.

  final TextEditingController _searchController = TextEditingController();

  // Blood Group Options
  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  EmployeeRecord? _editingEmployee;
  final _formKey = GlobalKey<FormState>();

  final _empIdController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedBranchId;
  final _dojController = TextEditingController();
  String _selectedBloodGroup = 'O+';
  bool _isActive = true;
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _imageController = TextEditingController();
  bool _isSaving = false;
  bool _isUploadingImage = false;
  Uint8List? _localPreviewBytes;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _empIdController.dispose();
    _nameController.dispose();
    _dojController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getEmployeesData(token),
        _api.getBranches(token, companyId: auth.activeCompanyId),
      ]);

      if (mounted) {
        final empData = results[0] as Map<String, dynamic>;
        final branchList = results[1] as List<Branch>;

        setState(() {
          _employees = empData['employees'] as List<EmployeeRecord>? ?? [];
          _totalCount = empData['total_count'] ?? _employees.length;
          _activeCount = empData['active_count'] ?? _employees.where((e) => e.active).length;
          _inactiveCount = empData['inactive_count'] ?? (_totalCount - _activeCount);
          _nextEmpId = empData['next_empid'] ?? 1001;
          _branches = branchList;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading employee data: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredEmployees = _employees.where((emp) {
      // 1. Text Search
      final matchesSearch = query.isEmpty ||
          (emp.empid?.toString() ?? '').contains(query) ||
          emp.empname.toLowerCase().contains(query) ||
          emp.branchid.toLowerCase().contains(query) ||
          emp.branchname.toLowerCase().contains(query) ||
          emp.bloodgroup.toLowerCase().contains(query) ||
          emp.mobile.toLowerCase().contains(query) ||
          emp.email.toLowerCase().contains(query) ||
          emp.address.toLowerCase().contains(query) ||
          emp.dateofjoin.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      // 2. Branch Filter
      if (_branchFilter != 'ALL' && emp.branchid.toUpperCase() != _branchFilter.toUpperCase()) {
        return false;
      }

      // 3. Status Filter
      if (_statusFilter == 'ACTIVE' && !emp.active) return false;
      if (_statusFilter == 'INACTIVE' && emp.active) return false;

      // 4. Blood Group Filter
      if (_bloodGroupFilter != 'ALL' && emp.bloodgroup.toUpperCase() != _bloodGroupFilter.toUpperCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  String _getBranchName(String branchId) {
    final match = _branches.where((b) => b.branchId.toUpperCase() == branchId.toUpperCase()).firstOrNull;
    return match?.branchName ?? branchId;
  }

  void _openForm([EmployeeRecord? existing]) {
    setState(() {
      _editingEmployee = existing;
      _showForm = true;
      _localPreviewBytes = null;
      if (existing != null) {
        _empIdController.text = existing.empid?.toString() ?? '';
        _nameController.text = existing.empname;
        _selectedBranchId = _branches.any((b) => b.branchId.toUpperCase() == existing.branchid.toUpperCase())
            ? existing.branchid
            : (_branches.isNotEmpty ? _branches.first.branchId : null);
        _dojController.text = existing.dateofjoin;
        _selectedBloodGroup = _bloodGroups.contains(existing.bloodgroup) ? existing.bloodgroup : 'O+';
        _isActive = existing.active;
        _mobileController.text = existing.mobile;
        _emailController.text = existing.email;
        _addressController.text = existing.address;
        _imageController.text = existing.image;
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _empIdController.text = _nextEmpId.toString();
    _nameController.clear();
    _selectedBranchId = _branches.isNotEmpty ? _branches.first.branchId : null;
    final today = DateTime.now();
    _dojController.text = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    _selectedBloodGroup = 'O+';
    _isActive = true;
    _mobileController.clear();
    _emailController.clear();
    _addressController.clear();
    _imageController.clear();
    _localPreviewBytes = null;
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingEmployee = null;
      _localPreviewBytes = null;
    });
  }

  Future<void> _selectDateOfJoin() async {
    DateTime initial = DateTime.now();
    if (_dojController.text.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(_dojController.text.trim());
      if (parsed != null) initial = parsed;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: GlassTheme.primaryNeon,
              onPrimary: Colors.white,
              onSurface: GlassTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dojController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  /// Opens native file picker and uploads selected photo directly to ImageKit CDN
  Future<void> _pickAndUploadImage() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expired. Please log in again."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        final bytes = pickedFile.bytes;
        if (bytes == null || bytes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Could not read image file. Please select another image."),
                backgroundColor: GlassTheme.accentRose,
              ),
            );
          }
          return;
        }

        setState(() {
          _localPreviewBytes = bytes;
          _isUploadingImage = true;
        });

        final ext = pickedFile.extension ?? 'png';
        final empIdStr = _empIdController.text.trim().isNotEmpty ? _empIdController.text.trim() : 'emp';
        final fileName = "emp_${empIdStr}_${DateTime.now().millisecondsSinceEpoch}.$ext";

        final uploadRes = await _api.uploadImage(
          token: token,
          fileBytes: bytes,
          fileName: fileName,
          folder: 'employees',
        );

        if (mounted) {
          setState(() => _isUploadingImage = false);

          if (uploadRes['success'] == true && uploadRes['url'] != null) {
            final imageUrl = uploadRes['url'].toString();
            setState(() {
              _imageController.text = imageUrl;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text("Photo uploaded to ImageKit successfully!"),
                  ],
                ),
                backgroundColor: GlassTheme.accentEmerald,
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(uploadRes['message']?.toString() ?? "Failed to upload photo"),
                backgroundColor: GlassTheme.accentRose,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Image upload error: $e"),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  Future<void> _saveEmployeeForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a valid branch assignment."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    final explicitId = int.tryParse(_empIdController.text.trim());

    final employeePayload = EmployeeRecord(
      empid: explicitId,
      empname: _nameController.text.trim(),
      branchid: _selectedBranchId!.trim().toUpperCase(),
      dateofjoin: _dojController.text.trim(),
      active: _isActive,
      bloodgroup: _selectedBloodGroup,
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      image: _imageController.text.trim(),
    );

    Map<String, dynamic> res;
    if (_editingEmployee == null) {
      res = await _api.createEmployee(token, employeePayload);
    } else {
      final targetId = _editingEmployee!.empid ?? explicitId ?? 0;
      res = await _api.updateEmployee(token, targetId, employeePayload);
    }

    setState(() => _isSaving = false);

    if (res['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(res['message'] ?? "Employee saved successfully!")),
              ],
            ),
            backgroundColor: GlassTheme.accentEmerald,
          ),
        );
      }
      _closeForm();
      await _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Failed to save employee record."),
            backgroundColor: GlassTheme.accentRose,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(EmployeeRecord emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GlassTheme.accentRose.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: GlassTheme.accentRose, size: 22),
            ),
            const SizedBox(width: 12),
            const Text("Delete Employee", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "Are you sure you want to permanently delete \"${emp.empname}\" (ID: ${emp.empid})?\n\nThis action cannot be undone.",
          style: const TextStyle(fontSize: 14, color: GlassTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Record", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true && emp.empid != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.authToken;
      if (token == null) return;

      setState(() => _isLoading = true);
      final res = await _api.deleteEmployee(token, emp.empid!);
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? "Employee deleted successfully."),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
        }
        await _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? "Failed to delete employee."),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    }
  }

  void _exportCsv() {
    if (_filteredEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No employee records to export.")),
      );
      return;
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln("Emp ID,Employee Name,Branch ID,Branch Name,Date of Joining,Active,Blood Group,Mobile,Email,Address");

    for (final e in _filteredEmployees) {
      final safeName = '"${e.empname.replaceAll('"', '""')}"';
      final safeBranch = '"${_getBranchName(e.branchid).replaceAll('"', '""')}"';
      final safeAddress = '"${e.address.replaceAll('"', '""')}"';
      buffer.writeln("${e.empid ?? ''},$safeName,${e.branchid},$safeBranch,${e.dateofjoin},${e.active ? 'YES' : 'NO'},${e.bloodgroup},${e.mobile},${e.email},$safeAddress");
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text("Employee CSV copied to clipboard successfully!"),
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
          _buildStatCards(),
          const SizedBox(height: 20),
          if (_showForm) ...[
            _buildInPageForm(),
            const SizedBox(height: 20),
          ],
          _buildActionBar(),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(60.0),
                child: CircularProgressIndicator(color: GlassTheme.primaryNeon),
              ),
            )
          else if (_filteredEmployees.isEmpty)
            _buildEmptyState()
          else if (_isTableView)
            _buildDataTable()
          else
            _buildCardGrid(),
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
              color: GlassTheme.secondaryNeon.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.badge_rounded, color: GlassTheme.secondaryNeon, size: 26),
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
                      "Employee Master",
                      style: TextStyle(color: GlassTheme.secondaryNeon, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  "Employee Master",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Manage store staff, sales personnel, branch assignment, joining dates & bio records",
                  style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.secondaryNeon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: Icon(_showForm ? Icons.close_rounded : Icons.person_add_alt_1_rounded, size: 18),
            label: Text(
              _showForm ? "Close Form" : "+ Add Employee",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    );
  }

  // ================= METRIC STAT CARDS =================
  Widget _buildStatCards() {
    final assignedBranchCount = _employees.map((e) => e.branchid).toSet().length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isMobile ? 1.8 : 2.5,
          children: [
            _buildStatCard(
              title: "Total Staff",
              value: "$_totalCount",
              subtitle: "Registered Employees",
              icon: Icons.groups_rounded,
              color: GlassTheme.secondaryNeon,
            ),
            _buildStatCard(
              title: "Active Staff",
              value: "$_activeCount",
              subtitle: "Currently on Duty",
              icon: Icons.check_circle_rounded,
              color: GlassTheme.accentEmerald,
            ),
            _buildStatCard(
              title: "Inactive Staff",
              value: "$_inactiveCount",
              subtitle: "On Leave / Relieved",
              icon: Icons.pause_circle_rounded,
              color: GlassTheme.accentAmber,
            ),
            _buildStatCard(
              title: "Branches Covered",
              value: "$assignedBranchCount",
              subtitle: "Active Branches",
              icon: Icons.store_mall_directory_rounded,
              color: GlassTheme.accentCyan,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, height: 1.1),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= IN-PAGE REGISTRATION / EDIT FORM =================
  Widget _buildInPageForm() {
    final isEdit = _editingEmployee != null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlassTheme.secondaryNeon.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: GlassTheme.secondaryNeon.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GlassTheme.secondaryNeon.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_note_rounded : Icons.person_add_rounded,
                    color: GlassTheme.secondaryNeon,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? "Edit Employee Details (#${_editingEmployee?.empid ?? ''})" : "New Employee Registration",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                      ),
                      Text(
                        isEdit
                            ? "Update branch assignment, contact information, and active status"
                            : "Enter employee identity, branch, joining date, and contact details",
                        style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: GlassTheme.textSecondary),
                  tooltip: "Cancel",
                  onPressed: _closeForm,
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFE2E8F0)),

            // Form Row 1: Emp ID (Int), Full Name, Branch Dropdown
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 750;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emp ID (Integer)
                      SizedBox(
                        width: 160,
                        child: _buildTextField(
                          controller: _empIdController,
                          label: "Employee ID (Int)",
                          hint: "e.g. 1001",
                          icon: Icons.tag_rounded,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Required";
                            final id = int.tryParse(v.trim());
                            if (id == null || id <= 0) return "Valid integer";
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Employee Name
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          controller: _nameController,
                          label: "Employee Full Name *",
                          hint: "e.g. Rajesh Sharma",
                          icon: Icons.person_rounded,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Please enter employee name";
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Branch Selector
                      Expanded(
                        flex: 3,
                        child: _buildBranchDropdown(),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _empIdController,
                              label: "Employee ID (Int)",
                              hint: "e.g. 1001",
                              icon: Icons.tag_rounded,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return "Required";
                                final id = int.tryParse(v.trim());
                                if (id == null || id <= 0) return "Valid int";
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildBranchDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _nameController,
                        label: "Employee Full Name *",
                        hint: "e.g. Rajesh Sharma",
                        icon: Icons.person_rounded,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Please enter employee name";
                          return null;
                        },
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 14),

            // Form Row 2: Date of Joining, Blood Group, Active Switch
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 750;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date of Joining
                      Expanded(
                        flex: 2,
                        child: _buildDateField(),
                      ),
                      const SizedBox(width: 14),
                      // Blood Group Dropdown
                      Expanded(
                        flex: 2,
                        child: _buildBloodGroupDropdown(),
                      ),
                      const SizedBox(width: 14),
                      // Active Switch Pill
                      Expanded(
                        flex: 2,
                        child: _buildActiveToggle(),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDateField()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildBloodGroupDropdown()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildActiveToggle(),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 14),

            // Form Row 3: Mobile, Email, ImageKit Photo Upload
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _mobileController,
                          label: "Mobile Number",
                          hint: "e.g. 9876543210",
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildTextField(
                          controller: _emailController,
                          label: "Email Address",
                          hint: "e.g. rajesh@progold.com",
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildPhotoUploadField(),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildTextField(
                        controller: _mobileController,
                        label: "Mobile Number",
                        hint: "e.g. 9876543210",
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _emailController,
                        label: "Email Address",
                        hint: "e.g. rajesh@progold.com",
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _buildPhotoUploadField(),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 14),

            // Form Row 4: Address
            _buildTextField(
              controller: _addressController,
              label: "Residential / Postal Address",
              hint: "Street address, City, Pincode",
              icon: Icons.location_on_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Bottom Action Buttons & Image Preview
            Row(
              children: [
                // Quick Preview Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: GlassTheme.secondaryNeon.withOpacity(0.15),
                  backgroundImage: _localPreviewBytes != null
                      ? MemoryImage(_localPreviewBytes!)
                      : (_imageController.text.trim().isNotEmpty
                          ? NetworkImage(_imageController.text.trim())
                          : null),
                  child: (_localPreviewBytes == null && _imageController.text.trim().isEmpty)
                      ? Text(
                          _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()[0].toUpperCase()
                              : "E",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.secondaryNeon),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "New Employee",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GlassTheme.textPrimary),
                ),
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GlassTheme.textSecondary,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _closeForm,
                  child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.secondaryNeon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isSaving ? "Saving..." : (isEdit ? "Update Employee" : "Save Employee"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isSaving ? null : _saveEmployeeForm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Branch Selector Dropdown Field
  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Branch Assignment *",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedBranchId,
              hint: const Text("Select Branch", style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.secondaryNeon),
              items: _branches.map((b) {
                return DropdownMenuItem<String>(
                  value: b.branchId,
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: GlassTheme.secondaryNeon),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${b.branchName} (${b.branchId})",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedBranchId = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // Date of Joining Selector Field
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Date of Joining",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDateOfJoin,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: GlassTheme.secondaryNeon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _dojController.text.trim().isNotEmpty ? _dojController.text : "Select date",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded, color: GlassTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Blood Group Dropdown Field
  Widget _buildBloodGroupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Blood Group",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedBloodGroup,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.accentRose),
              items: _bloodGroups.map((bg) {
                return DropdownMenuItem<String>(
                  value: bg,
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_rounded, size: 16, color: GlassTheme.accentRose),
                      const SizedBox(width: 8),
                      Text(
                        bg,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedBloodGroup = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // Active Toggle Switch
  Widget _buildActiveToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Employment Status",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isActive ? GlassTheme.accentEmerald.withOpacity(0.08) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isActive ? GlassTheme.accentEmerald.withOpacity(0.4) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                    size: 18,
                    color: _isActive ? GlassTheme.accentEmerald : GlassTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isActive ? "ACTIVE STAFF" : "INACTIVE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _isActive ? GlassTheme.accentEmerald : GlassTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isActive,
                activeThumbColor: GlassTheme.accentEmerald,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: GlassTheme.secondaryNeon),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: GlassTheme.secondaryNeon, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ================= IMAGEKIT PHOTO UPLOAD WIDGET =================
  Widget _buildPhotoUploadField() {
    final imageText = _imageController.text.trim();
    final hasImage = _localPreviewBytes != null || imageText.isNotEmpty;
    final isImageKit = imageText.contains("imagekit.io");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Employee Photo",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
            ),
            if (hasImage && isImageKit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: GlassTheme.accentEmerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 10, color: GlassTheme.accentEmerald),
                    SizedBox(width: 4),
                    Text(
                      "ImageKit Hosted",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GlassTheme.accentEmerald),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasImage ? GlassTheme.secondaryNeon.withOpacity(0.5) : const Color(0xFFCBD5E1),
              width: hasImage ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large, Prominent Picture Box Preview
              InkWell(
                onTap: hasImage
                    ? () => _showFullImagePreview(imageText, _nameController.text.trim(), localBytes: _localPreviewBytes)
                    : _pickAndUploadImage,
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x080F172A), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: _localPreviewBytes != null
                            ? Image.memory(
                                _localPreviewBytes!,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                              )
                            : (imageText.isNotEmpty
                                ? Image.network(
                                    imageText,
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: GlassTheme.secondaryNeon),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFFF1F5F9),
                                        child: const Center(
                                          child: Icon(Icons.broken_image_rounded, size: 28, color: GlassTheme.accentRose),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: GlassTheme.secondaryNeon.withOpacity(0.06),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_a_photo_outlined, size: 24, color: GlassTheme.secondaryNeon.withOpacity(0.7)),
                                          const SizedBox(height: 4),
                                          const Text("Add Photo", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: GlassTheme.secondaryNeon)),
                                        ],
                                      ),
                                    ),
                                  )),
                      ),
                    ),
                    if (hasImage)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    if (_isUploadingImage)
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Control & Action Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasImage ? "Photo Attached" : "No photo attached",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: hasImage ? GlassTheme.textPrimary : GlassTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasImage ? "Click picture to zoom preview" : "Upload JPG, PNG, or WEBP",
                      style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasImage ? Colors.white : GlassTheme.secondaryNeon,
                            foregroundColor: hasImage ? GlassTheme.textPrimary : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            elevation: 0,
                            side: hasImage ? const BorderSide(color: Color(0xFFCBD5E1)) : BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: _isUploadingImage
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                )
                              : Icon(
                                  hasImage ? Icons.cached_rounded : Icons.cloud_upload_rounded,
                                  size: 14,
                                ),
                          label: Text(
                            _isUploadingImage
                                ? "Uploading..."
                                : (hasImage ? "Change" : "Upload Photo"),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (hasImage) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GlassTheme.secondaryNeon,
                              side: BorderSide(color: GlassTheme.secondaryNeon.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.fullscreen_rounded, size: 14),
                            label: const Text("View", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            onPressed: () => _showFullImagePreview(imageText, _nameController.text.trim(), localBytes: _localPreviewBytes),
                          ),
                          IconButton(
                            tooltip: "Clear Photo",
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GlassTheme.accentRose),
                            onPressed: () {
                              setState(() {
                                _imageController.clear();
                                _localPreviewBytes = null;
                              });
                            },
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ],
                        IconButton(
                          tooltip: "Edit Raw URL",
                          icon: const Icon(Icons.link_rounded, size: 18, color: GlassTheme.textSecondary),
                          onPressed: () => _showManualUrlDialog(),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullImagePreview(String imageUrl, String empName, {Uint8List? localBytes}) {
    if (imageUrl.isEmpty && localBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x20000000), blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_box_rounded, color: GlassTheme.secondaryNeon, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        empName.isNotEmpty ? empName : "Employee Photo",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: GlassTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: GlassTheme.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              // Image Container
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: localBytes != null
                          ? Image.memory(
                              localBytes,
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(color: Colors.white));
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image_rounded, color: Colors.white70, size: 40),
                                      SizedBox(height: 8),
                                      Text("Failed to load image", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      localBytes != null
                          ? "Preview from device"
                          : (imageUrl.contains('imagekit.io') ? "Hosted on ImageKit CDN" : "External URL"),
                      style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualUrlDialog() {
    final tempController = TextEditingController(text: _imageController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Image URL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter or paste a direct image URL:", style: TextStyle(fontSize: 13, color: GlassTheme.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: tempController,
              decoration: InputDecoration(
                hintText: "https://...",
                prefixIcon: const Icon(Icons.image_rounded, size: 18),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.secondaryNeon, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _imageController.text = tempController.text.trim();
              });
              Navigator.of(ctx).pop();
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );
  }

  // ================= ACTION BAR (SEARCH & FILTERS) =================
  Widget _buildActionBar() {
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
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary),
              decoration: InputDecoration(
                hintText: "Search by ID, name, mobile...",
                hintStyle: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: GlassTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _applyFilter();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: GlassTheme.secondaryNeon),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilter();
                });
              },
            ),
          ),

          // Filters Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Branch Filter
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
                    value: _branchFilter,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: GlassTheme.textSecondary),
                    style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text("All Branches")),
                      ..._branches.map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.branchName))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _branchFilter = val;
                          _applyFilter();
                        });
                      }
                    },
                  ),
                ),
              ),

              // Blood Group Filter
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
                    value: _bloodGroupFilter,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: GlassTheme.accentRose),
                    style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text("All Blood Groups")),
                      ..._bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text("Blood: $bg"))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _bloodGroupFilter = val;
                          _applyFilter();
                        });
                      }
                    },
                  ),
                ),
              ),

              // Status Filter
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
                    value: _statusFilter,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: GlassTheme.textSecondary),
                    style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text("All Status")),
                      DropdownMenuItem(value: 'ACTIVE', child: Text("Active Staff")),
                      DropdownMenuItem(value: 'INACTIVE', child: Text("Inactive")),
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
                ),
              ),

              // Export CSV Button
              IconButton(
                icon: const Icon(Icons.download_rounded, color: GlassTheme.secondaryNeon, size: 20),
                tooltip: "Copy CSV to Clipboard",
                onPressed: _exportCsv,
              ),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: GlassTheme.textSecondary, size: 20),
                tooltip: "Reload Employees",
                onPressed: _loadData,
              ),

              // View Toggle (Card Grid vs Table)
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.grid_view_rounded,
                        size: 18,
                        color: !_isTableView ? GlassTheme.secondaryNeon : GlassTheme.textSecondary,
                      ),
                      tooltip: "Grid View",
                      onPressed: () => setState(() => _isTableView = false),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.table_chart_rounded,
                        size: 18,
                        color: _isTableView ? GlassTheme.secondaryNeon : GlassTheme.textSecondary,
                      ),
                      tooltip: "Table View",
                      onPressed: () => setState(() => _isTableView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= CARD GRID VIEW =================
  Widget _buildCardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 650) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1050) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 220,
          ),
          itemCount: _filteredEmployees.length,
          itemBuilder: (context, index) {
            final emp = _filteredEmployees[index];
            return _buildEmployeeCard(emp);
          },
        );
      },
    );
  }

  Widget _buildEmployeeCard(EmployeeRecord emp) {
    final branchDisplayName = _getBranchName(emp.branchid);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name, Status Pill & Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with Active Indicator (clickable to view full image)
              InkWell(
                onTap: emp.image.isNotEmpty ? () => _showFullImagePreview(emp.image, emp.empname) : null,
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: GlassTheme.secondaryNeon.withOpacity(0.15),
                      backgroundImage: emp.image.isNotEmpty ? NetworkImage(emp.image) : null,
                      child: emp.image.isEmpty
                          ? Text(
                              emp.empname.isNotEmpty ? emp.empname[0].toUpperCase() : "E",
                              style: const TextStyle(fontWeight: FontWeight.w800, color: GlassTheme.secondaryNeon, fontSize: 16),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: emp.active ? GlassTheme.accentEmerald : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GlassTheme.secondaryNeon.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "#${emp.empid ?? ''}",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.secondaryNeon),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (emp.bloodgroup.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: GlassTheme.accentRose.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.water_drop_rounded, size: 10, color: GlassTheme.accentRose),
                                const SizedBox(width: 2),
                                Text(
                                  emp.bloodgroup,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: GlassTheme.accentRose),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      emp.empname,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      branchDisplayName,
                      style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Action Buttons (Edit / Delete)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18, color: GlassTheme.secondaryNeon),
                    tooltip: "Edit",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _openForm(emp),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GlassTheme.accentRose),
                    tooltip: "Delete",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(emp),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // Info Rows: Date of Joining, Mobile, Email
          if (emp.dateofjoin.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: GlassTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  "Joined: ${emp.dateofjoin}",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GlassTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (emp.mobile.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.phone_android_rounded, size: 13, color: GlassTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  emp.mobile,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (emp.email.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 13, color: GlassTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    emp.email,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: GlassTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (emp.address.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: GlassTheme.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    emp.address,
                    style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ================= DATA TABLE VIEW =================
  Widget _buildDataTable() {
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
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text("Emp ID", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Employee", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Branch", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Joining Date", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Blood Group", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Mobile", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Email", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
              DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.textPrimary))),
            ],
            rows: _filteredEmployees.map((emp) {
              final branchName = _getBranchName(emp.branchid);

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GlassTheme.secondaryNeon.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "#${emp.empid ?? ''}",
                        style: const TextStyle(fontWeight: FontWeight.w800, color: GlassTheme.secondaryNeon, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      emp.empname,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GlassTheme.textPrimary),
                    ),
                  ),
                  DataCell(Text(branchName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(emp.dateofjoin.isNotEmpty ? emp.dateofjoin : '-', style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary))),
                  DataCell(
                    emp.bloodgroup.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: GlassTheme.accentRose.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              emp.bloodgroup,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.accentRose),
                            ),
                          )
                        : const Text('-', style: TextStyle(color: GlassTheme.textSecondary)),
                  ),
                  DataCell(Text(emp.mobile.isNotEmpty ? emp.mobile : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(emp.email.isNotEmpty ? emp.email : '-', style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: emp.active ? GlassTheme.accentEmerald.withOpacity(0.12) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        emp.active ? "ACTIVE" : "INACTIVE",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: emp.active ? GlassTheme.accentEmerald : GlassTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 16, color: GlassTheme.secondaryNeon),
                          tooltip: "Edit",
                          onPressed: () => _openForm(emp),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: GlassTheme.accentRose),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(emp),
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

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GlassTheme.secondaryNeon.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_outlined, color: GlassTheme.secondaryNeon, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? "No matching employees found" : "No employee records added yet",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? "Try adjusting your search terms or filter criteria."
                : "Register store staff, sales executives, and personnel with branch assignments.",
            style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.secondaryNeon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text("+ Add First Employee", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _openForm(),
          ),
        ],
      ),
    );
  }
}

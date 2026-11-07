import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/location_data.dart';
import '../models/account_head_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class AccountHeadMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AccountHeadMasterScreen({super.key, this.onBack});

  @override
  State<AccountHeadMasterScreen> createState() =>
      _AccountHeadMasterScreenState();
}

class _AccountHeadMasterScreenState extends State<AccountHeadMasterScreen> {
  final ApiService _api = ApiService();

  List<AccountHead> _accountHeads = [];
  List<AccountHead> _filteredAccountHeads = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // Predefined defaults
  static const List<String> _defaultAccountTypes = [
    'CASH',
    'SMITH',
    'DEALER',
    'BANK',
    'OTHER',
    'INTERNAL',
  ];

  static const List<String> _defaultFinancialGroups = [
    'Bank Name',
    'Sundry Debtors',
    'Sundry Creditors',
    'Duties & Taxes',
    'Capital Account',
    'Loans & Liabilities',
    'Current Assets',
    'Sales Account',
    'Purchase Account',
    'Direct Expenses',
    'Indirect Expenses',
  ];

  List<String> _accountTypeOptions = List.from(_defaultAccountTypes);
  List<String> _groupOptions = List.from(_defaultFinancialGroups);

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  AccountHead? _editingHead;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  String _selectedAccountType = 'CASH';
  String _selectedGroup = 'Bank Name';

  // Address & Contact Controllers
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  int _selectedCountryId = 1; // India default
  StateItem? _selectedState;
  final _customStateController = TextEditingController();
  final _pinController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();

  // Multiple Bank Accounts
  List<BankAccountDetail> _formBankAccounts = [];

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAccountHeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _customStateController.dispose();
    _pinController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountHeads() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _api.getAccountHeads(token),
        _api.getAccountHeadOptions(token),
      ]);

      final heads = results[0] as List<AccountHead>;
      final optionsRes = results[1] as Map<String, dynamic>;

      final Set<String> allTypes = Set.from(_defaultAccountTypes);
      final Set<String> allGroups = Set.from(_defaultFinancialGroups);

      // Add from saved options
      if (optionsRes['success'] == true && optionsRes['options'] is List) {
        for (var opt in optionsRes['options']) {
          final type = opt['option_type']?.toString().toUpperCase();
          final val = opt['option_value']?.toString().trim();
          if (val != null && val.isNotEmpty) {
            if (type == 'ACCOUNT_TYPE') {
              allTypes.add(val.toUpperCase());
            } else if (type == 'FINANCIAL_GROUP') {
              allGroups.add(val);
            }
          }
        }
      }

      // Add from actual account heads
      for (var h in heads) {
        if (h.accounttype.trim().isNotEmpty) {
          allTypes.add(h.accounttype.trim().toUpperCase());
        }
        if (h.groupname.trim().isNotEmpty) {
          allGroups.add(h.groupname.trim());
        }
      }

      if (mounted) {
        setState(() {
          _accountHeads = heads;
          _accountTypeOptions = allTypes.toList();
          _groupOptions = allGroups.toList();
          _applyFilter(_searchQuery);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading account heads or options: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredAccountHeads = List.from(_accountHeads);
    } else {
      _filteredAccountHeads = _accountHeads.where((h) {
        final matchesGeneral =
            h.accode.toLowerCase().contains(_searchQuery) ||
            h.accountname.toLowerCase().contains(_searchQuery) ||
            h.accounttype.toLowerCase().contains(_searchQuery) ||
            h.groupname.toLowerCase().contains(_searchQuery) ||
            h.addressLine1.toLowerCase().contains(_searchQuery) ||
            h.addressLine2.toLowerCase().contains(_searchQuery) ||
            h.city.toLowerCase().contains(_searchQuery) ||
            h.state.toLowerCase().contains(_searchQuery) ||
            h.country.toLowerCase().contains(_searchQuery) ||
            h.pincode.toLowerCase().contains(_searchQuery) ||
            h.phoneNo.toLowerCase().contains(_searchQuery) ||
            h.email.toLowerCase().contains(_searchQuery) ||
            h.gstno.toLowerCase().contains(_searchQuery) ||
            h.panno.toLowerCase().contains(_searchQuery);

        final matchesBank = h.bankAccounts.any(
          (b) =>
              b.bankName.toLowerCase().contains(_searchQuery) ||
              b.accountNumber.toLowerCase().contains(_searchQuery) ||
              b.ifscCode.toLowerCase().contains(_searchQuery) ||
              b.branchName.toLowerCase().contains(_searchQuery) ||
              b.accountHolderName.toLowerCase().contains(_searchQuery),
        );

        return matchesGeneral || matchesBank;
      }).toList();
    }
  }

  void _openForm([AccountHead? existing]) {
    setState(() {
      _editingHead = existing;
      _showForm = true;
      if (existing != null) {
        _nameController.text = existing.accountname;

        // Ensure existing account type is in options list
        final existingType = existing.accounttype.trim().toUpperCase();
        if (existingType.isNotEmpty &&
            !_accountTypeOptions.contains(existingType)) {
          _accountTypeOptions.add(existingType);
        }
        _selectedAccountType = existingType.isNotEmpty
            ? existingType
            : _accountTypeOptions.first;

        // Ensure existing group name is in options list
        final existingGroup = existing.groupname.trim();
        if (existingGroup.isNotEmpty &&
            !_groupOptions.contains(existingGroup)) {
          _groupOptions.add(existingGroup);
        }
        _selectedGroup = existingGroup.isNotEmpty
            ? existingGroup
            : _groupOptions.first;

        _address1Controller.text = existing.addressLine1;
        _address2Controller.text = existing.addressLine2;
        _cityController.text = existing.city;
        _phoneController.text = existing.phoneNo;
        _emailController.text = existing.email;
        _gstController.text = existing.gstno;
        _panController.text = existing.panno;
        _pinController.text = existing.pincode;
        _isActive = existing.active == 1;

        // Clone bank accounts list
        _formBankAccounts = existing.bankAccounts
            .map((b) => b.copyWith())
            .toList();

        final matchedCountry = LocationData.getCountryByNameOrCode(
          existing.country,
        );
        _selectedCountryId = matchedCountry?.id ?? 1;

        final statesForCountry = LocationData.getStatesForCountry(
          _selectedCountryId,
        );
        _selectedState = statesForCountry
            .where((s) => s.name.toLowerCase() == existing.state.toLowerCase())
            .firstOrNull;
        _customStateController.text = _selectedState == null
            ? existing.state
            : '';
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _nameController.clear();
    _selectedAccountType = _accountTypeOptions.contains('CASH')
        ? 'CASH'
        : _accountTypeOptions.first;
    _selectedGroup = _groupOptions.contains('Bank Name')
        ? 'Bank Name'
        : _groupOptions.first;
    _address1Controller.clear();
    _address2Controller.clear();
    _cityController.clear();
    _phoneController.clear();
    _emailController.clear();
    _selectedCountryId = 1;
    final indianStates = LocationData.indianStates;
    _selectedState =
        indianStates.where((s) => s.name == "Tamil Nadu").firstOrNull ??
        (indianStates.isNotEmpty ? indianStates.first : null);
    _customStateController.clear();
    _pinController.clear();
    _gstController.clear();
    _panController.clear();
    _formBankAccounts.clear();
    _isActive = true;
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingHead = null;
      _resetFormFields();
    });
  }

  // ================= PROMPT ADD NEW ACCOUNT TYPE =================
  Future<void> _promptAddNewAccountType() async {
    final customTypeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;

    final addedType = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category_rounded, color: Color(0xFFF43F5E), size: 24),
            SizedBox(width: 8),
            Text(
              "Add New Account Type",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter a new account classification (e.g. VENDOR, CUSTOMER, EXPENSE, INVESTOR):",
                style: TextStyle(
                  color: GlassTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: customTypeCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GlassTheme.textPrimary,
                ),
                decoration: _inputDecoration("e.g. VENDOR"),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Account type name is required";
                  }
                  final normalized = val.trim().toUpperCase();
                  if (_accountTypeOptions
                      .map((e) => e.toUpperCase())
                      .contains(normalized)) {
                    return "Account type '$normalized' already exists";
                  }
                  return null;
                },
              ),
            ],
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
            onPressed: () => Navigator.pop(ctx, null),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Add Type",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, customTypeCtrl.text.trim().toUpperCase());
              }
            },
          ),
        ],
      ),
    );

    if (addedType != null && addedType.isNotEmpty) {
      if (token != null) {
        _api.createAccountHeadOption(token, 'ACCOUNT_TYPE', addedType);
      }

      if (!mounted) return;

      setState(() {
        if (!_accountTypeOptions.contains(addedType)) {
          _accountTypeOptions.add(addedType);
        }
        _selectedAccountType = addedType;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Account Type '$addedType' added successfully!"),
          backgroundColor: GlassTheme.accentEmerald,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ================= PROMPT ADD NEW FINANCIAL GROUP =================
  Future<void> _promptAddNewFinancialGroup() async {
    final customGroupCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;

    final addedGroup = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.account_tree_rounded,
              color: Color(0xFFF43F5E),
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              "Add New Financial Group",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter a new financial ledger grouping (e.g. Fixed Assets, Investments, Branch Transfers):",
                style: TextStyle(
                  color: GlassTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: customGroupCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: GlassTheme.textPrimary,
                ),
                decoration: _inputDecoration("e.g. Fixed Assets"),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Financial Group name is required";
                  }
                  final normalized = val.trim();
                  if (_groupOptions
                      .map((e) => e.toLowerCase())
                      .contains(normalized.toLowerCase())) {
                    return "Financial Group '$normalized' already exists";
                  }
                  return null;
                },
              ),
            ],
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
            onPressed: () => Navigator.pop(ctx, null),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Add Group",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, customGroupCtrl.text.trim());
              }
            },
          ),
        ],
      ),
    );

    if (addedGroup != null && addedGroup.isNotEmpty) {
      if (token != null) {
        _api.createAccountHeadOption(token, 'FINANCIAL_GROUP', addedGroup);
      }

      if (!mounted) return;

      setState(() {
        if (!_groupOptions.contains(addedGroup)) {
          _groupOptions.add(addedGroup);
        }
        _selectedGroup = addedGroup;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Financial Group '$addedGroup' added successfully!"),
          backgroundColor: GlassTheme.accentEmerald,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ================= PROMPT ADD / EDIT BANK ACCOUNT MODAL =================
  Future<void> _promptAddOrEditBankAccount([
    BankAccountDetail? existing,
    int? index,
  ]) async {
    final bankNameCtrl = TextEditingController(text: existing?.bankName ?? '');
    final accNoCtrl = TextEditingController(
      text: existing?.accountNumber ?? '',
    );
    final ifscCtrl = TextEditingController(text: existing?.ifscCode ?? '');
    final branchCtrl = TextEditingController(text: existing?.branchName ?? '');
    final holderCtrl = TextEditingController(
      text: existing?.accountHolderName ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<BankAccountDetail>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GlassTheme.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: GlassTheme.accentCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              existing == null
                  ? "Add Bank Account Detail"
                  : "Edit Bank Account Detail",
              style: const TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bank Name *",
                    style: TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: bankNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GlassTheme.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      "e.g. HDFC Bank, SBI, ICICI Bank",
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? "Bank name is required"
                        : null,
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    "Account Number *",
                    style: TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: accNoCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GlassTheme.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration("e.g. 50200012345678"),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? "Account number is required"
                        : null,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "IFSC Code",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: ifscCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: GlassTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration("e.g. HDFC0001234"),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Branch Name",
                              style: TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: branchCtrl,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: GlassTheme.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: _inputDecoration(
                                "e.g. T.Nagar, Chennai",
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    "Account Holder / Name on A/C",
                    style: TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: holderCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: GlassTheme.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      "e.g. Sri Krishna Jewellers Pvt Ltd",
                    ),
                  ),
                ],
              ),
            ),
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
            onPressed: () => Navigator.pop(ctx, null),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentCyan,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(
              existing == null ? "Add Bank Account" : "Update Bank Account",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final detail = BankAccountDetail(
                  bankName: bankNameCtrl.text.trim(),
                  accountNumber: accNoCtrl.text.trim(),
                  ifscCode: ifscCtrl.text.trim().toUpperCase(),
                  branchName: branchCtrl.text.trim(),
                  accountHolderName: holderCtrl.text.trim(),
                );
                Navigator.pop(ctx, detail);
              }
            },
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null && index >= 0 && index < _formBankAccounts.length) {
          _formBankAccounts[index] = result;
        } else {
          _formBankAccounts.add(result);
        }
      });
    }
  }

  // ================= VIEW ALL BANK ACCOUNTS MODAL =================
  void _showViewBankAccountsDialog(AccountHead head) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GlassTheme.accentCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: GlassTheme.accentCyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bank Accounts (${head.accountname})",
                    style: const TextStyle(
                      color: GlassTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Code: ${head.accode} • ${head.bankAccounts.length} Account(s)",
                    style: const TextStyle(
                      color: GlassTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: head.bankAccounts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      "No bank accounts recorded for this account head.",
                      style: TextStyle(
                        color: GlassTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: head.bankAccounts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final bank = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
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
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GlassTheme.accentCyan,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "A/C #${i + 1}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      bank.bankName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: GlassTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  bank.accountNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF43F5E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 8),
                            if (bank.ifscCode.isNotEmpty)
                              _buildInfoRow("IFSC Code", bank.ifscCode),
                            if (bank.branchName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildInfoRow("Branch", bank.branchName),
                            ],
                            if (bank.accountHolderName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildInfoRow(
                                "Account Holder",
                                bank.accountHolderName,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Close",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ================= SAVE ACCOUNT HEAD FORM =================
  Future<void> _saveAccountHeadForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final countryObj = LocationData.getCountryById(_selectedCountryId);
      final countryName = countryObj?.name ?? 'India';
      final stateName = _selectedState != null
          ? _selectedState!.name
          : _customStateController.text.trim();

      final record = AccountHead(
        accode: _editingHead?.accode ?? '',
        accountname: name,
        accounttype: _selectedAccountType,
        groupname: _selectedGroup,
        bankAccounts: _formBankAccounts,
        addressLine1: _address1Controller.text.trim(),
        addressLine2: _address2Controller.text.trim(),
        city: _cityController.text.trim(),
        country: countryName,
        state: stateName,
        pincode: _pinController.text.trim(),
        phoneNo: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        gstno: _gstController.text.trim().toUpperCase(),
        panno: _panController.text.trim().toUpperCase(),
        active: _isActive ? 1 : 0,
      );

      final isEditing = _editingHead != null && _editingHead!.id != null;
      final response = isEditing
          ? await _api.updateAccountHead(token, _editingHead!.id!, record)
          : await _api.createAccountHead(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? "Account '$name' updated successfully!"
                    : "Account '$name' created successfully!",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
          _closeForm();
          await _loadAccountHeads();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message']?.toString() ??
                    "Failed to save account head",
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

        // Search & View toggles
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Body
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: CircularProgressIndicator(color: GlassTheme.primaryNeon),
            ),
          )
        else if (_filteredAccountHeads.isEmpty)
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
                  tooltip: "Back to Master Hub",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
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
                        "Account Head Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(
                        label: "Ledgers",
                        color: GlassTheme.accentRose,
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Configure accounts, multiple bank accounts, address & statutory parameters",
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
                tooltip: "Reload Accounts",
                onPressed: _loadAccountHeads,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm
                      ? const Color(0xFF334155)
                      : const Color(0xFFF43F5E),
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
                  _showForm ? "Close Form" : "Add Account Head",
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
    final isEditing = _editingHead != null;
    final statesForCountry = LocationData.getStatesForCountry(
      _selectedCountryId,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
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
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing
                        ? Icons.edit_note_rounded
                        : Icons.add_circle_outline_rounded,
                    color: const Color(0xFFF43F5E),
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
                            ? "Edit Account Head (${_editingHead!.accode} - ${_editingHead!.accountname})"
                            : "Create New Account Head / Ledger",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Configure general ledger, account types, financial groups, bank accounts & address details",
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

            // Section 1: Basic Classification
            const Text(
              "Account Classification & Type",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // Account Name
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Account Head Name *",
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
                          "e.g. HDFC Bank, Sundry Debtors - Walkin",
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return "Account name is required";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // Account Type Selector with + Add Type Action
                SizedBox(
                  width: isMobile ? double.infinity : 270,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Account Type *",
                            style: TextStyle(
                              color: GlassTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          InkWell(
                            onTap: _promptAddNewAccountType,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 14,
                                    color: Color(0xFFF43F5E),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "+ Add Type",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFF43F5E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _accountTypeOptions.contains(_selectedAccountType)
                            ? _selectedAccountType
                            : (_accountTypeOptions.isNotEmpty
                                  ? _accountTypeOptions.first
                                  : 'CASH'),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Select Account Type"),
                        items: _accountTypeOptions.map((type) {
                          final badgeColor = _getAccountTypeColor(type);
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  type,
                                  style: const TextStyle(
                                    color: GlassTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedAccountType = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Financial Group Selector with + Add Group Action
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Financial Group *",
                            style: TextStyle(
                              color: GlassTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          InkWell(
                            onTap: _promptAddNewFinancialGroup,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 14,
                                    color: Color(0xFFF43F5E),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "+ Add Group",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFF43F5E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _groupOptions.contains(_selectedGroup)
                            ? _selectedGroup
                            : (_groupOptions.isNotEmpty
                                  ? _groupOptions.first
                                  : 'Bank Name'),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("Select Group"),
                        items: _groupOptions.map((grp) {
                          return DropdownMenuItem(
                            value: grp,
                            child: Text(
                              grp,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGroup = val);
                        },
                      ),
                    ],
                  ),
                ),

                // Status Switch
                SizedBox(
                  width: isMobile ? double.infinity : 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Status",
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
              ],
            ),
            const SizedBox(height: 22),

            // Section 2: Multiple Bank Accounts Details
            _buildBankAccountsSection(isMobile),
            const SizedBox(height: 22),

            // Section 3: Address & Contact Details
            const Text(
              "Address & Contact Details",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                // Address Line 1
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Address Line 1 / Street / Door No",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _address1Controller,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. No. 45, Car Street"),
                      ),
                    ],
                  ),
                ),

                // Address Line 2
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Address Line 2 / Area / Landmark",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _address2Controller,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. Near Big Bazaar"),
                      ),
                    ],
                  ),
                ),

                // City
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "City / Town",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
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

                // Country
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Country",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
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
                              _selectedState = newStates.isNotEmpty
                                  ? newStates.first
                                  : null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // State
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "State",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      statesForCountry.isNotEmpty
                          ? DropdownButtonFormField<StateItem>(
                              initialValue:
                                  _selectedState != null &&
                                      statesForCountry.contains(_selectedState)
                                  ? _selectedState
                                  : (statesForCountry.isNotEmpty
                                        ? statesForCountry.first
                                        : null),
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: _inputDecoration("State"),
                              items: statesForCountry.map((s) {
                                return DropdownMenuItem(
                                  value: s,
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
                                  setState(() => _selectedState = val),
                            )
                          : TextFormField(
                              controller: _customStateController,
                              style: const TextStyle(
                                color: GlassTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: _inputDecoration("Enter State"),
                            ),
                    ],
                  ),
                ),

                // PIN
                SizedBox(
                  width: isMobile ? double.infinity : 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "PIN Code",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. 600001"),
                      ),
                    ],
                  ),
                ),

                // Phone / Mobile
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Phone / Mobile No",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
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

                // Email
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Email Address",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
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
                        decoration: _inputDecoration("e.g. finance@ledger.com"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Section 4: Statutory GSTIN & PAN
            const Text(
              "Statutory Numbers",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "GSTIN (15 Chars)",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
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
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "PAN Number",
                        style: TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _panController,
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. ABCDE1234F"),
                        maxLength: 10,
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
            const SizedBox(height: 26),

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
                  label: isEditing ? "Update Account" : "Save Account",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
                  ),
                  isLoading: _isSaving,
                  onPressed: _saveAccountHeadForm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= MULTIPLE BANK ACCOUNTS SECTION COMPONENT =================
  Widget _buildBankAccountsSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: GlassTheme.accentCyan,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Bank Account Details",
                    style: TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _formBankAccounts.isEmpty
                          ? const Color(0xFFE2E8F0)
                          : GlassTheme.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${_formBankAccounts.length} Added",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _formBankAccounts.isEmpty
                            ? GlassTheme.textSecondary
                            : GlassTheme.accentCyan,
                      ),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentCyan,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  "+ Add Bank Account",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () => _promptAddOrEditBankAccount(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_formBankAccounts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: GlassTheme.textMuted,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "No bank accounts attached. Click '+ Add Bank Account' to configure multiple banking accounts.",
                    style: TextStyle(
                      color: GlassTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: _formBankAccounts.asMap().entries.map((entry) {
                final idx = entry.key;
                final bank = entry.value;

                return Container(
                  width: isMobile ? double.infinity : 320,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: GlassTheme.accentCyan.withValues(alpha: 0.3),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_rounded,
                                size: 16,
                                color: GlassTheme.accentCyan,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                bank.bankName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: GlassTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: GlassTheme.primaryNeon,
                                ),
                                tooltip: "Edit Bank Account",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    _promptAddOrEditBankAccount(bank, idx),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: GlassTheme.accentRose,
                                ),
                                tooltip: "Remove Bank Account",
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(
                                    () => _formBankAccounts.removeAt(idx),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "A/C: ${bank.accountNumber}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFFF43F5E),
                        ),
                      ),
                      if (bank.ifscCode.isNotEmpty ||
                          bank.branchName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (bank.ifscCode.isNotEmpty)
                              "IFSC: ${bank.ifscCode}",
                            if (bank.branchName.isNotEmpty)
                              "Branch: ${bank.branchName}",
                          ].join(" • "),
                          style: const TextStyle(
                            fontSize: 11,
                            color: GlassTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
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
        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 2.0),
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
                    "Search accounts by code, name, bank account, IFSC, city, GSTIN...",
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
                    color: Color(0xFFF43F5E),
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
                Icons.account_balance_wallet_rounded,
                size: 48,
                color: GlassTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching accounts found"
                  : "No Account Heads created yet",
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
                  : "Get started by adding accounts (e.g. Cash Account, Smith Account, Dealer, Bank Account, Sales).",
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
                  backgroundColor: const Color(0xFFF43F5E),
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
                  "Create Account Head",
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

  // ================= COLOR HELPER FOR ACCOUNT TYPES =================
  Color _getAccountTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'CASH':
        return GlassTheme.accentAmber;
      case 'SMITH':
        return const Color(0xFF7C3AED); // Purple
      case 'DEALER':
        return GlassTheme.accentEmerald;
      case 'BANK':
        return GlassTheme.accentCyan;
      case 'INTERNAL':
        return GlassTheme.primaryNeon;
      case 'OTHER':
      default:
        return const Color(0xFF64748B); // Slate
    }
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
          children: _filteredAccountHeads.map((head) {
            final typeColor = _getAccountTypeColor(head.accounttype);

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
                            head.accountname,
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
                          label: head.active == 1 ? "ACTIVE" : "INACTIVE",
                          color: head.active == 1
                              ? GlassTheme.accentEmerald
                              : GlassTheme.accentRose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Type Badge & Group Tag
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                head.accounttype,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              head.groupname,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: GlassTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow("Account Code", head.accode),
                    const SizedBox(height: 6),
                    _buildInfoRow("Type", head.accounttype),
                    const SizedBox(height: 6),
                    _buildInfoRow("Group", head.groupname),

                    // Bank Accounts Chip / Modal Trigger
                    if (head.bankAccounts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showViewBankAccountsDialog(head),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: GlassTheme.accentCyan.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: GlassTheme.accentCyan.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_rounded,
                                size: 15,
                                color: GlassTheme.accentCyan,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  head.bankAccounts.length == 1
                                      ? "${head.bankAccounts.first.bankName} (${head.bankAccounts.first.accountNumber})"
                                      : "${head.bankAccounts.length} Bank Accounts Attached",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: GlassTheme.accentCyan,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: GlassTheme.accentCyan,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Address / City / Location
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "Location",
                      [
                        if (head.city.isNotEmpty) head.city,
                        head.state,
                        head.country,
                      ].where((s) => s.isNotEmpty).join(", "),
                    ),

                    if (head.phoneNo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow("Phone", head.phoneNo),
                    ],
                    if (head.gstno.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow("GSTIN", head.gstno),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (head.bankAccounts.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.account_balance_outlined,
                              color: GlassTheme.accentCyan,
                              size: 20,
                            ),
                            tooltip: "View Bank Accounts",
                            onPressed: () => _showViewBankAccountsDialog(head),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: GlassTheme.primaryNeon,
                            size: 20,
                          ),
                          tooltip: "Edit Account",
                          onPressed: () => _openForm(head),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 20,
                          ),
                          tooltip: "Delete Account",
                          onPressed: () => _confirmDelete(head),
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
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: GlassTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.end,
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
                  "ACCOUNT NAME",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "ACCOUNT TYPE",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "FINANCIAL GROUP",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "BANK ACCOUNTS",
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "CITY / STATE",
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
            rows: _filteredAccountHeads.map((head) {
              final typeColor = _getAccountTypeColor(head.accounttype);

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      head.accode,
                      style: const TextStyle(
                        color: Color(0xFFF43F5E),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      head.accountname,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w600,
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
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        head.accounttype,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      head.groupname,
                      style: const TextStyle(
                        color: GlassTheme.primaryNeon,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  DataCell(
                    head.bankAccounts.isEmpty
                        ? const Text(
                            "-",
                            style: TextStyle(color: GlassTheme.textMuted),
                          )
                        : InkWell(
                            onTap: () => _showViewBankAccountsDialog(head),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.account_balance_rounded,
                                  size: 14,
                                  color: GlassTheme.accentCyan,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  head.bankAccounts.length == 1
                                      ? head.bankAccounts.first.bankName
                                      : "${head.bankAccounts.length} Banks",
                                  style: const TextStyle(
                                    color: GlassTheme.accentCyan,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  DataCell(
                    Text(
                      [
                        if (head.city.isNotEmpty) head.city,
                        head.state,
                      ].where((s) => s.isNotEmpty).join(", "),
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      head.gstno.isEmpty ? "-" : head.gstno,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    StatusBadge(
                      label: head.active == 1 ? "Active" : "Inactive",
                      color: head.active == 1
                          ? GlassTheme.accentEmerald
                          : GlassTheme.accentRose,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (head.bankAccounts.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.account_balance_outlined,
                              color: GlassTheme.accentCyan,
                              size: 18,
                            ),
                            tooltip: "View Bank Accounts",
                            onPressed: () => _showViewBankAccountsDialog(head),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: GlassTheme.primaryNeon,
                            size: 18,
                          ),
                          tooltip: "Edit",
                          onPressed: () => _openForm(head),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: GlassTheme.accentRose,
                            size: 18,
                          ),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(head),
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
  void _confirmDelete(AccountHead head) {
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
              "Delete Account Head",
              style: TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete account head '${head.accode} - ${head.accountname}'?",
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
              if (head.id == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteAccountHead(token, head.id!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? "Account head deleted",
                    ),
                    backgroundColor: isOk
                        ? GlassTheme.accentEmerald
                        : GlassTheme.accentRose,
                  ),
                );
                if (isOk) _loadAccountHeads();
              }
            },
          ),
        ],
      ),
    );
  }
}

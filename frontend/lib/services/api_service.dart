import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/tenant_model.dart';
import '../models/company_model.dart';
import '../models/branch_model.dart';
import '../models/user_model.dart';
import '../models/account_head_model.dart';
import '../models/tax_model.dart';
import '../models/inventory_models.dart';
import '../models/system_control_model.dart';
import '../models/estimate_model.dart';
import '../models/employee_model.dart';
import '../models/rate_model.dart';

class ApiService {
  // Automatically detects production Web origin (e.g. https://progold.vercel.app/api)
  // or falls back to http://localhost:5000/api for local testing / desktop.
  static String get defaultBaseUrl {
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty &&
            !origin.startsWith('http://localhost') &&
            !origin.startsWith('http://127.0.0.1')) {
          return '$origin/api';
        }
      } catch (_) {}
    }
    return "http://localhost:5000/api";
  }

  String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  Map<String, dynamic> _decodeAuthResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      // Hosting failures can return plain text or HTML instead of API JSON.
    }
    final timedOut = response.statusCode == 504 ||
        response.body.contains('FUNCTION_INVOCATION_TIMEOUT');
    return {
      'success': false,
      'message': timedOut
          ? 'The server timed out. Please wait a moment and try again.'
          : 'The server returned an unexpected response (HTTP ${response.statusCode}). '
              'Please try again. If this continues, check the deployment logs.',
    };
  }

  Map<String, String> _headers([String? token]) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Sends 6-digit OTP to user's email
  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim()}),
      );
      final data = _decodeAuthResponse(res);
      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Failed to reach backend server ($e)',
      };
    }
  }

  /// Verifies OTP code entered by user
  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
      );
      final data = _decodeAuthResponse(res);
      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Failed to verify OTP ($e)',
      };
    }
  }

  /// Registers a new multi-tenant account
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String contactNumber,
    required String validFrom,
    required String validTo,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers(),
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'contact_number': contactNumber.trim(),
          'valid_from': validFrom,
          'valid_to': validTo,
        }),
      );
      return _decodeAuthResponse(res);
    } catch (e) {
      return {'success': false, 'message': 'Registration error: $e'};
    }
  }

  /// Logs in tenant with email & password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      return _decodeAuthResponse(res);
    } catch (e) {
      return {'success': false, 'message': 'Login error: $e'};
    }
  }

  /// Verifies if an email exists globally
  Future<Map<String, dynamic>> verifyEmail(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/verify-email'),
        headers: _headers(),
        body: jsonEncode({'email': email.trim()}),
      );
      return _decodeAuthResponse(res);
    } catch (e) {
      return {'success': false, 'message': 'Verification error: $e'};
    }
  }

  /// Fetches authenticated tenant profile, role, & user details
  Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/profile'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Updates business profile (name, logo, contact)
  Future<Map<String, dynamic>> updateProfile(
    String token, {
    String? businessName,
    String? businessLogo,
    String? contactNumber,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/profile'),
        headers: _headers(token),
        body: jsonEncode({
          'business_name': ?businessName,
          'business_logo': ?businessLogo,
          'contact_number': ?contactNumber,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update profile: $e'};
    }
  }

  /// Fetches tables and schema metrics from the tenant's PostgreSQL schema
  Future<List<TableOverview>> getTenantDbOverview(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/db/overview'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['tables'] is List) {
          return (data['tables'] as List)
              .map((t) => TableOverview.fromJson(t))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches comprehensive Database Status (fast metrics by default, optional tables breakdown)
  Future<Map<String, dynamic>> getTenantDbStatus(
    String token, {
    bool includeTables = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/tenant/db/status').replace(
        queryParameters: includeTables ? {'include_tables': 'true'} : null,
      );
      final res = await http.get(uri, headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch database status: $e',
      };
    }
  }

  /// Fetches detailed table breakdown, column structures, and row counts
  Future<Map<String, dynamic>> getTenantDbTables(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/db/tables'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch database tables: $e',
        'tables': [],
      };
    }
  }

  /// Optimizes database storage and updates query statistics
  Future<Map<String, dynamic>> optimizeTenantDb(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/db/optimize'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Optimization error: $e'};
    }
  }

  /// Tests latency and status of the tenant's PostgreSQL schema
  Future<DatabaseTestResult> testTenantDbHealth(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/db/health'),
        headers: _headers(token),
      );
      final data = jsonDecode(res.body);
      return DatabaseTestResult.fromJson(data);
    } catch (e) {
      return DatabaseTestResult(success: false, message: '$e');
    }
  }

  /// Executes a dynamic SQL query in the tenant's PostgreSQL schema
  Future<QueryResult> executeTenantQuery(String token, String sql) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/db/query'),
        headers: _headers(token),
        body: jsonEncode({'sql': sql}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return QueryResult.fromJson(data);
        }
      }
      try {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return QueryResult.fromJson(data);
        }
      } catch (_) {}
      return QueryResult(
        success: false,
        message:
            'Server error (${res.statusCode}): ${res.body.isNotEmpty ? (res.body.length > 120 ? "${res.body.substring(0, 120)}..." : res.body) : "Query execution failed."}',
      );
    } catch (e) {
      return QueryResult(success: false, message: 'Query execution error: $e');
    }
  }

  /// Reinstalls & Synchronizes the latest ProGold ERP schema into tenant's database
  Future<Map<String, dynamic>> reinstallTenantDatabase(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/db/reinstall'),
        headers: _headers(token),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        try {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            return data;
          }
        } catch (_) {}
        return {
          'success': true,
          'message': 'Database schema synchronized successfully.',
        };
      } else {
        try {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            return data;
          }
        } catch (_) {}
        final errText = res.body.trim();
        return {
          'success': false,
          'message':
              'Server error (${res.statusCode}): ${errText.isNotEmpty ? (errText.length > 150 ? "${errText.substring(0, 150)}..." : errText) : "Failed to reinstall schema."}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to reinstall database schema: $e',
      };
    }
  }

  // ================= COMPANY MASTER CRUD =================

  /// Fetches all company records for tenant
  Future<List<Company>> getCompanies(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/companies'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['companies'] is List) {
          return (data['companies'] as List)
              .map((item) => Company.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching companies: $e");
      return [];
    }
  }

  /// Creates a new company record
  Future<Map<String, dynamic>> createCompany(
    String token,
    Company company,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/companies'),
        headers: _headers(token),
        body: jsonEncode(company.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create company: $e'};
    }
  }

  /// Updates an existing company record
  Future<Map<String, dynamic>> updateCompany(
    String token,
    String companyId,
    Company company,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/companies/$companyId'),
        headers: _headers(token),
        body: jsonEncode(company.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update company: $e'};
    }
  }

  /// Deletes a company record
  Future<Map<String, dynamic>> deleteCompany(
    String token,
    String companyId,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/companies/$companyId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete company: $e'};
    }
  }

  // ================= BRANCH MASTER API METHODS =================

  /// Fetches branch records for the tenant, optionally filtered by companyId
  Future<List<Branch>> getBranches(String token, {String? companyId}) async {
    try {
      String url = '$baseUrl/tenant/branches';
      if (companyId != null && companyId.trim().isNotEmpty) {
        url += '?companyid=${Uri.encodeComponent(companyId.trim())}';
      }
      final res = await http.get(Uri.parse(url), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['branches'] != null) {
          return (data['branches'] as List)
              .map((item) => Branch.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("getBranches error: $e");
      return [];
    }
  }

  /// Creates a new branch record
  Future<Map<String, dynamic>> createBranch(String token, Branch branch) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/branches'),
        headers: _headers(token),
        body: jsonEncode(branch.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create branch: $e'};
    }
  }

  /// Updates an existing branch record
  Future<Map<String, dynamic>> updateBranch(
    String token,
    String branchId,
    Branch branch,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/branches/$branchId'),
        headers: _headers(token),
        body: jsonEncode(branch.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update branch: $e'};
    }
  }

  /// Deletes a branch record
  Future<Map<String, dynamic>> deleteBranch(
    String token,
    String branchId,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/branches/$branchId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete branch: $e'};
    }
  }

  // ================= USER MASTER API METHODS =================

  /// Fetches all user accounts for tenant
  Future<List<AppUser>> getUsers(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/users'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['users'] is List) {
          return (data['users'] as List)
              .map((item) => AppUser.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("getUsers error: $e");
      return [];
    }
  }

  /// Creates a new user record with password & menu permissions
  Future<Map<String, dynamic>> createUser(
    String token,
    AppUser user,
    String password,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/users'),
        headers: _headers(token),
        body: jsonEncode(user.toJson(password: password)),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create user: $e'};
    }
  }

  /// Updates an existing user record & menu permissions
  Future<Map<String, dynamic>> updateUser(
    String token,
    String userId,
    AppUser user,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/users/$userId'),
        headers: _headers(token),
        body: jsonEncode(user.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update user: $e'};
    }
  }

  /// Changes a user's password
  Future<Map<String, dynamic>> changeUserPassword(
    String token,
    String userId,
    String newPassword,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/users/$userId/change-password'),
        headers: _headers(token),
        body: jsonEncode({'new_password': newPassword}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to change password: $e'};
    }
  }

  /// Deletes a user record
  Future<Map<String, dynamic>> deleteUser(String token, String userId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/users/$userId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete user: $e'};
    }
  }

  /// Initiates password recovery via Email OTP
  Future<Map<String, dynamic>> recoverUserPassword(String emailOrUserId) async {
    try {
      final isEmail = emailOrUserId.contains('@');
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/users/recover-password'),
        headers: _headers(),
        body: jsonEncode({
          if (isEmail)
            'email': emailOrUserId.trim()
          else
            'userid': emailOrUserId.trim(),
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to initiate password recovery: $e',
      };
    }
  }

  // ================= ACCOUNT HEAD CRUD =================

  /// Fetches all account head records for tenant
  Future<List<AccountHead>> getAccountHeads(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/account-heads'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['accountHeads'] is List) {
          return (data['accountHeads'] as List)
              .map((item) => AccountHead.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching account heads: $e");
      return [];
    }
  }

  /// Creates a new account head record
  Future<Map<String, dynamic>> createAccountHead(
    String token,
    AccountHead head,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/account-heads'),
        headers: _headers(token),
        body: jsonEncode(head.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create account head: $e'};
    }
  }

  /// Updates an existing account head record
  Future<Map<String, dynamic>> updateAccountHead(
    String token,
    int id,
    AccountHead head,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/account-heads/$id'),
        headers: _headers(token),
        body: jsonEncode(head.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update account head: $e'};
    }
  }

  /// Deletes an account head record
  Future<Map<String, dynamic>> deleteAccountHead(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/account-heads/$id'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete account head: $e'};
    }
  }

  /// Fetches custom account head options (types & groups)
  Future<Map<String, dynamic>> getAccountHeadOptions(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/account-heads/options'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'success': false, 'options': []};
    } catch (e) {
      debugPrint("Error fetching account head options: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Creates a custom account head option (ACCOUNT_TYPE or FINANCIAL_GROUP)
  Future<Map<String, dynamic>> createAccountHeadOption(
    String token,
    String optionType,
    String optionValue,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/account-heads/options'),
        headers: _headers(token),
        body: jsonEncode({
          'option_type': optionType,
          'option_value': optionValue,
        }),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to save option: $e'};
    }
  }

  // ================= TAX MASTER CRUD =================

  /// Fetches all tax master records for tenant
  Future<List<TaxRecord>> getTaxRecords(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/tax-master'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['taxRecords'] is List) {
          return (data['taxRecords'] as List)
              .map((item) => TaxRecord.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching tax records: $e");
      return [];
    }
  }

  /// Creates a new tax master record
  Future<Map<String, dynamic>> createTaxRecord(
    String token,
    TaxRecord tax,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/tax-master'),
        headers: _headers(token),
        body: jsonEncode(tax.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to create tax master record: $e',
      };
    }
  }

  /// Updates an existing tax master record
  Future<Map<String, dynamic>> updateTaxRecord(
    String token,
    int id,
    TaxRecord tax,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/tax-master/$id'),
        headers: _headers(token),
        body: jsonEncode(tax.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update tax master record: $e',
      };
    }
  }

  /// Deletes a tax master record
  Future<Map<String, dynamic>> deleteTaxRecord(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/tax-master/$id'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete tax master record: $e',
      };
    }
  }

  // ================= METALS CRUD =================

  Future<List<Metal>> getMetals(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/metals'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['metals'] is List) {
          return (data['metals'] as List)
              .map((i) => Metal.fromJson(i))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getMetals: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createMetal(String token, Metal metal) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/metals'),
        headers: _headers(token),
        body: jsonEncode(metal.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateMetal(
    String token,
    String metalid,
    Metal metal,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/metals/$metalid'),
        headers: _headers(token),
        body: jsonEncode(metal.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMetal(String token, String metalid) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/metals/$metalid'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= PURITIES CRUD =================

  Future<List<Purity>> getPurities(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/purities'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['purities'] is List) {
          return (data['purities'] as List)
              .map((i) => Purity.fromJson(i))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getPurities: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createPurity(String token, Purity purity) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/purities'),
        headers: _headers(token),
        body: jsonEncode(purity.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePurity(
    String token,
    int purityid,
    Purity purity,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/purities/$purityid'),
        headers: _headers(token),
        body: jsonEncode(purity.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePurity(String token, int purityid) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/purities/$purityid'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= CATEGORIES CRUD =================

  Future<List<CategoryRecord>> getCategories(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/categories'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['categories'] is List) {
          return (data['categories'] as List)
              .map((i) => CategoryRecord.fromJson(i))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getCategories: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createCategory(
    String token,
    CategoryRecord category,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/categories'),
        headers: _headers(token),
        body: jsonEncode(category.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateCategory(
    String token,
    int id,
    CategoryRecord category,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/categories/$id'),
        headers: _headers(token),
        body: jsonEncode(category.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteCategory(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/categories/$id'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= PRODUCTS CRUD (4th Inventory Master) =================

  /// Fetches products along with last_productid and next_productid metadata
  Future<Map<String, dynamic>> getProductsData(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/products'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['products'] is List) {
          final items = (data['products'] as List)
              .map((i) => ProductRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'products': items,
            'last_productid': data['last_productid'] ?? 0,
            'next_productid': data['next_productid'] ?? 1,
            'total_count': data['total_count'] ?? 0,
          };
        }
      }
      return {
        'success': false,
        'products': <ProductRecord>[],
        'last_productid': 0,
        'next_productid': 1,
      };
    } catch (e) {
      debugPrint("Error getProductsData: $e");
      return {
        'success': false,
        'products': <ProductRecord>[],
        'last_productid': 0,
        'next_productid': 1,
      };
    }
  }

  Future<List<ProductRecord>> getProducts(String token) async {
    final data = await getProductsData(token);
    return data['products'] as List<ProductRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createProduct(
    String token,
    ProductRecord product,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/products'),
        headers: _headers(token),
        body: jsonEncode(product.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProduct(
    String token,
    int productid,
    ProductRecord product,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/products/$productid'),
        headers: _headers(token),
        body: jsonEncode(product.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteProduct(
    String token,
    int productid,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/products/$productid'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= SUB-PRODUCTS CRUD (5th Inventory Master) =================

  /// Fetches subproducts along with last_subproductid and next_subproductid metadata
  Future<Map<String, dynamic>> getSubProductsData(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/subproducts'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['subproducts'] is List) {
          final items = (data['subproducts'] as List)
              .map((i) => SubProductRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'subproducts': items,
            'last_subproductid': data['last_subproductid'] ?? 0,
            'next_subproductid': data['next_subproductid'] ?? 1,
            'total_count': data['total_count'] ?? 0,
          };
        }
      }
      return {
        'success': false,
        'subproducts': <SubProductRecord>[],
        'last_subproductid': 0,
        'next_subproductid': 1,
      };
    } catch (e) {
      debugPrint("Error getSubProductsData: $e");
      return {
        'success': false,
        'subproducts': <SubProductRecord>[],
        'last_subproductid': 0,
        'next_subproductid': 1,
      };
    }
  }

  Future<List<SubProductRecord>> getSubProducts(String token) async {
    final data = await getSubProductsData(token);
    return data['subproducts'] as List<SubProductRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createSubProduct(
    String token,
    SubProductRecord subProduct,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/subproducts'),
        headers: _headers(token),
        body: jsonEncode(subProduct.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSubProduct(
    String token,
    int subproductid,
    SubProductRecord subProduct,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/subproducts/$subproductid'),
        headers: _headers(token),
        body: jsonEncode(subProduct.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteSubProduct(
    String token,
    int subproductid,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/subproducts/$subproductid'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= STYLES CRUD (6th Master under Inventory) =================

  /// Fetches styles along with last_styleid and next_styleid metadata
  Future<Map<String, dynamic>> getStylesData(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/styles'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['styles'] is List) {
          final items = (data['styles'] as List)
              .map((i) => StyleRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'styles': items,
            'last_styleid': data['last_styleid'] ?? 0,
            'next_styleid': data['next_styleid'] ?? 1,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {
        'success': false,
        'styles': <StyleRecord>[],
        'last_styleid': 0,
        'next_styleid': 1,
      };
    } catch (e) {
      debugPrint("Error getStylesData: $e");
      return {
        'success': false,
        'styles': <StyleRecord>[],
        'last_styleid': 0,
        'next_styleid': 1,
      };
    }
  }

  Future<List<StyleRecord>> getStyles(String token) async {
    final data = await getStylesData(token);
    return data['styles'] as List<StyleRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createStyle(
    String token,
    StyleRecord style,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/styles'),
        headers: _headers(token),
        body: jsonEncode(style.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateStyle(
    String token,
    int styleid,
    StyleRecord style,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/styles/$styleid'),
        headers: _headers(token),
        body: jsonEncode(style.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteStyle(String token, int styleid) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/styles/$styleid'),
        headers: _headers(token),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= SIZES CRUD (7th Master under Inventory) =================

  /// Fetches sizes along with last_sizeid and next_sizeid metadata
  Future<Map<String, dynamic>> getSizesData(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/sizes'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['sizes'] is List) {
          final items = (data['sizes'] as List)
              .map((i) => SizeRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'sizes': items,
            'last_sizeid': data['last_sizeid'] ?? 0,
            'next_sizeid': data['next_sizeid'] ?? 1,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {
        'success': false,
        'sizes': <SizeRecord>[],
        'last_sizeid': 0,
        'next_sizeid': 1,
      };
    } catch (e) {
      debugPrint("Error getSizesData: $e");
      return {
        'success': false,
        'sizes': <SizeRecord>[],
        'last_sizeid': 0,
        'next_sizeid': 1,
      };
    }
  }

  Future<List<SizeRecord>> getSizes(String token) async {
    final data = await getSizesData(token);
    return data['sizes'] as List<SizeRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createSize(String token, SizeRecord size) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/sizes'),
        headers: _headers(token),
        body: jsonEncode(size.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSize(
    String token,
    int sizeid,
    SizeRecord size,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/sizes/$sizeid'),
        headers: _headers(token),
        body: jsonEncode(size.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteSize(String token, int sizeid) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/sizes/$sizeid'),
        headers: _headers(token),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= PRICE SETTING CRUD (8th Master under Inventory) =================

  /// Fetches price settings, optionally filtered by companyId
  Future<Map<String, dynamic>> getPriceSettingsData(
    String token, {
    String? companyId,
  }) async {
    try {
      String url = '$baseUrl/tenant/price-settings';
      if (companyId != null && companyId.trim().isNotEmpty) {
        url += '?companyid=${Uri.encodeComponent(companyId.trim())}';
      }
      final res = await http.get(Uri.parse(url), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['price_settings'] is List) {
          final items = (data['price_settings'] as List)
              .map((i) => PriceSettingRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'price_settings': items,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {
        'success': false,
        'price_settings': <PriceSettingRecord>[],
        'total_count': 0,
      };
    } catch (e) {
      debugPrint("Error getPriceSettingsData: $e");
      return {
        'success': false,
        'price_settings': <PriceSettingRecord>[],
        'total_count': 0,
      };
    }
  }

  Future<List<PriceSettingRecord>> getPriceSettings(
    String token, {
    String? companyId,
  }) async {
    final data = await getPriceSettingsData(token, companyId: companyId);
    return data['price_settings'] as List<PriceSettingRecord>? ?? [];
  }

  /// Fetches active dealers & smiths for Price Setting dropdown
  Future<List<Map<String, dynamic>>> getPriceSettingDealers(
    String token,
  ) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/price-settings/dealers'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['dealers'] is List) {
          return List<Map<String, dynamic>>.from(data['dealers']);
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getPriceSettingDealers: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createPriceSetting(
    String token,
    PriceSettingRecord record,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/price-settings'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePriceSetting(
    String token,
    int id,
    PriceSettingRecord record,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/price-settings/$id'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deletePriceSetting(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/price-settings/$id'),
        headers: _headers(token),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= DIAMOND PRICE SETTING CRUD (Master under Inventory) =================

  /// Fetches diamond price settings, optionally filtered by companyId
  Future<Map<String, dynamic>> getDiamondPriceSettingsData(
    String token, {
    String? companyId,
  }) async {
    try {
      String url = '$baseUrl/tenant/diamond-price-settings';
      if (companyId != null && companyId.trim().isNotEmpty) {
        url += '?companyid=${Uri.encodeComponent(companyId.trim())}';
      }
      final res = await http.get(Uri.parse(url), headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['diamond_price_settings'] is List) {
          final items = (data['diamond_price_settings'] as List)
              .map((i) => DiamondPriceSettingRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'diamond_price_settings': items,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {
        'success': false,
        'diamond_price_settings': <DiamondPriceSettingRecord>[],
        'total_count': 0,
      };
    } catch (e) {
      debugPrint("Error getDiamondPriceSettingsData: $e");
      return {
        'success': false,
        'diamond_price_settings': <DiamondPriceSettingRecord>[],
        'total_count': 0,
      };
    }
  }

  Future<List<DiamondPriceSettingRecord>> getDiamondPriceSettings(
    String token, {
    String? companyId,
  }) async {
    final data = await getDiamondPriceSettingsData(token, companyId: companyId);
    return data['diamond_price_settings'] as List<DiamondPriceSettingRecord>? ??
        [];
  }

  /// Fetches products where diastone IN ('D', 'S')
  Future<List<ProductRecord>> getDiamondProducts(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/diamond-price-settings/products'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['products'] is List) {
          return (data['products'] as List)
              .map((i) => ProductRecord.fromJson(i))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getDiamondProducts: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createDiamondPriceSetting(
    String token,
    DiamondPriceSettingRecord record,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/diamond-price-settings'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateDiamondPriceSetting(
    String token,
    int id,
    DiamondPriceSettingRecord record,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/diamond-price-settings/$id'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteDiamondPriceSetting(
    String token,
    int id,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/diamond-price-settings/$id'),
        headers: _headers(token),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= DESIGNER MASTER CRUD (Master under Inventory) =================

  /// Fetches designers list along with metadata
  Future<Map<String, dynamic>> getDesignersData(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/designers'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['designers'] is List) {
          final items = (data['designers'] as List)
              .map((i) => DesignerRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'designers': items,
            'last_designerid': data['last_designerid'] ?? 0,
            'next_designerid': data['next_designerid'] ?? 1,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {
        'success': false,
        'designers': <DesignerRecord>[],
        'total_count': 0,
      };
    } catch (e) {
      debugPrint("Error getDesignersData: $e");
      return {
        'success': false,
        'designers': <DesignerRecord>[],
        'total_count': 0,
      };
    }
  }

  Future<List<DesignerRecord>> getDesigners(String token) async {
    final data = await getDesignersData(token);
    return data['designers'] as List<DesignerRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createDesigner(
    String token,
    DesignerRecord record,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/designers'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateDesigner(
    String token,
    int id,
    DesignerRecord record,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/designers/$id'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteDesigner(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/designers/$id'),
        headers: _headers(token),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= PREPARE FOR SKU (Stock Management) =================

  /// Fetches Prepare SKU Lots with metadata and filtering
  Future<Map<String, dynamic>> getPrepareSkuLotsData(
    String token, {
    String? companyId,
    String? branchId,
    int? designerId,
    int? productId,
    int? purityId,
    String? fromDate,
    String? toDate,
    String? isActive,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (companyId != null && companyId.trim().isNotEmpty) {
        queryParams['companyid'] = companyId.trim();
      }
      if (branchId != null && branchId.trim().isNotEmpty && branchId != 'ALL') {
        queryParams['branchid'] = branchId.trim();
      }
      if (designerId != null && designerId > 0) {
        queryParams['designerid'] = designerId.toString();
      }
      if (productId != null && productId > 0) {
        queryParams['productid'] = productId.toString();
      }
      if (purityId != null && purityId > 0) {
        queryParams['purityid'] = purityId.toString();
      }
      if (fromDate != null && fromDate.trim().isNotEmpty) {
        queryParams['from_date'] = fromDate.trim();
      }
      if (toDate != null && toDate.trim().isNotEmpty) {
        queryParams['to_date'] = toDate.trim();
      }
      if (isActive != null && isActive.trim().isNotEmpty) {
        queryParams['is_active'] = isActive.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }

      final uri = Uri.parse(
        '$baseUrl/tenant/stock/prepare-sku',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['lots'] is List) {
          final items = (data['lots'] as List)
              .map((i) => PrepareSkuLotRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'lots': items,
            'total_count': data['total_count'] ?? items.length,
          };
        }
      }
      return {
        'success': false,
        'lots': <PrepareSkuLotRecord>[],
        'total_count': 0,
      };
    } catch (e) {
      debugPrint("Error getPrepareSkuLotsData: $e");
      return {
        'success': false,
        'lots': <PrepareSkuLotRecord>[],
        'total_count': 0,
      };
    }
  }

  Future<List<PrepareSkuLotRecord>> getPrepareSkuLots(
    String token, {
    String? companyId,
    String? branchId,
    int? designerId,
    int? productId,
    int? purityId,
    String? fromDate,
    String? toDate,
    String? isActive,
    String? status,
  }) async {
    final data = await getPrepareSkuLotsData(
      token,
      companyId: companyId,
      branchId: branchId,
      designerId: designerId,
      productId: productId,
      purityId: purityId,
      fromDate: fromDate,
      toDate: toDate,
      isActive: isActive,
      status: status,
    );
    return data['lots'] as List<PrepareSkuLotRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createPrepareSkuLot(
    String token,
    PrepareSkuLotRecord record,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/stock/prepare-sku'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200 || res.statusCode == 201,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePrepareSkuLot(
    String token,
    int id,
    PrepareSkuLotRecord record,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/stock/prepare-sku/$id'),
        headers: _headers(token),
        body: jsonEncode(record.toJson()),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Soft deactivates/disables a Prepare SKU Lot
  Future<Map<String, dynamic>> deletePrepareSkuLot(String token, int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/stock/prepare-sku/$id'),
        headers: _headers(token),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Toggles activation/deactivation of a Prepare SKU Lot
  Future<Map<String, dynamic>> togglePrepareSkuLotActive(
    String token,
    int id,
    bool isActive,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/stock/prepare-sku/$id'),
        headers: _headers(token),
        body: jsonEncode({
          'is_active': isActive,
          'status': isActive ? 'ACTIVE' : 'DISABLED',
        }),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= SYSTEM CONTROLS CRUD (4th Menu under Settings) =================

  /// Fetches system controls along with last_sno and next_sno metadata
  Future<Map<String, dynamic>> getSystemControlsData(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/system-controls'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['controls'] is List) {
          final items = (data['controls'] as List)
              .map((i) => SystemControlRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'controls': items,
            'last_sno': data['last_sno'] ?? 0,
            'next_sno': data['next_sno'] ?? 1,
            'total_count': data['total_count'] ?? 0,
          };
        }
      }
      return {
        'success': false,
        'controls': <SystemControlRecord>[],
        'last_sno': 0,
        'next_sno': 1,
      };
    } catch (e) {
      debugPrint("Error getSystemControlsData: $e");
      return {
        'success': false,
        'controls': <SystemControlRecord>[],
        'last_sno': 0,
        'next_sno': 1,
      };
    }
  }

  Future<List<SystemControlRecord>> getSystemControls(String token) async {
    final data = await getSystemControlsData(token);
    return data['controls'] as List<SystemControlRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createSystemControl(
    String token,
    SystemControlRecord control,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/system-controls'),
        headers: _headers(token),
        body: jsonEncode(control.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSystemControl(
    String token,
    int sno,
    SystemControlRecord control,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/system-controls/$sno'),
        headers: _headers(token),
        body: jsonEncode(control.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteSystemControl(
    String token,
    int sno,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/system-controls/$sno'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= ESTIMATE / QUOTATION CRUD (3rd Main Menu) =================

  /// Fetches estimates with metadata (counts, total value, next estimate no) and optional filters
  Future<Map<String, dynamic>> getEstimatesData(
    String token, {
    String? search,
    String? status,
    String? fromDate,
    String? toDate,
    int? employeeId,
  }) async {
    try {
      final params = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      if (status != null &&
          status.trim().isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        params['status'] = status.trim().toUpperCase();
      }
      if (fromDate != null && fromDate.trim().isNotEmpty) {
        params['from_date'] = fromDate.trim();
      }
      if (toDate != null && toDate.trim().isNotEmpty) {
        params['to_date'] = toDate.trim();
      }
      if (employeeId != null && employeeId > 0) {
        params['employee_id'] = employeeId.toString();
      }

      final uri = Uri.parse(
        '$baseUrl/tenant/estimates',
      ).replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['estimates'] is List) {
          final items = (data['estimates'] as List)
              .map((i) => EstimateRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'estimates': items,
            'last_estimate_id': data['last_estimate_id'] ?? 0,
            'next_estimate_no': data['next_estimate_no'] ?? 'EST-1001',
            'total_count': data['total_count'] ?? 0,
            'open_count': data['open_count'] ?? 0,
            'total_value': (data['total_value'] as num?)?.toDouble() ?? 0.0,
            'today_count': data['today_count'] ?? 0,
          };
        }
      }
      return {
        'success': false,
        'estimates': <EstimateRecord>[],
        'next_estimate_no': 'EST-1001',
        'total_count': 0,
      };
    } catch (e) {
      debugPrint("Error getEstimatesData: $e");
      return {
        'success': false,
        'estimates': <EstimateRecord>[],
        'next_estimate_no': 'EST-1001',
        'total_count': 0,
      };
    }
  }

  Future<List<EstimateRecord>> getEstimates(String token) async {
    final data = await getEstimatesData(token);
    return data['estimates'] as List<EstimateRecord>? ?? [];
  }

  /// Looks up barcode / SKU directly from tagged stock inventory or prepare SKU lots
  Future<Map<String, dynamic>> lookupBarcodeForEstimate(
    String token,
    String sku,
  ) async {
    try {
      final clean = sku.trim();
      final uri = Uri.parse(
        '$baseUrl/tenant/estimates/barcode-lookup',
      ).replace(queryParameters: {'sku': clean});
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) return data;
      } else {
        try {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) return data;
        } catch (_) {}
      }
      return {
        'success': false,
        'message': 'Barcode "$clean" was not found in database.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Barcode lookup error: $e'};
    }
  }

  /// Searches available SKUs / lots from database for quick picking in Estimate
  Future<List<Map<String, dynamic>>> searchAvailableSkusForEstimate(
    String token, {
    String query = '',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/tenant/estimates/search-skus').replace(
        queryParameters: query.trim().isNotEmpty ? {'q': query.trim()} : null,
      );
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['items'] is List) {
          return List<Map<String, dynamic>>.from(data['items']);
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error searching SKUs: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createEstimate(
    String token,
    EstimateRecord estimate,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/estimates'),
        headers: _headers(token),
        body: jsonEncode(estimate.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateEstimate(
    String token,
    int estimateId,
    EstimateRecord estimate,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/estimates/$estimateId'),
        headers: _headers(token),
        body: jsonEncode(estimate.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteEstimate(
    String token,
    int estimateId,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/estimates/$estimateId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Deletes estimates by date range or specific date
  Future<Map<String, dynamic>> deleteEstimatesByDate(
    String token, {
    String? fromDate,
    String? toDate,
    String? beforeDate,
    String? date,
  }) async {
    try {
      final payload = <String, String>{};
      if (fromDate != null && fromDate.trim().isNotEmpty) {
        payload['from_date'] = fromDate.trim();
      }
      if (toDate != null && toDate.trim().isNotEmpty) {
        payload['to_date'] = toDate.trim();
      }
      if (beforeDate != null && beforeDate.trim().isNotEmpty) {
        payload['before_date'] = beforeDate.trim();
      }
      if (date != null && date.trim().isNotEmpty) payload['date'] = date.trim();

      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/estimates/bulk/date-range'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= EMPLOYEE MASTER CRUD =================

  /// Fetches employees with metadata (counts, next empid)
  Future<Map<String, dynamic>> getEmployeesData(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/employees'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['employees'] is List) {
          final items = (data['employees'] as List)
              .map((i) => EmployeeRecord.fromJson(i))
              .toList();
          return {
            'success': true,
            'employees': items,
            'last_empid': data['last_empid'] ?? 0,
            'next_empid': data['next_empid'] ?? 1001,
            'total_count': data['total_count'] ?? items.length,
            'active_count': data['active_count'] ?? 0,
            'inactive_count': data['inactive_count'] ?? 0,
          };
        }
      }
      return {
        'success': false,
        'employees': <EmployeeRecord>[],
        'last_empid': 0,
        'next_empid': 1001,
        'total_count': 0,
        'active_count': 0,
        'inactive_count': 0,
      };
    } catch (e) {
      debugPrint("Error getEmployeesData: $e");
      return {
        'success': false,
        'employees': <EmployeeRecord>[],
        'last_empid': 0,
        'next_empid': 1001,
        'total_count': 0,
        'active_count': 0,
        'inactive_count': 0,
      };
    }
  }

  Future<List<EmployeeRecord>> getEmployees(String token) async {
    final data = await getEmployeesData(token);
    return data['employees'] as List<EmployeeRecord>? ?? [];
  }

  Future<Map<String, dynamic>> createEmployee(
    String token,
    EmployeeRecord employee,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/employees'),
        headers: _headers(token),
        body: jsonEncode(employee.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateEmployee(
    String token,
    int empid,
    EmployeeRecord employee,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/employees/$empid'),
        headers: _headers(token),
        body: jsonEncode(employee.toJson()),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteEmployee(String token, int empid) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/employees/$empid'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= DAILY PURITY RATES & HISTORY CRUD (Rate Master) =================

  /// Fetches latest purity rates and ticker summary (Gold 24K, 22K 916, Silver)
  Future<LatestRatesSummary> getLatestRates(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/rates/latest'),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          return LatestRatesSummary.fromJson(data);
        }
      }
      return LatestRatesSummary();
    } catch (e) {
      debugPrint("Error getLatestRates: $e");
      return LatestRatesSummary();
    }
  }

  /// Fetches rates configured for a specific date (or defaults to last known rates)
  Future<Map<String, dynamic>> getRatesByDate(String token, String date) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/tenant/rates/by-date?date=${Uri.encodeComponent(date.trim())}',
        ),
        headers: _headers(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['rates'] is List) {
          final items = (data['rates'] as List)
              .map((i) => PurityRateItem.fromJson(i))
              .toList();
          return {
            'success': true,
            'target_date': data['target_date'] ?? date,
            'is_already_saved_for_date':
                data['is_already_saved_for_date'] ?? false,
            'rates': items,
          };
        }
      }
      return {
        'success': false,
        'rates': <PurityRateItem>[],
        'is_already_saved_for_date': false,
      };
    } catch (e) {
      debugPrint("Error getRatesByDate: $e");
      return {
        'success': false,
        'rates': <PurityRateItem>[],
        'is_already_saved_for_date': false,
      };
    }
  }

  /// Saves or updates all daily purity rates for a given date in one operation
  Future<Map<String, dynamic>> saveBulkRates(
    String token,
    String ratedate,
    List<PurityRateItem> rates,
  ) async {
    try {
      final payload = {
        'ratedate': ratedate.trim(),
        'rates': rates.map((r) => r.toJson()).toList(),
      };
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/rates/bulk-update'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetches historical rate logs with optional filters
  Future<List<RateHistoryRecord>> getRateHistory(
    String token, {
    String? fromDate,
    String? toDate,
    String? metalId,
    int? purityId,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, String>{'limit': limit.toString()};
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['from_date'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) queryParams['to_date'] = toDate;
      if (metalId != null && metalId.isNotEmpty && metalId != 'ALL') {
        queryParams['metalid'] = metalId;
      }
      if (purityId != null && purityId > 0) {
        queryParams['purityid'] = purityId.toString();
      }

      final uri = Uri.parse(
        '$baseUrl/tenant/rates/history',
      ).replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['history'] is List) {
          return (data['history'] as List)
              .map((i) => RateHistoryRecord.fromJson(i))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error getRateHistory: $e");
      return [];
    }
  }

  /// Deletes a specific historical rate record by ID
  Future<Map<String, dynamic>> deleteRateRecord(
    String token,
    int rateId,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/rates/$rateId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= MEDIA / IMAGEKIT UPLOAD METHODS =================

  /// Uploads an image (as raw bytes) to ImageKit via the ProGold backend API.
  /// Works across Flutter Web, Desktop, and Mobile.
  /// [fileBytes] - raw binary data of the picked image
  /// [fileName] - original or generated file name
  /// [folder] - destination folder category ('employees', 'catalogues', 'itemtags')
  Future<Map<String, dynamic>> uploadImage({
    required String token,
    required List<int> fileBytes,
    required String fileName,
    String folder = 'employees',
  }) async {
    try {
      final base64String = base64Encode(fileBytes);
      final payload = {
        'image': base64String,
        'fileName': fileName,
        'folder': folder,
      };

      final res = await http.post(
        Uri.parse('$baseUrl/tenant/upload/image'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );

      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }

      return {
        'success': res.statusCode == 200,
        'message': 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
      };
    } catch (e) {
      debugPrint("uploadImage error: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Deletes an uploaded image from ImageKit by fileId
  Future<Map<String, dynamic>> deleteUploadedImage(
    String token,
    String fileId,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/upload/image/$fileId'),
        headers: _headers(token),
      );
      if (res.body.isNotEmpty) {
        try {
          return jsonDecode(res.body);
        } catch (_) {}
      }
      return {'success': res.statusCode == 200};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= BARCODE TEMPLATES API METHODS =================

  /// Fetches all dynamic barcode label templates
  Future<Map<String, dynamic>> getBarcodeTemplates(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tenant/barcode-templates'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Creates a new barcode template
  Future<Map<String, dynamic>> createBarcodeTemplate(
    String token,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/barcode-templates'),
        headers: _headers(token),
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Updates an existing barcode template
  Future<Map<String, dynamic>> updateBarcodeTemplate(
    String token,
    int templateId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/barcode-templates/$templateId'),
        headers: _headers(token),
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Deletes a barcode template
  Future<Map<String, dynamic>> deleteBarcodeTemplate(
    String token,
    int templateId,
  ) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/barcode-templates/$templateId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Sets a template as the default print template
  Future<Map<String, dynamic>> setDefaultBarcodeTemplate(
    String token,
    int templateId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/barcode-templates/$templateId/set-default'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ================= STOCK BARCODE TAGGING API METHODS =================

  /// Retrieves tagged stock inventory items with optional filters
  Future<Map<String, dynamic>> getStockTags(
    String token, {
    String? companyId,
    String? branchId,
    int? lotId,
    String? status,
    String? search,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final params = <String, String>{};
      if (companyId != null && companyId.isNotEmpty) {
        params['companyid'] = companyId;
      }
      if (branchId != null && branchId.isNotEmpty) {
        params['branchid'] = branchId;
      }
      if (lotId != null) params['lot_id'] = lotId.toString();
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (fromDate != null && fromDate.isNotEmpty) {
        params['from_date'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) params['to_date'] = toDate;

      final uri = Uri.parse(
        '$baseUrl/tenant/stock/tags',
      ).replace(queryParameters: params.isNotEmpty ? params : null);
      final res = await http.get(uri, headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Looks up Value Addition (Price Setting) matching smith, product, and weight range
  Future<Map<String, dynamic>> lookupVaPriceSetting(
    String token, {
    String? companyId,
    String? branchId,
    required int productId,
    int? subproductId,
    String? accode,
    double? weight,
  }) async {
    try {
      final params = <String, String>{'productid': productId.toString()};
      if (companyId != null && companyId.isNotEmpty) {
        params['companyid'] = companyId;
      }
      if (branchId != null && branchId.isNotEmpty) {
        params['branchid'] = branchId;
      }
      if (subproductId != null) {
        params['subproductid'] = subproductId.toString();
      }
      if (accode != null && accode.isNotEmpty) params['accode'] = accode;
      if (weight != null) params['weight'] = weight.toString();

      final uri = Uri.parse(
        '$baseUrl/tenant/stock/va-lookup',
      ).replace(queryParameters: params);
      final res = await http.get(uri, headers: _headers(token));
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Generates individual or batch SKU tags from a source Lot
  Future<Map<String, dynamic>> generateTagsFromLot(
    String token,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/stock/tags/generate-from-lot'),
        headers: _headers(token),
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Updates a tagged stock item
  Future<Map<String, dynamic>> updateStockTag(
    String token,
    int tagId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/tenant/stock/tags/$tagId'),
        headers: _headers(token),
        body: jsonEncode(data),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Deletes a tagged stock item
  Future<Map<String, dynamic>> deleteStockTag(String token, int tagId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/tenant/stock/tags/$tagId'),
        headers: _headers(token),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Marks selected tags as printed
  Future<Map<String, dynamic>> markStockTagsPrinted(
    String token, {
    List<int>? itemIds,
    List<String>? skuCodes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tenant/stock/tags/mark-printed'),
        headers: _headers(token),
        body: jsonEncode({'item_ids': ?itemIds, 'sku_codes': ?skuCodes}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

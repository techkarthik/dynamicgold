import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import '../constants/app_version.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for Login
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  // Controllers for Register
  final _regEmailController = TextEditingController();
  final _regOtpController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regContactController = TextEditingController();

  bool _regObscure = true;
  bool _regConfirmObscure = true;

  DateTime _validFrom = DateTime.now();
  DateTime _validTo = DateTime.now().add(const Duration(days: 365));

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regEmailController.dispose();
    _regOtpController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _regContactController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final initialDate = isFrom ? _validFrom : _validTo;
    final firstDate = isFrom ? DateTime(2020) : _validFrom;
    final lastDate = DateTime(2040);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: GlassTheme.primaryNeon,
              onPrimary: Colors.white,
              surface: GlassTheme.bgSurface,
              onSurface: GlassTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _validFrom = picked;
          if (_validTo.isBefore(_validFrom)) {
            _validTo = _validFrom.add(const Duration(days: 30));
          }
        } else {
          _validTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: GlassTheme.bgDark,
      body: Stack(
        children: [
          // Background ambient luxury pastel gradient mesh
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 550,
              height: 550,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.primaryNeon.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.accentAmber.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.35,
            left: size.width * 0.3,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GlassTheme.accentCyan.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo & Title
                    _buildHeader(),
                    const SizedBox(height: 28),

                    // Main Glass Card Container
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 620 : 500,
                      ),
                      child: GlassContainer(
                        borderRadius: 24,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Content: either Company Selection or Login/Register Tabs
                            if (auth.isSelectingCompany) ...[
                              _buildCompanySelectionView(auth),
                            ] else ...[
                              // Tab Selector
                              _buildTabSelector(),
                              const SizedBox(height: 24),

                              // Alert messages
                              if (auth.errorMessage != null) ...[
                                _buildAlertBanner(
                                  auth.errorMessage!,
                                  isError: true,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (auth.successMessage != null) ...[
                                _buildAlertBanner(
                                  auth.successMessage!,
                                  isError: false,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Tab Views
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _tabController.index == 0
                                    ? _buildLoginForm(auth)
                                    : _buildRegisterForm(auth),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Footer
                    const Text(
                      "ProGold Multi-Tenant Cloud • Powered by PostgreSQL & Node.js",
                      style: TextStyle(
                        color: GlassTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppVersion.drawerVersion,
                      style: const TextStyle(
                        color: GlassTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x080F172A),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_rounded, color: GlassTheme.primaryNeon, size: 18),
              SizedBox(width: 8),
              Text(
                "Worship God.. Repect Human",
                style: TextStyle(
                  color: GlassTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (bounds) =>
              GlassTheme.primaryGradient.createShader(bounds),
          child: const Text(
            "ProGold",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Next-Gen Gold & ERP Database Platform for Modern Web",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: GlassTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {});
          Provider.of<AuthProvider>(context, listen: false).clearMessages();
        },
        indicator: BoxDecoration(
          gradient: GlassTheme.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: GlassTheme.primaryNeon.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: GlassTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        tabs: const [
          Tab(text: "Sign In"),
          Tab(text: "Register Tenant"),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(String message, {required bool isError}) {
    final color = isError ? GlassTheme.accentRose : GlassTheme.accentEmerald;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= LOGIN FORM =================
  Widget _buildLoginForm(AuthProvider auth) {
    if (!auth.isEmailVerifiedForLogin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTextField(
            controller: _loginEmailController,
            label: "Login Email",
            hint: "user@domain.com or admin@domain.com",
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          GlassButton(
            label: "Next",
            icon: Icons.arrow_forward_rounded,
            isLoading: auth.isLoading,
            onPressed: () async {
              final email = _loginEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter your email address"),
                  ),
                );
                return;
              }
              await auth.verifyEmailForLogin(email);
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              icon: const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: GlassTheme.accentAmber,
              ),
              label: const Text(
                "Quick Demo Auto-Fill (Registered Account)",
                style: TextStyle(color: GlassTheme.accentAmber, fontSize: 12),
              ),
              onPressed: () {
                _loginEmailController.text = "tenant_test@example.com";
              },
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: GlassTheme.primaryNeon.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: GlassTheme.primaryNeon.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle_rounded,
                  color: GlassTheme.primaryNeon,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome, ${auth.verifiedEmailUsername}!",
                        style: const TextStyle(
                          color: GlassTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${auth.verifiedEmail} • Role: ${auth.verifiedEmailRole}",
                        style: const TextStyle(
                          color: GlassTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassTextField(
            controller: _loginPasswordController,
            label: "Enter Password",
            hint: "••••••••",
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _loginObscure,
            suffixIcon: IconButton(
              icon: Icon(
                _loginObscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: GlassTheme.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
          ),
          const SizedBox(height: 24),
          GlassButton(
            label: "Sign In",
            icon: Icons.login_rounded,
            isLoading: auth.isLoading,
            onPressed: () async {
              final email = auth.verifiedEmail!;
              final password = _loginPasswordController.text;
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter your password")),
                );
                return;
              }
              final loggedIn = await auth.login(
                email: email,
                password: password,
              );
              if (loggedIn) {
                _loginPasswordController.clear();
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: GlassTheme.textMuted,
                ),
                label: const Text(
                  "Use a different email",
                  style: TextStyle(
                    color: GlassTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  auth.resetLoginVerification();
                  _loginPasswordController.clear();
                },
              ),
              TextButton.icon(
                icon: const Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: GlassTheme.accentAmber,
                ),
                label: const Text(
                  "Auto-Fill Password",
                  style: TextStyle(color: GlassTheme.accentAmber, fontSize: 12),
                ),
                onPressed: () {
                  _loginPasswordController.text = "Admin@123";
                },
              ),
            ],
          ),
        ],
      );
    }
  }

  // ================= REGISTER FORM =================
  Widget _buildRegisterForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Email & OTP Verification Section
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: GlassTextField(
                controller: _regEmailController,
                label: "Email Address (Tenant Master)",
                hint: "tenant@domain.com",
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                readOnly: auth.otpVerified,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GlassButton(
                height: 48,
                label: auth.otpCountdown > 0
                    ? "Resend (${auth.otpCountdown}s)"
                    : "Send OTP",
                icon: Icons.send_rounded,
                isLoading: auth.isLoading && !auth.otpSent,
                gradient: GlassTheme.cyanGradient,
                onPressed: (auth.otpCountdown > 0 || auth.otpVerified)
                    ? null
                    : () async {
                        final email = _regEmailController.text.trim();
                        final sent = await auth.sendOtp(email);
                        if (sent && auth.devOtpCode != null) {
                          _regOtpController.text = auth.devOtpCode!;
                        }
                      },
              ),
            ),
          ],
        ),

        // OTP Input Row
        if (auth.otpSent || auth.otpVerified) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: GlassTextField(
                  controller: _regOtpController,
                  label: "6-Digit Email OTP",
                  hint: "123456",
                  prefixIcon: Icons.security_rounded,
                  keyboardType: TextInputType.number,
                  readOnly: auth.otpVerified,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: auth.otpVerified
                    ? Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: GlassTheme.accentEmerald.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: GlassTheme.accentEmerald.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: GlassTheme.accentEmerald,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Verified",
                              style: TextStyle(
                                color: GlassTheme.accentEmerald,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GlassButton(
                        height: 48,
                        label: "Verify OTP",
                        icon: Icons.check_circle_outline,
                        isLoading: auth.isLoading,
                        gradient: GlassTheme.emeraldGradient,
                        onPressed: () {
                          auth.verifyOtp(
                            _regEmailController.text.trim(),
                            _regOtpController.text.trim(),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (auth.devOtpCode != null && !auth.otpVerified) ...[
            const SizedBox(height: 6),
            Text(
              "🔑 Dev Code: ${auth.devOtpCode} (Auto-filled for testing)",
              style: const TextStyle(
                color: GlassTheme.accentEmerald,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
        // 2. Password & Confirm Password
        Row(
          children: [
            Expanded(
              child: GlassTextField(
                controller: _regPasswordController,
                label: "Password",
                hint: "••••••••",
                prefixIcon: Icons.lock_outline,
                obscureText: _regObscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _regObscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: GlassTheme.textMuted,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _regObscure = !_regObscure),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassTextField(
                controller: _regConfirmPasswordController,
                label: "Confirm Password",
                hint: "••••••••",
                prefixIcon: Icons.lock_outline,
                obscureText: _regConfirmObscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _regConfirmObscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: GlassTheme.textMuted,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _regConfirmObscure = !_regConfirmObscure),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        // 3. Contact Number
        GlassTextField(
          controller: _regContactController,
          label: "Contact Number",
          hint: "+91 9876543210",
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 16),
        // 4. Validation Period (From Date & To Date)
        const Text(
          "Tenant Validation Period (Subscription Range)",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: GlassTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: GlassTheme.primaryNeon,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "From Date",
                            style: TextStyle(
                              fontSize: 10,
                              color: GlassTheme.textMuted,
                            ),
                          ),
                          Text(
                            _dateFormat.format(_validFrom),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: GlassTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 16,
                        color: GlassTheme.accentEmerald,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "To Date",
                            style: TextStyle(
                              fontSize: 10,
                              color: GlassTheme.textMuted,
                            ),
                          ),
                          Text(
                            _dateFormat.format(_validTo),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: GlassTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),
        // 5. PostgreSQL Database Information
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 18,
                        color: GlassTheme.primaryNeon,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "PostgreSQL Tenant Database",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "A private PostgreSQL schema will be created automatically for this account.",
                style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // 6. Register Action Button
        GlassButton(
          label: "Register Tenant Account",
          icon: Icons.app_registration_rounded,
          isLoading: auth.isLoading,
          onPressed: () async {
            final email = _regEmailController.text.trim();
            final password = _regPasswordController.text;
            final confirmPassword = _regConfirmPasswordController.text;
            final contact = _regContactController.text.trim();

            if (password != confirmPassword) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Passwords do not match.")),
              );
              return;
            }

            if (contact.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Contact number is required.")),
              );
              return;
            }

            await auth.registerTenant(
              email: email,
              password: password,
              contactNumber: contact,
              validFrom: _dateFormat.format(_validFrom),
              validTo: _dateFormat.format(_validTo),
            );
          },
        ),
      ],
    );
  }

  // ================= COMPANY SELECTION VIEW =================
  Widget _buildCompanySelectionView(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: GlassTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: GlassTheme.primaryNeon.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.corporate_fare_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Operating Company",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: GlassTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Your account has ${auth.availableCompanies.length} companies registered. Choose one to launch workspace.",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: GlassTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Company Cards List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: auth.availableCompanies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final company = auth.availableCompanies[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => auth.selectCompany(company),
                    hoverColor: GlassTheme.primaryNeon.withValues(alpha: 0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Company Icon / Initial Avatar
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                company.companyId,
                                style: const TextStyle(
                                  color: GlassTheme.primaryNeon,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Company Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        company.companyName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: GlassTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    StatusBadge(
                                      label: company.companyId,
                                      color: GlassTheme.primaryNeon,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: GlassTheme.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        [
                                          if (company.city.isNotEmpty)
                                            company.city,
                                          if (company.state.isNotEmpty)
                                            company.state,
                                        ].join(", ").ifEmpty("Headquarters"),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: GlassTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (company.mobileNumber.isNotEmpty ||
                                    company.gstNo.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (company.mobileNumber.isNotEmpty) ...[
                                        const Icon(
                                          Icons.phone_iphone_rounded,
                                          size: 13,
                                          color: GlassTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          company.mobileNumber,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: GlassTheme.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      if (company.gstNo.isNotEmpty) ...[
                                        const Icon(
                                          Icons.receipt_long_rounded,
                                          size: 13,
                                          color: GlassTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "GST: ${company.gstNo}",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: GlassTheme.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Selection Arrow
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GlassTheme.primaryNeon.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: GlassTheme.primaryNeon,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),

        // Sign Out / Change Account Option
        Center(
          child: TextButton.icon(
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: GlassTheme.textMuted,
            ),
            label: const Text(
              "Sign in with a different account",
              style: TextStyle(
                color: GlassTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            onPressed: () => auth.logout(),
          ),
        ),
      ],
    );
  }
}

extension _StringEmptyHelper on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

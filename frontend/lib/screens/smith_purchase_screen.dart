import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class SmithPurchaseScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(String module)? onNavigateModule;

  const SmithPurchaseScreen({
    super.key,
    this.onBack,
    this.onNavigateModule,
  });

  @override
  State<SmithPurchaseScreen> createState() => _SmithPurchaseScreenState();
}

class _SmithPurchaseScreenState extends State<SmithPurchaseScreen> {
  String _activeSection = "HUB"; // HUB, ENTRY, REGISTER, RECEIPT, LEDGER

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar with Breadcrumb
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Back",
                  onPressed: () {
                    if (_activeSection != "HUB") {
                      setState(() => _activeSection = "HUB");
                    } else if (widget.onBack != null) {
                      widget.onBack!();
                    }
                  },
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeSection == "HUB"
                          ? "Smith Purchase"
                          : "Smith Purchase > $_activeSection",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GlassTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Text(
                      "Smith Purchases, Inward Receipts & Karigar Ledger",
                      style: TextStyle(fontSize: 11, color: GlassTheme.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const Spacer(),
                const StatusBadge(
                  label: "Module Ready",
                  color: Color(0xFFD97706),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Main Content Area
            if (_activeSection == "HUB")
              _buildHubView(isDesktop)
            else
              _buildSectionPlaceholder(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildHubView(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome / Info Banner
        GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.all(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.diamond_rounded, color: Color(0xFFB45309), size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Smith Purchase Hub",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Gold bar and ornament purchases, karigar receipts, and metal account ledger.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78350F),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 4 Action Feature Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = isDesktop ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildActionCard(
                  width: cardWidth,
                  icon: Icons.add_circle_outline_rounded,
                  title: "Smith Purchase Entry",
                  desc: "Record new gold, silver & ornament purchases from smiths / karigars",
                  color: const Color(0xFF0284C7),
                  badge: "Entry",
                  onTap: () => setState(() => _activeSection = "ENTRY"),
                ),
                _buildActionCard(
                  width: cardWidth,
                  icon: Icons.receipt_long_rounded,
                  title: "Smith Purchase Register",
                  desc: "View, search, and export previous purchase transactions and invoices",
                  color: const Color(0xFF059669),
                  badge: "Register",
                  onTap: () => setState(() => _activeSection = "REGISTER"),
                ),
                _buildActionCard(
                  width: cardWidth,
                  icon: Icons.move_to_inbox_rounded,
                  title: "Smith Inward / Receipt",
                  desc: "Receive finished jewelry items, calculate wastage and touch purity",
                  color: const Color(0xFFD97706),
                  badge: "Inward",
                  onTap: () => setState(() => _activeSection = "RECEIPT"),
                ),
                _buildActionCard(
                  width: cardWidth,
                  icon: Icons.account_balance_wallet_rounded,
                  title: "Smith Metal & Cash Ledger",
                  desc: "Track smith-wise outstanding pure metal, alloy, and payment accounts",
                  color: const Color(0xFF7C3AED),
                  badge: "Ledger",
                  onTap: () => setState(() => _activeSection = "LEDGER"),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required double width,
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: GlassContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GlassTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GlassTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionPlaceholder(bool isDesktop) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.diamond_rounded, color: Color(0xFFB45309), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              "$_activeSection - Smith Purchase",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: GlassTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "This menu workspace is initialized and ready for your custom workflow specifications.",
              style: TextStyle(
                fontSize: 13,
                color: GlassTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text("Return to Smith Purchase Hub"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: const BorderSide(color: Color(0xFFD97706)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => setState(() => _activeSection = "HUB"),
            ),
          ],
        ),
      ),
    );
  }
}

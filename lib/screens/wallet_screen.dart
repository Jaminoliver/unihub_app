import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Define colors from the UI
    const Color purpleGradientStart = Color(0xFF7B2ABF);
    const Color purpleGradientEnd = Color(0xFF5B27A8);
    const Color lightPurpleInfoBg = Color(0xFFF3EFFF);
    const Color lightGreenBg = Color(0xFFE6F8F0);
    const Color darkGreenText = Color(0xFF00875A);
    const Color lightGreyBg = Color(0xFFF9FAFB);
    const Color lightGreyInfoText = Color(0xFF6B7280);
    const Color pendingYellow = Color(0xFFF79009);
    const Color pendingYellowBg = Color(0xFFFFFAEB);
    const Color completedGreen = Color(0xFF027A48);
    const Color completedGreenBg = Color(0xFFECFDF3);
    const Color errorRed = Color(0xFFD92D20);

    return Scaffold(
      backgroundColor: lightGreyBg,
      appBar: AppBar(
        backgroundColor: lightGreyBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Standard back navigation. If this is a root tab, it might do nothing.
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'My Wallet',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Total Wallet Balance Card
            _buildBalanceCard(purpleGradientStart, purpleGradientEnd),
            const SizedBox(height: 24),

            // 2. Auto-Save Card
            _buildAutoSaveCard(darkGreenText, lightGreenBg),
            const SizedBox(height: 16),

            // 3. Auto-Save Info Box
            _buildInfoBox(lightPurpleInfoBg, lightGreyInfoText),
            const SizedBox(height: 24),

            // 4. Total Earned & Savings Row
            _buildStatsRow(lightGreenBg, darkGreenText),
            const SizedBox(height: 24),

            // 5. Wallet Activity Feed
            _buildWalletActivityFeed(
              pendingYellow,
              pendingYellowBg,
              completedGreen,
              completedGreenBg,
              errorRed,
            ),
            const SizedBox(height: 24),

            // 6. How Your Wallet Works
            _buildHowWalletWorks(lightPurpleInfoBg, lightGreyInfoText),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildBalanceCard(Color gradientStart, Color gradientEnd) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientEnd.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Wallet Balance',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '₦665,000',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _buildBalanceRow(Icons.lock_outline, 'In Escrow', '₦450,000'),
          const SizedBox(height: 8),
          _buildBalanceRow(Icons.check_circle_outline, 'Available', '₦215,000'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: Colors.white.withOpacity(0.2)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionItem(Icons.add, 'Add Funds'),
              _buildActionItem(Icons.arrow_upward, 'Withdraw'),
              _buildActionItem(Icons.swap_horiz, 'Transfer'),
              _buildActionItem(Icons.receipt_long, 'Transactions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(IconData icon, String title, String amount) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        ),
        const Spacer(),
        Text(
          amount,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAutoSaveCard(Color darkGreenText, Color lightGreenBg) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lightGreenBg,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(Icons.savings_outlined, color: darkGreenText, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Auto-Save on Purchases',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: lightGreenBg,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: darkGreenText, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: GoogleFonts.inter(
                              color: darkGreenText,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Save 10% of every order automatically if balance allows',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: true,
            onChanged: (val) {},
            activeTrackColor: darkGreenText.withOpacity(0.3),
            activeColor: darkGreenText,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(Color lightPurpleInfoBg, Color lightGreyInfoText) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: lightPurpleInfoBg,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: lightGreyInfoText, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'When enabled, 10% of every purchase will be automatically saved to your wallet when sufficient balance is available. This helps you build savings while shopping!',
              style: GoogleFonts.inter(
                color: lightGreyInfoText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color lightGreenBg, Color darkGreenText) {
    // Define colors for the new savings card
    const Color lightBlueBg = Color(0xFFEBF5FF);
    const Color darkBlueText = Color(0xFF0057D9);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            bgColor: lightGreenBg,
            iconColor: darkGreenText,
            icon: Icons.trending_up,
            amount: '₦766k',
            label: 'Total Earned',
            trendIcon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            bgColor: lightBlueBg,
            iconColor: darkBlueText,
            icon: Icons.savings_outlined, // Savings icon
            amount: '₦42.5k', // Dummy value for savings
            label: 'Savings',
            trendIcon: Icons.arrow_upward, // Show savings growing
          ),
        ),
      ],
    );
  }

  // Reusable card for stats row
  Widget _buildStatCard({
    required Color bgColor,
    required Color iconColor,
    required IconData icon,
    required String amount,
    required String label,
    required IconData trendIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                  overflow:
                      TextOverflow.ellipsis, // <-- This is the corrected line
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(trendIcon, color: iconColor),
        ],
      ),
    );
  }

  Widget _buildWalletActivityFeed(
    Color pendingYellow,
    Color pendingYellowBg,
    Color completedGreen,
    Color completedGreenBg,
    Color errorRed,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Wallet Activity Feed',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5B27A8), // Use primary app color
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTransactionItem(
          icon: Icons.lock_outline,
          iconBg: pendingYellowBg,
          iconColor: pendingYellow,
          title: 'Escrow Locked (Order #1032)',
          date: 'Oct 21, 2025',
          amount: '₦15,000',
          amountColor: Colors.black,
          status: 'pending',
          statusColor: pendingYellow,
        ),
        _buildTransactionItem(
          icon: Icons.save_outlined,
          iconBg: completedGreenBg,
          iconColor: completedGreen,
          title: 'Auto-Save',
          date: 'Oct 20, 2025',
          amount: '+₦1,500',
          amountColor: completedGreen,
          status: 'completed',
          statusColor: completedGreen,
        ),
        _buildTransactionItem(
          icon: Icons.check_circle_outline,
          iconBg: completedGreenBg,
          iconColor: completedGreen,
          title: 'Escrow Released',
          date: 'Oct 18, 2025',
          amount: '+₦15,000',
          amountColor: completedGreen,
          status: 'completed',
          statusColor: completedGreen,
        ),
        _buildTransactionItem(
          icon: Icons.house_outlined,
          iconBg: errorRed.withOpacity(0.1),
          iconColor: errorRed,
          title: 'Withdrawal',
          date: 'Oct 17, 2025',
          amount: '-₦5,000',
          amountColor: errorRed,
          status: 'completed',
          statusColor: completedGreen,
        ),
      ],
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String date,
    required String amount,
    required Color amountColor,
    required String status,
    required Color statusColor,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowWalletWorks(
    Color lightPurpleInfoBg,
    Color lightGreyInfoText,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: lightPurpleInfoBg,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_person_outlined, color: Color(0xFF5B27A8)),
              const SizedBox(width: 8),
              Text(
                'How Your Wallet Works',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWalletWorksItem(
            'Escrow Protection: ',
            'Your funds are securely held in escrow and are only released to the seller once your order has been successfully delivered.',
            lightGreyInfoText,
          ),
          _buildWalletWorksItem(
            null,
            'Withdrawals are free and processed within 24 hours',
            lightGreyInfoText,
          ),
          _buildWalletWorksItem(
            null,
            'Top up your wallet anytime with Paystack or Flutterwave',
            lightGreyInfoText,
          ),
          _buildWalletWorksItem(
            null,
            'Your money is always secure with bank-level encryption',
            lightGreyInfoText,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletWorksItem(
    String? boldText,
    String normalText,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 13,
                  height: 1.5,
                ),
                children: [
                  if (boldText != null)
                    TextSpan(
                      text: boldText,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: normalText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

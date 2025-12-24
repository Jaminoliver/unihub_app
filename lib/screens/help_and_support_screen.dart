import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'dispute_chatbot_screen.dart';
import 'track_orders_screen.dart';
import 'view_disputes_screen.dart';

class HelpAndSupportScreen extends StatefulWidget {
  const HelpAndSupportScreen({super.key});

  @override
  State<HelpAndSupportScreen> createState() => _HelpAndSupportScreenState();
}

class _HelpAndSupportScreenState extends State<HelpAndSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToDispute(String reasonValue, String reasonLabel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DisputeChatbotScreen(
          preSelectedReason: reasonValue,
          preSelectedReasonLabel: reasonLabel,
        ),
      ),
    );
  }

  List<_FAQItem> get _filteredFAQs {
    if (_searchQuery.isEmpty) return _allFAQs;
    
    return _allFAQs.where((faq) {
      return faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Help & Support', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildSearchBar(),
          SizedBox(height: 20),
          _buildQuickIssueButtons(),
          SizedBox(height: 20),
          _buildPopularTopics(),
          SizedBox(height: 20),
          _buildFAQSection(),
          SizedBox(height: 20),
          _buildContactSection(),
          SizedBox(height: 20),
          _buildDisputeLink(),
          SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search for help...',
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.textLight, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: AppColors.textLight, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildQuickIssueButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How can we help?',
          style: AppTextStyles.subheading.copyWith(fontSize: 16),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildIssueChip(
              icon: Icons.local_shipping_outlined,
              label: "Where's my order?",
              color: AppColors.infoBlue,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackOrdersScreen())),
            ),
            _buildIssueChip(
              icon: Icons.refresh_outlined,
              label: 'Return item',
              color: AppColors.warningYellow,
              onTap: () => _navigateToDispute('refund_not_received', 'Return/Refund Request'),
            ),
            _buildIssueChip(
              icon: Icons.payment_outlined,
              label: 'Payment issue',
              color: AppColors.successGreen,
              onTap: () => _navigateToDispute('payment_issue', 'Payment Issue'),
            ),
            _buildIssueChip(
              icon: Icons.inventory_2_outlined,
              label: 'Wrong item',
              color: AppColors.errorRed,
              onTap: () => _navigateToDispute('wrong_item_received', 'Wrong Item Received'),
            ),
            _buildIssueChip(
              icon: Icons.chat_bubble_outline,
              label: 'Seller not responding',
              color: Color(0xFF8B5CF6),
              onTap: () => _navigateToDispute('seller_not_shipping', 'Seller Not Responding'),
            ),
            _buildIssueChip(
              icon: Icons.cancel_outlined,
              label: 'Cancel order',
              color: AppColors.textLight,
              onTap: () => _navigateToDispute('other', 'Order Cancellation Request'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIssueChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularTopics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Topics',
          style: AppTextStyles.subheading.copyWith(fontSize: 16),
        ),
        SizedBox(height: 12),
        _buildTopicCard(
          icon: Icons.local_shipping,
          title: 'Shipping & Delivery',
          subtitle: 'Track orders, delivery times',
          color: AppColors.infoBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackOrdersScreen())),
        ),
        SizedBox(height: 10),
        _buildTopicCard(
          icon: Icons.assignment_return,
          title: 'Returns & Refunds',
          subtitle: 'Return policy, refund status',
          color: AppColors.warningYellow,
          onTap: () => _navigateToDispute('refund_not_received', 'Return/Refund Request'),
        ),
        SizedBox(height: 10),
        _buildTopicCard(
          icon: Icons.account_circle_outlined,
          title: 'Account & Settings',
          subtitle: 'Manage profile, security',
          color: AppColors.successGreen,
          onTap: () => Navigator.pushNamed(context, '/settings'),
        ),
        SizedBox(height: 10),
        _buildTopicCard(
          icon: Icons.credit_card,
          title: 'Payment Methods',
          subtitle: 'Add cards, payment issues',
          color: Color(0xFF8B5CF6),
          onTap: () => _navigateToDispute('payment_issue', 'Payment Issue'),
        ),
      ],
    );
  }

  Widget _buildTopicCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    final faqs = _filteredFAQs;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primaryOrange, size: 22),
            SizedBox(width: 8),
            Text(
              'Frequently Asked Questions',
              style: AppTextStyles.subheading.copyWith(fontSize: 16),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: faqs.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, color: AppColors.textLight, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: faqs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final faq = entry.value;
                    return Column(
                      children: [
                        _FAQTile(faq: faq),
                        if (index < faqs.length - 1)
                          Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: AppColors.primaryOrange, size: 22),
              SizedBox(width: 8),
              Text(
                'Contact Support',
                style: AppTextStyles.subheading.copyWith(fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'We typically respond within 2-4 hours',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          SizedBox(height: 16),
          _buildContactRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: 'support@unihub.com',
            color: AppColors.infoBlue,
          ),
          SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: '+234 800 123 4567',
            color: AppColors.successGreen,
          ),
          SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.message_outlined,
            label: 'WhatsApp',
            value: '+234 800 123 4567',
            color: Color(0xFF25D366),
          ),
          SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.access_time,
            label: 'Support Hours',
            value: 'Mon-Fri: 9AM - 6PM WAT',
            color: AppColors.warningYellow,
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisputeLink() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textLight, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Still need help? Check FAQs first before raising a dispute.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ViewDisputesScreen()),
                ),
                icon: Icon(Icons.list_alt, size: 18),
                label: Text('View Disputes'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textLight,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DisputeChatbotScreen()),
                ),
                icon: Icon(Icons.flag_outlined, size: 18),
                label: Text('Report Issue'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// FAQ Tile Widget
class _FAQTile extends StatefulWidget {
  final _FAQItem faq;

  const _FAQTile({required this.faq});

  @override
  State<_FAQTile> createState() => _FAQTileState();
}

class _FAQTileState extends State<_FAQTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq.question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.remove : Icons.add,
                  color: AppColors.primaryOrange,
                  size: 20,
                ),
              ],
            ),
            if (_isExpanded) ...[
              SizedBox(height: 12),
              Text(
                widget.faq.answer,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// FAQ Data Model
class _FAQItem {
  final String question;
  final String answer;

  _FAQItem({required this.question, required this.answer});
}

// FAQ Data
final List<_FAQItem> _allFAQs = [
  _FAQItem(
    question: 'How do I track my order?',
    answer: 'Go to Orders tab, select your order, and tap "Track Order" to see real-time updates on your delivery status.',
  ),
  _FAQItem(
    question: 'What payment methods do you accept?',
    answer: 'We accept full payment, half payment (50% upfront), and pay on delivery for eligible orders.',
  ),
  _FAQItem(
    question: 'How long does delivery take?',
    answer: 'Delivery typically takes 2-5 business days within the same state, and 5-7 days for interstate deliveries.',
  ),
  _FAQItem(
    question: 'Can I cancel my order?',
    answer: 'Yes, you can cancel within 2 hours of placing the order if it hasn\'t been confirmed by the seller yet.',
  ),
  _FAQItem(
    question: 'What is your return policy?',
    answer: 'You can return items within 7 days of delivery if they\'re unused and in original packaging. Refunds are processed within 5-7 business days.',
  ),
  _FAQItem(
    question: 'How do I raise a dispute?',
    answer: 'Go to Help & Support > Report Issue. Select your order and describe the problem. Our team will review and respond within 24-48 hours.',
  ),
  _FAQItem(
    question: 'When will I get my refund?',
    answer: 'Refunds are processed within 5-7 business days after dispute resolution approval. Amount will be credited to your original payment method.',
  ),
  _FAQItem(
    question: 'How does the delivery code work?',
    answer: 'You receive a 6-digit code when placing an order. Share this code ONLY when you receive your item to confirm delivery and release payment to the seller.',
  ),
  _FAQItem(
    question: 'Is my payment secure?',
    answer: 'Yes! All payments are held in escrow until you confirm delivery. Your funds are protected throughout the transaction.',
  ),
  _FAQItem(
    question: 'How do I contact the seller?',
    answer: 'Seller contact information is available on the product page and in your order details after purchase.',
  ),
];
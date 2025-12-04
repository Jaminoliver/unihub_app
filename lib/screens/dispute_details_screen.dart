import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dispute_model.dart';
import '../services/dispute_service.dart';
import '../constants/app_colors.dart';
import 'package:intl/intl.dart';

class DisputeDetailsScreen extends StatefulWidget {
  final String disputeId;

  const DisputeDetailsScreen({
    super.key,
    required this.disputeId,
  });

  @override
  State<DisputeDetailsScreen> createState() => _DisputeDetailsScreenState();
}

class _DisputeDetailsScreenState extends State<DisputeDetailsScreen> {
  final DisputeService _disputeService = DisputeService();
  DisputeModel? _dispute;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDispute();
  }

  Future<void> _loadDispute() async {
    setState(() => _isLoading = true);
    try {
      final dispute = await _disputeService.getDisputeById(widget.disputeId);
      setState(() {
        _dispute = dispute;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dispute: $e')),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Dispute Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _dispute == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadDispute,
                  color: Color(0xFFFF6B35),
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      _buildStatusCard(),
                      SizedBox(height: 16),
                      _buildDisputeInfoCard(),
                      SizedBox(height: 16),
                      _buildOrderInfoCard(),
                      if (_dispute!.evidenceUrls != null && _dispute!.evidenceUrls!.isNotEmpty) ...[
                        SizedBox(height: 16),
                        _buildEvidenceCard(),
                      ],
                      if (_dispute!.isResolved) ...[
                        SizedBox(height: 16),
                        _buildResolutionCard(),
                      ],
                      SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Dispute not found',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getStatusGradient(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(_getStatusIcon(), color: Colors.white, size: 48),
          SizedBox(height: 12),
          Text(
            _dispute!.statusDisplayText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Order: ${_dispute!.orderNumber}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Priority: ${_dispute!.priority.toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_dispute!.status) {
      case 'open':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  List<Color> _getStatusGradient() {
    final color = _getStatusColor();
    return [color, color.withOpacity(0.7)];
  }

  IconData _getStatusIcon() {
    switch (_dispute!.status) {
      case 'open':
        return Icons.report_problem;
      case 'under_review':
        return Icons.search;
      case 'resolved':
        return Icons.check_circle;
      case 'closed':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Widget _buildDisputeInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report, color: Colors.red[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Dispute Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow('Reason', _dispute!.reasonDisplayText, Icons.error_outline),
          Divider(height: 20),
          _buildInfoRow('Raised By', _dispute!.raisedByType.toUpperCase(), Icons.person),
          Divider(height: 20),
          _buildInfoRow(
            'Created',
            _formatDate(_dispute!.createdAt),
            Icons.calendar_today,
          ),
          SizedBox(height: 16),
          Text(
            'Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              _dispute!.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              if (_dispute!.productImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _dispute!.productImageUrl!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImage(),
                  ),
                )
              else
                _placeholderImage(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dispute!.productName ?? 'Product',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Order: ${_dispute!.orderNumber}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _dispute!.formattedAmount,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
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
  }

  Widget _buildEvidenceCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image, color: Colors.blue[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Evidence (${_dispute!.evidenceUrls!.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _dispute!.evidenceUrls!.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _viewImage(_dispute!.evidenceUrls![index]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _dispute!.evidenceUrls![index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 20),
              SizedBox(width: 8),
              Text(
                'Resolution',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _dispute!.resolution ?? 'No resolution details available',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),
          if (_dispute!.resolvedAt != null) ...[
            SizedBox(height: 8),
            Text(
              'Resolved ${_formatDate(_dispute!.resolvedAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image, color: Colors.grey[400]),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final format = DateFormat('E, d MMM yyyy \'at\' h:mm a');
    return format.format(date);
  }

  void _viewImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            SizedBox(height: 16),
            CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
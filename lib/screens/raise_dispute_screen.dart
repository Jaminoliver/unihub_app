import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/order_model.dart';
import '../services/dispute_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Theme constants
const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kNavyBlue = Color(0xFF1E3A8A);
const kTextLight = Color(0xFF6B7280);
const kTextDark = Color(0xFF1F2937);
const kAshGray = Color(0xFFF5F5F7);
const kWhite = Colors.white;

class RaiseDisputeScreen extends StatefulWidget {
  final OrderModel order;

  const RaiseDisputeScreen({super.key, required this.order});

  @override
  State<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends State<RaiseDisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final DisputeService _disputeService = DisputeService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedReasonValue;
  List<Map<String, String>> _disputeReasons = [];
  List<File> _evidenceImages = [];
  bool _isLoading = false;
  bool _isLoadingReasons = true;

  @override
  void initState() {
    super.initState();
    _loadDisputeReasons();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadDisputeReasons() {
    try {
      setState(() {
        _disputeReasons = _disputeService.getDisputeReasons();
        _isLoadingReasons = false;
      });
    } catch (e) {
      setState(() => _isLoadingReasons = false);
      _showError('Failed to load dispute reasons: $e');
    }
  }

  Future<void> _pickImage() async {
    if (_evidenceImages.length >= 5) {
      _showError('Maximum 5 images allowed');
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _evidenceImages.add(File(image.path));
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_evidenceImages.length >= 5) {
      _showError('Maximum 5 images allowed');
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _evidenceImages.add(File(photo.path));
        });
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _evidenceImages.removeAt(index);
    });
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedReasonValue == null) {
      _showError('Please select a dispute reason');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showError('User not authenticated');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Create the dispute first (without evidence URLs)
      final dispute = await _disputeService.createDispute(
        orderId: widget.order.id,
        raisedByUserId: user.id,
        raisedByType: 'buyer',
        disputeReason: _selectedReasonValue!,
        description: _descriptionController.text.trim(),
        evidenceUrls: [], // Will update after uploading
      );

      // Step 2: Upload evidence images if any
      List<String> evidenceUrls = [];
      if (_evidenceImages.isNotEmpty) {
        for (var image in _evidenceImages) {
          try {
            final url = await _disputeService.uploadDisputeAttachment(
              dispute.id,
              image,
            );
            if (url != null) {
              evidenceUrls.add(url);
            }
          } catch (e) {
            print('Warning: Failed to upload evidence image: $e');
            // Continue with other images
          }
        }

        // Step 3: Update dispute with evidence URLs if any were uploaded
        if (evidenceUrls.isNotEmpty) {
          try {
            await Supabase.instance.client
                .from('disputes')
                .update({'evidence_urls': evidenceUrls})
                .eq('id', dispute.id);
          } catch (e) {
            print('Warning: Failed to update evidence URLs: $e');
          }
        }
      }

      if (!mounted) return;

      // Show success and navigate back
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to submit dispute: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 50, color: Colors.green),
            ),
            const SizedBox(height: 20),
            const Text(
              'Dispute Submitted!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your dispute has been submitted successfully. Our team will review it within 24-48 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: kTextLight, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to Help & Support
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: kWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Evidence',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
                ),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Use camera', style: TextStyle(fontSize: 12, color: kTextLight)),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF10B981)),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select from photos', style: TextStyle(fontSize: 12, color: kTextLight)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: kWhite),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAshGray,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: const Text(
            'Raise Dispute',
            style: TextStyle(
              color: kWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
      body: _isLoadingReasons
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderInfoCard(),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Reason for Dispute', Icons.report_problem),
                        const SizedBox(height: 12),
                        _buildReasonSelector(),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Description', Icons.description),
                        const SizedBox(height: 12),
                        _buildDescriptionField(),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Evidence (Optional)', Icons.photo_library),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload photos to support your dispute (max 5)',
                          style: TextStyle(fontSize: 12, color: kTextLight),
                        ),
                        const SizedBox(height: 12),
                        _buildEvidenceSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildSubmitButton(),
              ],
            ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: kOrangeGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_bag, color: kWhite, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(fontSize: 12, color: kTextLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.order.orderNumber,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.order.orderStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.order.orderStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(widget.order.orderStatus),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _OrderDetailItem(
                icon: Icons.calendar_today,
                label: 'Order Date',
                value: _formatDate(widget.order.createdAt),
              ),
              _OrderDetailItem(
                icon: Icons.payments,
                label: 'Amount',
                value: '₦${widget.order.totalAmount.toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => kOrangeGradient.createShader(bounds),
          child: Icon(icon, size: 20, color: kWhite),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
        ),
      ],
    );
  }

  Widget _buildReasonSelector() {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedReasonValue,
        decoration: InputDecoration(
          hintText: 'Select a reason',
          hintStyle: const TextStyle(color: kTextLight, fontSize: 14),
          prefixIcon: const Icon(Icons.report, color: Color(0xFFFF6B35)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: kWhite,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: _disputeReasons.map((reason) {
          return DropdownMenuItem(
            value: reason['value'],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reason['label']!,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  reason['description']!,
                  style: const TextStyle(fontSize: 11, color: kTextLight),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedReasonValue = value);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a dispute reason';
          }
          return null;
        },
        isExpanded: true,
        selectedItemBuilder: (BuildContext context) {
          return _disputeReasons.map<Widget>((reason) {
            return Text(
              reason['label']!,
              style: const TextStyle(fontSize: 14),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 6,
        maxLength: 500,
        decoration: InputDecoration(
          hintText: 'Describe the issue in detail...',
          hintStyle: const TextStyle(color: kTextLight, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: kWhite,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: const TextStyle(fontSize: 11, color: kTextLight),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please provide a description';
          }
          if (value.trim().length < 20) {
            return 'Description must be at least 20 characters';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      children: [
        if (_evidenceImages.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidenceImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _evidenceImages[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: kWhite, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          onTap: _evidenceImages.length < 5 ? _showImagePickerOptions : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _evidenceImages.length < 5
                    ? const Color(0xFFFF6B35).withOpacity(0.3)
                    : kTextLight.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  color: _evidenceImages.length < 5 ? const Color(0xFFFF6B35) : kTextLight,
                ),
                const SizedBox(width: 8),
                Text(
                  _evidenceImages.isEmpty
                      ? 'Add Photos'
                      : 'Add More (${_evidenceImages.length}/5)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _evidenceImages.length < 5 ? const Color(0xFFFF6B35) : kTextLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitDispute,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              disabledBackgroundColor: kTextLight.withOpacity(0.3),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: kWhite, strokeWidth: 2),
                  )
                : const Text(
                    'Submit Dispute',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'refunded':
        return Colors.red;
      default:
        return kTextLight;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Helper Widgets
class _OrderDetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OrderDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kTextLight),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: kTextLight)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark)),
          ],
        ),
      ],
    );
  }
}
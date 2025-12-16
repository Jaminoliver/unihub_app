import 'package:flutter/material.dart';
import 'dart:io';
import '../models/order_model.dart';

// ==================== PROGRESS INDICATOR ====================
class DisputeProgressIndicator extends StatelessWidget {
  final int currentStep;

  const DisputeProgressIndicator({Key? key, required this.currentStep}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: List.generate(5, (index) {
          final stepNum = index + 1;
          final isActive = stepNum <= currentStep;
          final isCompleted = stepNum < currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? Color(0xFF3B82F6) : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted 
                      ? Icon(Icons.check, size: 16, color: Colors.white)
                      : Text('$stepNum', style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
                if (index < 4)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: stepNum < currentStep ? Color(0xFF3B82F6) : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ==================== INFO BANNER ====================
class DisputeInfoBanner extends StatelessWidget {
  final String disputeNumber;
  final String orderNumber;

  const DisputeInfoBanner({
    Key? key,
    required this.disputeNumber,
    required this.orderNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFDCEFFF),
        border: Border(bottom: BorderSide(color: Color(0xFF3B82F6).withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Color(0xFF1E40AF)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dispute: $disputeNumber • Order: $orderNumber',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E40AF)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== TYPING INDICATOR ====================
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, size: 18, color: Colors.white),
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                child: _AnimatedDot(),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Opacity(
          opacity: 0.3 + (value * 0.7),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}

// ==================== CHATBOT INPUT (STEP 3 - DESCRIPTION) ====================
class DisputeDescriptionInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const DisputeDescriptionInput({
    Key? key,
    required this.controller,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Describe the issue in detail...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Color(0xFFF3F4F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: IconButton(
              icon: Icon(Icons.send_rounded, color: Colors.white),
              onPressed: onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== EVIDENCE INPUT (STEP 4) ====================
class DisputeEvidenceInput extends StatelessWidget {
  final List<File> selectedImages;
  final VoidCallback onPickImages;
  final VoidCallback onContinue;
  final Function(int) onRemoveImage;

  const DisputeEvidenceInput({
    Key? key,
    required this.selectedImages,
    required this.onPickImages,
    required this.onContinue,
    required this.onRemoveImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedImages.isNotEmpty) ...[
            Container(
              height: 80,
              margin: EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: selectedImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    margin: EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(selectedImages[index], width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => onRemoveImage(index),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickImages,
                  icon: Icon(Icons.add_photo_alternate_rounded),
                  label: Text(selectedImages.isEmpty ? 'Add Images' : 'Add More (${selectedImages.length})'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Color(0xFF3B82F6)),
                    foregroundColor: Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onContinue,
                  child: Text('Continue'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== SUBMIT BUTTON (STEP 5) ====================
class DisputeSubmitButton extends StatelessWidget {
  final VoidCallback onSubmit;

  const DisputeSubmitButton({Key? key, required this.onSubmit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: ElevatedButton(
        onPressed: onSubmit,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded),
            SizedBox(width: 10),
            Text('Submit Dispute', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF3B82F6),
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ==================== ADMIN CHAT INPUT ====================
class DisputeAdminChatInput extends StatelessWidget {
  final TextEditingController controller;
  final List<File> pendingImages;
  final bool isSendingMessage;
  final bool isUploadingImage;
  final VoidCallback onPickImages;
  final VoidCallback onSendMessage;
  final VoidCallback onSendPendingImages;
  final Function(int) onRemovePendingImage;

  const DisputeAdminChatInput({
    Key? key,
    required this.controller,
    required this.pendingImages,
    required this.isSendingMessage,
    required this.isUploadingImage,
    required this.onPickImages,
    required this.onSendMessage,
    required this.onSendPendingImages,
    required this.onRemovePendingImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingImages.isNotEmpty) ...[
            Container(
              height: 100,
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.all(8),
                      itemCount: pendingImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 84,
                          margin: EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(pendingImages[index], width: 84, height: 84, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => onRemovePendingImage(index),
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(left: 8, right: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: isUploadingImage ? null : onSendPendingImages,
                          icon: isUploadingImage
                              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.send, color: Color(0xFF3B82F6)),
                        ),
                        Text('${pendingImages.length}', 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isUploadingImage && pendingImages.isEmpty)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Color(0xFFDCEFFF), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Uploading images...', 
                    style: TextStyle(fontSize: 13, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(Icons.add_photo_alternate, color: Color(0xFF3B82F6)),
                  onPressed: isUploadingImage ? null : onPickImages,
                  tooltip: 'Add Images',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !isSendingMessage && !isUploadingImage,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: IconButton(
                  icon: isSendingMessage
                      ? SizedBox(width: 20, height: 20, 
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: (isSendingMessage || isUploadingImage) ? null : onSendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== CLOSED BANNER ====================
class DisputeClosedBanner extends StatelessWidget {
  const DisputeClosedBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)]),
        border: Border(top: BorderSide(color: Color(0xFF10B981), width: 2)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF065F46), size: 24),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Dispute Resolved', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 15)),
                Text('This case has been closed', style: TextStyle(color: Color(0xFF047857), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== DIALOGS ====================
void showManualOrderEntryDialog(BuildContext context, Function(String) onVerify) {
  showDialog(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      String? errorText;
      
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.help_outline, color: Color(0xFF3B82F6)),
                SizedBox(width: 12),
                Text('Can\'t Find Your Order?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your order number manually:',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'ORD######',
                    helperText: 'Format: ORD followed by 6 digits',
                    helperStyle: TextStyle(fontSize: 11),
                    prefixIcon: Icon(Icons.shopping_bag),
                    errorText: errorText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value.isEmpty) {
                        errorText = null;
                      } else if (!RegExp(r'^ORD\d{6}$').hasMatch(value.toUpperCase())) {
                        errorText = 'Invalid format';
                      } else {
                        errorText = null;
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
              ElevatedButton(
                onPressed: errorText != null || controller.text.trim().isEmpty
                    ? null
                    : () {
                        final orderNum = controller.text.trim().toUpperCase();
                        Navigator.pop(context);
                        onVerify(orderNum);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Verify Order'),
              ),
            ],
          );
        },
      );
    },
  );
}

void showOrderNotFoundDialog(
  BuildContext context, 
  String orderNum, 
  String message, 
  {bool isWrongAccount = false, 
  List<String>? suggestions,
  required VoidCallback onTryAgain,
  required Function(String) onSuggestionTap,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          SizedBox(width: 12),
          Text('Order Not Found'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$orderNum',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.orange[900],
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 14, height: 1.4)),
          if (suggestions != null && suggestions.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              'Did you mean:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(height: 8),
            ...suggestions.map((s) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onSuggestionTap(s);
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFFDCEFFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF3B82F6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF1E40AF)),
                      SizedBox(width: 8),
                      Text(s, style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            )),
          ],
          if (!isWrongAccount) ...[
            SizedBox(height: 16),
            Text(
              '✓ Check the order number\n✓ Verify spelling and format',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Contact support feature coming soon')),
            );
          },
          child: Text('Contact Support'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onTryAgain();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF3B82F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Try Again'),
        ),
      ],
    ),
  );
}

void showExitDisputeDialog(BuildContext context, VoidCallback onExit) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Text('Exit Dispute?'),
        ],
      ),
      content: Text('Your progress will be saved. You can resume this dispute later from where you left off.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            onExit();
          },
          child: Text('Exit'),
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3B82F6)),
        ),
      ],
    ),
  );
}

void showStartNewDisputeDialog(BuildContext context, VoidCallback onStartNew) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.add_circle, color: Color(0xFF3B82F6)),
          SizedBox(width: 12),
          Text('Start New Dispute?'),
        ],
      ),
      content: Text('This will save your current progress and start a new dispute. You can resume this one later.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onStartNew();
          },
          child: Text('Start New'),
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF3B82F6)),
        ),
      ],
    ),
  );
}
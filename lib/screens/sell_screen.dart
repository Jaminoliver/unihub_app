import 'package:flutter/material.dart';
import '../constants/style.dart';

class SellScreen extends StatelessWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Sell Items', style: AppText.heading),
        centerTitle: true,
      ),
      body: Padding(
        padding: AppPadding.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏷️ Sell Screen', style: AppText.subheading),
            const SizedBox(height: 10),
            Text(
              'List new products for sale on your campus.',
              style: AppText.body,
            ),
          ],
        ),
      ),
    );
  }
}

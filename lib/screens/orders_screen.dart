import 'package:flutter/material.dart';
import '../constants/style.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('My Orders', style: AppText.heading),
        centerTitle: true,
      ),
      body: Padding(
        padding: AppPadding.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📦 Orders Screen', style: AppText.subheading),
            const SizedBox(height: 10),
            Text(
              'Track your purchases and deliveries here.',
              style: AppText.body,
            ),
          ],
        ),
      ),
    );
  }
}

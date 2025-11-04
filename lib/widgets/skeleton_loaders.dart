import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

/// A widget to show a single shimmering skeleton box.
class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black, // Shimmer's base color, doesn't matter
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A shimmering placeholder for a grid of products.
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;
  const ProductGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.background, // Use your app's background color
      highlightColor: AppColors.white, // Use your app's white/light color
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(
                width: double.infinity,
                height: 160,
                borderRadius: 16,
              ),
              SizedBox(height: 10),
              _SkeletonBox(width: 140, height: 16),
              SizedBox(height: 6),
              _SkeletonBox(width: 80, height: 18),
            ],
          );
        },
      ),
    );
  }
}

/// A shimmering placeholder for a horizontal list of products.
class HorizontalProductListSkeleton extends StatelessWidget {
  final int itemCount;
  const HorizontalProductListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.background,
      highlightColor: AppColors.white,
      child: SizedBox(
        height: 280, // Matches your horizontal list height
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Container(
              width: 170,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 170, height: 160, borderRadius: 16),
                  SizedBox(height: 10),
                  _SkeletonBox(width: 140, height: 16),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 80, height: 18),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 120, height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A shimmering placeholder for the category filter chips.
class CategoryChipsSkeleton extends StatelessWidget {
  final bool isCircle;
  const CategoryChipsSkeleton({super.key, this.isCircle = false});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.background,
      highlightColor: AppColors.white,
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 5,
          itemBuilder: (context, index) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: _SkeletonBox(width: 100, height: 40, borderRadius: 20),
            );
          },
        ),
      ),
    );
  }
}

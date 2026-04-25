import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AdminDashboardSkeleton extends StatelessWidget {
  const AdminDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Sidebar Skeleton
          Container(
            width: 280,
            color: AppColors.brandDark,
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                _buildShimmerCircle(64),
                const SizedBox(height: 16),
                _buildShimmerRect(150, 24),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.builder(
                    itemCount: 8,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          _buildShimmerCircle(24),
                          const SizedBox(width: 16),
                          _buildShimmerRect(120, 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content Skeleton
          Expanded(
            child: Column(
              children: [
                // Header Skeleton
                Container(
                  height: 64,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildShimmerRect(200, 24),
                      const Spacer(),
                      _buildShimmerCircle(32),
                      const SizedBox(width: 16),
                      _buildShimmerCircle(32),
                    ],
                  ),
                ),
                // Body Skeleton
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildShimmerCard(120)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildShimmerCard(120)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildShimmerCard(120)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildShimmerCard(120)),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildShimmerCard(double.infinity)),
                              const SizedBox(width: 32),
                              Expanded(flex: 2, child: _buildShimmerCard(double.infinity)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerRect(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildShimmerCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildShimmerCard(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShimmerRect(100, 16),
            const SizedBox(height: 12),
            _buildShimmerRect(150, 24),
          ],
        ),
      ),
    );
  }
}

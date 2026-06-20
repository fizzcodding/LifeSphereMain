import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Displays the "HollowCore -:- LifeSphere" branding.
///
/// Can be used in app bars, splash screens, and onboarding flows.
class HollowCoreBrand extends StatelessWidget {
  const HollowCoreBrand({
    super.key,
    this.size = BrandSize.medium,
    this.showSubtitle = true,
  });

  /// Visual size variant.
  final BrandSize size;

  /// Whether to show the subtitle line below the brand name.
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (size) {
      case BrandSize.small:
        return _buildSmall(context, colorScheme);
      case BrandSize.medium:
        return _buildMedium(context, colorScheme);
      case BrandSize.large:
        return _buildLarge(context, colorScheme);
    }
  }

  Widget _buildSmall(BuildContext context, ColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: colors.primary),
        const SizedBox(width: 6),
        Text(
          AppConstants.hollowCoreBranding,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildMedium(BuildContext context, ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hexagon, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              AppConstants.hollowCoreBranding,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            '— part of the LifeSphere ecosystem —',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLarge(BuildContext context, ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hexagon, size: 48, color: colors.primary),
        const SizedBox(height: 16),
        Text(
          AppConstants.hollowCoreBranding,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '-:- LifeSphere -:-',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: colors.primary,
            letterSpacing: 4,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 12),
          Text(
            'A part of the LifeSphere ecosystem',
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

/// Visual size variants for [HollowCoreBrand].
enum BrandSize { small, medium, large }

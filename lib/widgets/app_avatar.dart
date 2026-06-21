import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl = '',
    this.size = 44,
  });

  final String name;
  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    final initials =
        name.trim().isEmpty
            ? 'JS'
            : name
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((part) => part.characters.first.toUpperCase())
                .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.forest,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child:
          cleanUrl.isNotEmpty
              ? Image.network(cleanUrl, fit: BoxFit.cover)
              : Center(
                child: Text(
                  initials,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
    );
  }
}

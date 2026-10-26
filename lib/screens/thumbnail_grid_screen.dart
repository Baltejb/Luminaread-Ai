import 'package:flutter/material.dart';

import '../models/translation_models.dart';
import '../theme/app_theme.dart';

class ThumbnailGridScreen extends StatelessWidget {
  const ThumbnailGridScreen({super.key, required this.pages, required this.currentPage});

  final List<TranslatedPage> pages;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('All pages')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          final page = pages[index];
          final selected = index == currentPage;
          return InkWell(
            onTap: () => Navigator.of(context).pop(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? accent : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      child: page.imageBytes != null
                          ? Image.memory(
                              page.imageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                                color: Colors.white,
                                child: Icon(Icons.broken_image_outlined, color: Colors.black26),
                              ),
                            )
                          : const ColoredBox(color: Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

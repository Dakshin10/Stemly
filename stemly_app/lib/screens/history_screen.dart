import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_history.dart';
import '../presentation/components/components.dart';
import '../storage/history_store.dart';
import '../strings.dart';
import '../theme/theme.dart';
import 'scan_result_screen.dart';

/// HIG-compliant History Screen for STEMLY.
/// Inset cards, 56 dp thumbnails, star toggling with accessible Semantics,
/// swipe-to-delete with undo, and category filter chips.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = AppStrings.filterAll;

  final List<String> _filters = const [
    AppStrings.filterAll,
    AppStrings.filterPhysics,
    AppStrings.filterMathematics,
    AppStrings.filterChemistry,
    AppStrings.filterStarred,
  ];

  @override
  void initState() {
    super.initState();
    _cleanupOldHistory();
  }

  void _cleanupOldHistory() {
    final list = HistoryStore.history;
    if (list.length > 50) {
      HistoryStore.setHistory(list.sublist(list.length - 50));
    }
  }

  Future<void> _clearNonStarred() async {
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: AppStrings.deleteScansConfirmTitle,
      message: AppStrings.deleteScansConfirmBody,
      confirmLabel: AppStrings.delete,
      isDestructive: true,
    );

    if (confirmed == true) {
      final unstarred = HistoryStore.history.where((h) => !h.isStarred).toList();
      for (var h in unstarred) {
        await HistoryStore.remove(h);
      }
      if (mounted) setState(() {});
    }
  }

  List<ScanHistory> _getFilteredHistory() {
    final list = HistoryStore.history;
    if (_selectedFilter == AppStrings.filterAll) return list;
    if (_selectedFilter == AppStrings.filterStarred) {
      return list.where((h) => h.isStarred).toList();
    }
    // Filter by topic keyword
    return list.where((h) {
      final topicLower = h.topic.toLowerCase();
      final filterLower = _selectedFilter.toLowerCase();
      return topicLower.contains(filterLower);
    }).toList();
  }

  String _formatRelativeDate(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      return "Today";
    } else if (diff.inDays == 1) {
      return "Yesterday";
    } else if (diff.inDays < 7) {
      return "${diff.inDays} days ago";
    } else {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = HistoryStore.history;
    final filteredHistory = _getFilteredHistory();
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return AppScaffold(
      title: AppStrings.historyTitle,
      isLargeTitle: true,
      currentBottomNavIndex: 1,
      actions: [
        if (allHistory.any((h) => !h.isStarred))
          TextButton(
            onPressed: _clearNonStarred,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, AppSpacing.minTouchTarget),
            ),
            child: Text(
              AppStrings.clearHistory,
              style: AppTypography.subhead(context).copyWith(
                color: AppColors.error(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),

            // FILTER CHIPS ROW
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;

                  return FilterChip(
                    label: Text(
                      filter,
                      style: AppTypography.footnote(context).copyWith(
                        color: isSelected
                            ? AppColors.onPrimary(context)
                            : textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppColors.primary(context),
                    backgroundColor: AppColors.surface(context),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary(context)
                          : AppColors.divider(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = filter);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // CONTENT: EMPTY STATE OR LIST
            if (filteredHistory.isEmpty)
              EmptyState(
                icon: Icons.history_rounded,
                title: "No scans in this view",
                message: _selectedFilter == AppStrings.filterStarred
                    ? "Star important problem scans to quickly access them here."
                    : "Problem scans you complete will appear here.",
              )
            else
              GroupedSection(
                children: filteredHistory.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final file = File(item.imagePath);
                  final hasImage = item.imagePath.isNotEmpty && file.existsSync();

                  return Dismissible(
                    key: ValueKey(item.timestamp.toIso8601String()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      color: AppColors.error(context),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                    ),
                    confirmDismiss: (_) async {
                      if (item.isStarred) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Unstar this item before deleting.")),
                        );
                        return false;
                      }
                      return true;
                    },
                    onDismissed: (_) {
                      final removedItem = item;
                      final removedIndex = index;
                      HistoryStore.remove(removedItem);
                      setState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("${AppStrings.scanDeleted}: '${removedItem.topic}'"),
                          duration: const Duration(seconds: 6),
                          action: SnackBarAction(
                            label: AppStrings.undo,
                            textColor: AppColors.primary(context),
                            onPressed: () {
                              HistoryStore.history.insert(removedIndex, removedItem);
                              HistoryStore.setHistory(HistoryStore.history);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                    child: GroupedRow(
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant(context),
                          borderRadius: BorderRadius.circular(AppRadii.input),
                          image: hasImage
                              ? DecorationImage(
                                  image: FileImage(file),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: !hasImage
                            ? Icon(Icons.science_outlined, color: AppColors.primary(context), size: 26)
                            : null,
                      ),
                      title: item.topic,
                      subtitle: _formatRelativeDate(item.timestamp) +
                          (item.variables.isNotEmpty
                              ? " • ${item.variables.take(3).join(', ')}"
                              : ""),
                      trailing: IconButton(
                        tooltip: item.isStarred
                            ? AppStrings.removeFromStarred
                            : AppStrings.addToStarred,
                        iconSize: 22,
                        icon: Icon(
                          item.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                          color: item.isStarred
                              ? Colors.amber.shade700
                              : textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            item.isStarred = !item.isStarred;
                            HistoryStore.update();
                          });
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScanResultScreen(
                              topic: item.topic,
                              variables: item.variables,
                              structuredVariables: item.structuredVariables,
                              targetQuestion: item.targetQuestion,
                              latexFormula: item.latexFormula,
                              notesJson: item.notesJson,
                              imagePath: item.imagePath,
                              historyItem: item,
                              isDegraded: false,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

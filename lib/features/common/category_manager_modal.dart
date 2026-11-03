import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/category_dao.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../main.dart';

class CategoryManagerModal extends ConsumerStatefulWidget {
  final String type; // 'live', 'movie', 'series'

  const CategoryManagerModal({
    super.key,
    required this.type,
  });

  @override
  ConsumerState<CategoryManagerModal> createState() => _CategoryManagerModalState();
}

class _CategoryManagerModalState extends ConsumerState<CategoryManagerModal> {
  int? _movingIndex;
  List<CategoryWithPref>? _localCategories;
  final ScrollController _scrollController = ScrollController();
  final Map<String, FocusNode> _itemFocusNodes = {};

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _itemFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onReorder(int oldIndex, int newIndex) async {
    final account = ref.read(activeAccountProvider);
    if (account == null || _localCategories == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _localCategories!.removeAt(oldIndex);
      _localCategories!.insert(newIndex, item);
      if (_movingIndex != null) {
        _movingIndex = newIndex;
      }
    });

    final orderedIds = _localCategories!.map((c) => c.category.categoryId).toList();
    await ref.read(categoryPreferenceDaoProvider).updateSortOrders(
          account.id,
          widget.type,
          orderedIds,
        );
  }

  void _toggleVisibility(CategoryWithPref item) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final newHidden = !item.isHidden;
    setState(() {
      if (_localCategories != null) {
        final idx = _localCategories!.indexWhere((c) => c.category.categoryId == item.category.categoryId);
        if (idx != -1) {
          _localCategories![idx] = CategoryWithPref(
            category: item.category,
            isHidden: newHidden,
            sortOrder: item.sortOrder,
            isNew: item.isNew,
          );
        }
      }
    });

    await ref.read(categoryPreferenceDaoProvider).setVisibility(
          account.id,
          item.category.categoryId,
          widget.type,
          newHidden,
        );
  }

  void _unhideAll() async {
    final account = ref.read(activeAccountProvider);
    if (account == null || _localCategories == null) return;

    final toUnhide = _localCategories!.where((c) => c.isHidden).toList();
    setState(() {
      _localCategories = _localCategories!.map((c) => CategoryWithPref(
        category: c.category,
        isHidden: false,
        sortOrder: c.sortOrder,
        isNew: c.isNew,
      )).toList();
    });

    final prefDao = ref.read(categoryPreferenceDaoProvider);
    for (final item in toUnhide) {
      await prefDao.setVisibility(account.id, item.category.categoryId, widget.type, false);
    }
  }

  void _resetOrder() async {
    final account = ref.read(activeAccountProvider);
    if (account == null || _localCategories == null) return;

    await ref.read(categoryPreferenceDaoProvider).resetToDefault(account.id, widget.type);

    final fav = _localCategories!.where((c) => c.category.categoryId == 'favorites').toList();
    final custom = _localCategories!.where((c) => c.category.categoryId.startsWith('custom_list:')).toList();
    final provider = _localCategories!.where((c) => c.category.categoryId != 'favorites' && !c.category.categoryId.startsWith('custom_list:')).toList()
      ..sort((a, b) => a.category.name.toLowerCase().compareTo(b.category.name.toLowerCase()));

    final resetList = [...fav, ...custom, ...provider];
    final orderedIds = resetList.map((c) => c.category.categoryId).toList();
    await ref.read(categoryPreferenceDaoProvider).updateSortOrders(account.id, widget.type, orderedIds);

    setState(() {
      _localCategories = resetList;
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();

    final categoriesAsync = ref.watch(managedCategoriesProvider(widget.type));

    final title = widget.type == 'live'
        ? 'Live TV Kategorien verwalten'
        : widget.type == 'movie'
            ? 'Film-Kategorien verwalten'
            : 'Serien-Kategorien verwalten';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: GoatPlatform.isTv ? 40 : 20,
        vertical: GoatPlatform.isTv ? 24 : 32,
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFF161026),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 36,
              spreadRadius: 6,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFFB388FF), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),

            // Action Bar (Unhide all / Reset)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TvFocusable(
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _unhideAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded, size: 14, color: Color(0xFFB388FF)),
                          SizedBox(width: 6),
                          Text('Alle einblenden', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _resetOrder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort_by_alpha_rounded, size: 14, color: Colors.white54),
                          SizedBox(width: 6),
                          Text('A-Z Zurücksetzen', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_movingIndex != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 14, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            'Verschiebemodus aktiv (▲/▼)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),

            // List of Categories
            Expanded(
              child: categoriesAsync.when(
                loading: () => _localCategories != null && _localCategories!.isNotEmpty
                    ? _buildListView()
                    : const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Text('Fehler: $e', style: const TextStyle(color: Colors.white54)),
                ),
                data: (data) {
                  if (_localCategories == null || _localCategories!.length != data.length) {
                    _localCategories = List.from(data);
                  } else if (_movingIndex == null) {
                    _localCategories = List.from(data);
                  }

                  if (_localCategories!.isEmpty) {
                    return const Center(
                      child: Text('Keine Kategorien vorhanden', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return _buildListView();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      scrollController: _scrollController,
      itemCount: _localCategories!.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final item = _localCategories![index];
        final isMoving = _movingIndex == index;
        final isFavorites = item.category.categoryId == 'favorites';
        final isCustomList = item.category.categoryId.startsWith('custom_list:');
        final node = _itemFocusNodes.putIfAbsent(
          item.category.categoryId,
          () => FocusNode(debugLabel: 'cat_mgr_${item.category.categoryId}'),
        );

        return Material(
          key: ValueKey('item_${item.category.categoryId}'),
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: TvFocusable(
              focusNode: node,
              borderRadius: BorderRadius.circular(10),
              onPressed: () {
                if (_movingIndex != null) {
                  setState(() => _movingIndex = null);
                } else {
                  _toggleVisibility(item);
                }
              },
              onKeyEvent: (fNode, event) {
                if (event is KeyDownEvent || event is KeyRepeatEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    // Normal click handled by onPressed
                  } else if (_movingIndex != null) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp && index > 0) {
                      _onReorder(index, index - 1);
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                        index < _localCategories!.length - 1) {
                      _onReorder(index, index + 2);
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                        event.logicalKey == LogicalKeyboardKey.goBack) {
                      setState(() => _movingIndex = null);
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMoving
                      ? Colors.amber.withValues(alpha: 0.15)
                      : item.isHidden
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMoving
                        ? Colors.amber
                        : item.isHidden
                            ? Colors.transparent
                            : const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    width: isMoving ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Dynamic Checkbox Icon
                    GestureDetector(
                      onTap: () => _toggleVisibility(item),
                      child: Icon(
                        item.isHidden
                            ? Icons.check_box_outline_blank_rounded
                            : Icons.check_box_rounded,
                        size: 22,
                        color: item.isHidden ? Colors.white30 : const Color(0xFFB388FF),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Distinct Icon for Favorites / Custom Lists
                    if (isFavorites)
                      const Icon(Icons.star_rounded, size: 20, color: Colors.amber)
                    else if (isCustomList)
                      const Icon(Icons.playlist_play_rounded, size: 20, color: Color(0xFFB388FF)),
                    if (isFavorites || isCustomList)
                      const SizedBox(width: 8),

                    // Category Name
                    Expanded(
                      child: Text(
                        item.category.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: item.isHidden ? FontWeight.normal : FontWeight.w600,
                          color: item.isHidden ? Colors.white38 : Colors.white,
                          decoration: item.isHidden ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Badge for Custom List
                    if (isCustomList) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFB388FF), width: 0.8),
                        ),
                        child: const Text(
                          'LISTE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB388FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // NEU Badge
                    if (item.isNew) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber, width: 0.8),
                        ),
                        child: const Text(
                          'NEU',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Move mode button for TV
                    if (GoatPlatform.isTv) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _movingIndex = (_movingIndex == index) ? null : index;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isMoving
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isMoving ? 'Fertig' : 'Verschieben',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isMoving ? Colors.black : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Single subtle Drag handle for mouse/touch
                    ReorderableDragStartListener(
                      index: index,
                      child: const MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.drag_handle_rounded, size: 20, color: Colors.white38),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

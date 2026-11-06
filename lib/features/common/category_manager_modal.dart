import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
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
          sortOrder: item.sortOrder,
        );
  }

  void _hideAll() async {
    final account = ref.read(activeAccountProvider);
    if (account == null || _localCategories == null) return;

    final updated = _localCategories!.map((c) => CategoryWithPref(
      category: c.category,
      isHidden: true,
      sortOrder: c.sortOrder,
      isNew: c.isNew,
    )).toList();

    setState(() {
      _localCategories = updated;
    });

    await ref.read(categoryPreferenceDaoProvider).setAllVisibility(
      account.id,
      widget.type,
      updated,
      true,
    );
  }

  void _unhideAll() async {
    final account = ref.read(activeAccountProvider);
    if (account == null || _localCategories == null) return;

    final updated = _localCategories!.map((c) => CategoryWithPref(
      category: c.category,
      isHidden: false,
      sortOrder: c.sortOrder,
      isNew: c.isNew,
    )).toList();

    setState(() {
      _localCategories = updated;
    });

    await ref.read(categoryPreferenceDaoProvider).setAllVisibility(
      account.id,
      widget.type,
      updated,
      false,
    );
  }

  void _resetOrder() async {
    final account = ref.read(activeAccountProvider);
    if (account == null || _localCategories == null) return;

    final fav = _localCategories!.where((c) => c.category.categoryId == 'favorites').toList();
    final custom = _localCategories!.where((c) => c.category.categoryId.startsWith('custom_list:')).toList();
    final provider = _localCategories!.where((c) => c.category.categoryId != 'favorites' && !c.category.categoryId.startsWith('custom_list:')).toList()
      ..sort((a, b) => a.category.name.toLowerCase().compareTo(b.category.name.toLowerCase()));

    final resetList = [...fav, ...custom, ...provider];
    final orderedIds = resetList.map((c) => c.category.categoryId).toList();

    setState(() {
      _localCategories = resetList;
    });

    await ref.read(categoryPreferenceDaoProvider).updateSortOrders(account.id, widget.type, orderedIds);
  }

  void _showRenameDialog(CategoryWithPref item, bool isDe) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final listId = int.tryParse(item.category.categoryId.replaceFirst('custom_list:', ''));
    if (listId == null) return;

    final controller = TextEditingController(text: item.category.name);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161026),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFB388FF).withValues(alpha: 0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: Color(0xFFB388FF), size: 22),
            const SizedBox(width: 10),
            Text(
              isDe ? 'Liste umbenennen' : 'Rename List',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: isDe ? 'Listenname...' : 'List name...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFB388FF), width: 1.5),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (isDe ? 'Name darf nicht leer sein' : 'Name cannot be empty')
                : null,
            onFieldSubmitted: (v) {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(v.trim());
              }
            },
          ),
        ),
        actions: [
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(isDe ? 'Abbrechen' : 'Cancel', style: const TextStyle(color: Colors.white60)),
            ),
          ),
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDe ? 'Speichern' : 'Save',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && mounted) {
      await ref.read(customListDaoProvider).renameList(listId, updated);
      setState(() {
        if (_localCategories != null) {
          final idx = _localCategories!.indexWhere((c) => c.category.categoryId == item.category.categoryId);
          if (idx != -1) {
            final old = _localCategories![idx];
            _localCategories![idx] = CategoryWithPref(
              category: Category(
                id: old.category.id,
                accountId: old.category.accountId,
                categoryId: old.category.categoryId,
                name: updated,
                type: old.category.type,
              ),
              isHidden: old.isHidden,
              sortOrder: old.sortOrder,
              isNew: old.isNew,
            );
          }
        }
      });
    }
  }

  void _showDeleteDialog(CategoryWithPref item, bool isDe) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;
    final listId = int.tryParse(item.category.categoryId.replaceFirst('custom_list:', ''));
    if (listId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161026),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 10),
            Text(
              isDe ? 'Liste löschen' : 'Delete List',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          isDe
              ? 'Möchtest du die Liste "${item.category.name}" wirklich löschen?\nEnthaltene Einträge bleiben erhalten.'
              : 'Do you really want to delete the list "${item.category.name}"?\nContained streams will not be deleted.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(isDe ? 'Abbrechen' : 'Cancel', style: const TextStyle(color: Colors.white60)),
            ),
          ),
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDe ? 'Löschen' : 'Delete',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(customListDaoProvider).deleteList(listId);
      await ref.read(categoryPreferenceDaoProvider).deletePreference(account.id, item.category.categoryId, widget.type);
      setState(() {
        if (_localCategories != null) {
          _localCategories!.removeWhere((c) => c.category.categoryId == item.category.categoryId);
        }
      });
    }
  }

  void _showTvCustomListMenu(CategoryWithPref item, int index, bool isDe) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF161026),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFB388FF).withValues(alpha: 0.5), width: 1.5),
        ),
        title: Text(
          item.category.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('move'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.swap_vert_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  Text(isDe ? 'Reihenfolge verschieben' : 'Reorder / Move', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('rename'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFFB388FF), size: 20),
                  const SizedBox(width: 12),
                  Text(isDe ? 'Liste umbenennen' : 'Rename list', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Text(isDe ? 'Liste löschen' : 'Delete list', style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (action == 'move') {
      setState(() => _movingIndex = index);
    } else if (action == 'rename') {
      _showRenameDialog(item, isDe);
    } else if (action == 'delete') {
      _showDeleteDialog(item, isDe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();

    final categoriesAsync = ref.watch(managedCategoriesProvider(widget.type));

    final initialData = categoriesAsync.asData?.value;
    if (initialData != null) {
      if (_localCategories == null || _localCategories!.length != initialData.length) {
        _localCategories = List.from(initialData);
      }
    }

    final currentList = _localCategories ?? initialData ?? const <CategoryWithPref>[];
    final allVisible = currentList.isNotEmpty && currentList.every((c) => !c.isHidden);

    final isDe = Localizations.localeOf(context).languageCode == 'de';

    final title = widget.type == 'live'
        ? (isDe ? 'Live TV Kategorien verwalten' : 'Manage Live TV Categories')
        : widget.type == 'movie'
            ? (isDe ? 'Film-Kategorien verwalten' : 'Manage Movie Categories')
            : (isDe ? 'Serien-Kategorien verwalten' : 'Manage Series Categories');

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
          border: Border.all(color: const Color(0xFFB388FF).withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0x33B388FF),
              blurRadius: 20,
              spreadRadius: 1,
            ),
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
                    autofocus: true,
                    borderRadius: BorderRadius.circular(8),
                    onPressed: allVisible ? _hideAll : _unhideAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            allVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 14,
                            color: const Color(0xFFB388FF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            allVisible ? (isDe ? 'Alle ausblenden' : 'Hide All') : (isDe ? 'Alle einblenden' : 'Show All'),
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_by_alpha_rounded, size: 14, color: Colors.white54),
                          const SizedBox(width: 6),
                          Text(isDe ? 'A-Z Zurücksetzen' : 'Reset A-Z', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (GoatPlatform.isTv && _movingIndex != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swap_vert_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            isDe ? 'Verschiebemodus aktiv (▲/▼)' : 'Move mode active (▲/▼)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (GoatPlatform.isTv) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFFB388FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDe
                            ? 'Tipp: OK gedrückt halten = Verschieben / Listen bearbeiten'
                            : 'Tip: Hold OK = Reorder / Edit list options',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 1, color: Colors.white10),

            // List of Categories
            Expanded(
              child: categoriesAsync.when(
                loading: () => _localCategories != null && _localCategories!.isNotEmpty
                    ? _buildListView(isDe)
                    : const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(
                  child: Text(isDe ? 'Fehler: $e' : 'Error: $e', style: const TextStyle(color: Colors.white54)),
                ),
                data: (data) {
                  if (_localCategories == null || _localCategories!.length != data.length) {
                    _localCategories = List.from(data);
                  }

                  if (_localCategories!.isEmpty) {
                    return Center(
                      child: Text(
                        isDe ? 'Keine Kategorien vorhanden' : 'No categories available',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return _buildListView(isDe);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(bool isDe) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      scrollController: _scrollController,
      itemCount: _localCategories!.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final item = _localCategories![index];
        final isMoving = GoatPlatform.isTv && _movingIndex == index;
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
                if (GoatPlatform.isTv && _movingIndex != null) {
                  setState(() => _movingIndex = null);
                } else {
                  _toggleVisibility(item);
                }
              },
              onLongPress: GoatPlatform.isTv
                  ? () {
                      if (isCustomList) {
                        _showTvCustomListMenu(item, index, isDe);
                      } else {
                        setState(() => _movingIndex = (_movingIndex == index) ? null : index);
                      }
                    }
                  : null,
              onKeyEvent: (fNode, event) {
                if (GoatPlatform.isTv && (event is KeyDownEvent || event is KeyRepeatEvent)) {
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

                    // Badge & Actions for Custom List
                    if (isCustomList) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFB388FF), width: 0.8),
                        ),
                        child: Text(
                          isDe ? 'LISTE' : 'LIST',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB388FF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Rename & Delete buttons (Mobile & Desktop)
                      if (!GoatPlatform.isTv) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFB388FF)),
                          tooltip: isDe ? 'Umbenennen' : 'Rename',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () => _showRenameDialog(item, isDe),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                          tooltip: isDe ? 'Löschen' : 'Delete',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          onPressed: () => _showDeleteDialog(item, isDe),
                        ),
                      ],
                      const SizedBox(width: 4),
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
                        child: Text(
                          isDe ? 'NEU' : 'NEW',
                          style: const TextStyle(
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
                      TvFocusable(
                        borderRadius: BorderRadius.circular(6),
                        onPressed: () {
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
                            isMoving ? (isDe ? 'Fertig' : 'Done') : (isDe ? 'Verschieben' : 'Move'),
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

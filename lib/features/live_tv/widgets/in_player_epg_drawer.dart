import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/channel_name_cleaner.dart';
import '../../../core/utils/live_stream_matcher.dart';
import '../epg_controller.dart';
import 'channel_icon.dart';

class InPlayerEpgDrawer extends ConsumerStatefulWidget {
  final List<StreamItem> streams;
  final String? currentStreamId;
  final ValueChanged<StreamItem> onSelectStream;
  final VoidCallback onClose;
  final String? categoryName;
  final bool isOpen;

  const InPlayerEpgDrawer({
    super.key,
    required this.streams,
    this.currentStreamId,
    required this.onSelectStream,
    required this.onClose,
    this.categoryName,
    this.isOpen = false,
  });

  @override
  ConsumerState<InPlayerEpgDrawer> createState() => _InPlayerEpgDrawerState();
}

class _InPlayerEpgDrawerState extends ConsumerState<InPlayerEpgDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

  void _scrollToCurrentChannel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.currentStreamId != null && widget.streams.isNotEmpty) {
        final idx = LiveStreamMatcher.indexOf(
          widget.streams,
          streamId: widget.currentStreamId,
          channelId: widget.currentStreamId,
        );
        if (idx > 3 && _scrollController.hasClients) {
          _scrollController.jumpTo((idx - 2) * 68.0);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollToCurrentChannel();
  }

  @override
  void didUpdateWidget(covariant InPlayerEpgDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen && !widget.isOpen) {
      // Clear search query and text controller when drawer closes
      _searchController.clear();
      setState(() {
        _searchQuery = '';
      });
    } else if (!oldWidget.isOpen && widget.isOpen) {
      _scrollToCurrentChannel();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentPrograms = ref.watch(currentProgramsMapProvider).asData?.value ?? const {};
    final now = DateTime.now();

    var filteredStreams = widget.streams;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filteredStreams = filteredStreams.where((s) => s.name.toLowerCase().contains(q)).toList();
    }

    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 350,
          color: const Color(0xE814141E), // Deep frosted glass slate
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Category Title + Channel count + Close
              Container(
                padding: const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.format_list_bulleted, color: Colors.white70, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.categoryName ?? (l10n?.epgDrawer ?? 'Channel List & EPG'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                          Text(
                            '${widget.streams.length} Sender',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      tooltip: l10n?.close ?? 'Close',
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l10n?.search ?? 'Search channels...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

              // Channels List
              Expanded(
                child: filteredStreams.isEmpty
                    ? Center(
                        child: Text(
                          l10n?.noResultsFound ?? 'No channels found',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredStreams.length,
                        itemExtent: 68.0,
                        itemBuilder: (context, index) {
                          final stream = filteredStreams[index];
                          final cleanName = ChannelNameCleaner.clean(stream.name);
                          final isSelected = stream.streamId == widget.currentStreamId;
                          final epgId = stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty
                              ? stream.epgChannelId
                              : stream.streamId;
                          final program = epgId != null ? currentPrograms[epgId] : null;

                          double? progress;
                          String? timeString;
                          if (program != null) {
                            final total = program.stopTime.difference(program.startTime).inMinutes;
                            final elapsed = now.difference(program.startTime).inMinutes;
                            if (total > 0) {
                              progress = (elapsed / total).clamp(0.0, 1.0);
                            }
                            timeString = '${_formatTime(program.startTime)} - ${_formatTime(program.stopTime)}';
                          }

                          return Material(
                            color: isSelected ? Colors.deepPurple.withValues(alpha: 0.35) : Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onSelectStream(stream),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: isSelected ? Colors.purpleAccent : Colors.transparent,
                                      width: 4,
                                    ),
                                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ChannelIcon(iconUrl: stream.streamIcon, channelName: cleanName, size: 38),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cleanName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? Colors.purpleAccent : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if (program != null) ...[
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    program.title,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                                  ),
                                                ),
                                                if (timeString != null)
                                                  Text(
                                                    timeString,
                                                    style: const TextStyle(fontSize: 9, color: Colors.white38),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            if (progress != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(2),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  minHeight: 2.5,
                                                  backgroundColor: Colors.white12,
                                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                                ),
                                              ),
                                          ] else ...[
                                            Text(
                                              l10n?.noProgramInfo ?? 'No program info',
                                              style: const TextStyle(fontSize: 10, color: Colors.white30),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.play_arrow, color: Colors.purpleAccent, size: 18),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating On-Screen Display (OSD) banner showing channel & show info on zap
class InPlayerOsdBanner extends StatelessWidget {
  final StreamItem stream;
  final EpgProgram? currentProgram;
  final EpgProgram? nextProgram;
  final int channelNumber;
  final bool isCompact;

  const InPlayerOsdBanner({
    super.key,
    required this.stream,
    this.currentProgram,
    this.nextProgram,
    required this.channelNumber,
    this.isCompact = false,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final cleanName = ChannelNameCleaner.clean(stream.name);
    final now = DateTime.now();

    double? progress;
    String? timeRange;
    if (currentProgram != null) {
      final total = currentProgram!.stopTime.difference(currentProgram!.startTime).inMinutes;
      final elapsed = now.difference(currentProgram!.startTime).inMinutes;
      if (total > 0) progress = (elapsed / total).clamp(0.0, 1.0);
      timeRange = '${_formatTime(currentProgram!.startTime)} - ${_formatTime(currentProgram!.stopTime)}';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(isCompact ? 10 : 14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: isCompact ? null : 520,
          constraints: isCompact ? const BoxConstraints(maxWidth: 340) : null,
          padding: isCompact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xE614141E),
            borderRadius: BorderRadius.circular(isCompact ? 10 : 14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Channel Logo
              ChannelIcon(iconUrl: stream.streamIcon, channelName: cleanName, size: isCompact ? 30 : 52),
              SizedBox(width: isCompact ? 8 : 14),

              // Channel Info & EPG
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel Number & Name
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 4 : 6,
                            vertical: isCompact ? 1 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(isCompact ? 3 : 4),
                          ),
                          child: Text(
                            '$channelNumber',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 9 : 11,
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 6 : 8),
                        Expanded(
                          child: Text(
                            cleanName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 12 : 16,
                            ),
                          ),
                        ),
                        if (timeRange != null)
                          Text(
                            timeRange,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: isCompact ? 9 : 11,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 2 : 5),

                    // Current Program
                    if (currentProgram != null) ...[
                      Text(
                        currentProgram!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 10 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isCompact ? 2 : 4),
                      if (progress != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: isCompact ? 2.0 : 3.0,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                          ),
                        ),
                    ],

                    // Next Program Preview (Omitted in compact preview mode)
                    if (!isCompact && nextProgram != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Danach: ${nextProgram!.title} (${_formatTime(nextProgram!.startTime)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

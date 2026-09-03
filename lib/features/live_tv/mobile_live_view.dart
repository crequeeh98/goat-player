import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'widgets/video_preview.dart';
import 'widgets/epg_timeline.dart';
import 'widgets/channel_icon.dart';
import 'live_tv_controller.dart';
import 'epg_controller.dart';
import '../../core/utils/channel_name_cleaner.dart';
import '../../main.dart';

class MobileLiveCategoriesScreen extends ConsumerStatefulWidget {
  const MobileLiveCategoriesScreen({super.key});

  @override
  ConsumerState<MobileLiveCategoriesScreen> createState() => _MobileLiveCategoriesScreenState();
}

class _MobileLiveCategoriesScreenState extends ConsumerState<MobileLiveCategoriesScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(liveTvControllerProvider).syncLiveCategories();
      ref.read(epgControllerProvider).syncEpgData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: '${l10n.search} ${l10n.allCategories}',
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
      body: ref.watch(liveCategoriesProvider).when(
        data: (rawCategories) {
          var categories = rawCategories;
          if (_searchQuery.trim().isNotEmpty) {
            categories = categories.where((c) => c.name.toLowerCase().contains(_searchQuery.trim().toLowerCase())).toList();
          }
          if (categories.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.noCategories));

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                title: Text(cat.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.read(liveTvControllerProvider).syncLiveStreams(cat.categoryId);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MobileLiveChannelsScreen(categoryId: cat.categoryId, categoryName: cat.name),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class MobileLiveChannelsScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  
  const MobileLiveChannelsScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  ConsumerState<MobileLiveChannelsScreen> createState() => _MobileLiveChannelsScreenState();
}

class _MobileLiveChannelsScreenState extends ConsumerState<MobileLiveChannelsScreen> {
  String _channelSearchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search channels...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => setState(() => _channelSearchQuery = val),
              )
            : Text(widget.categoryName),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _channelSearchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: ref.watch(liveStreamsProvider(widget.categoryId)).when(
        data: (rawStreams) {
          var streams = rawStreams;
          if (_channelSearchQuery.trim().isNotEmpty) {
            final query = _channelSearchQuery.trim().toLowerCase();
            streams = streams.where((s) => s.name.toLowerCase().contains(query)).toList();
          }

          if (streams.isEmpty) {
            return const Center(child: Text('No channels found'));
          }

          final currentPrograms = ref.watch(currentProgramsMapProvider).asData?.value ?? const {};
          final now = DateTime.now();

          return ListView.builder(
            itemCount: streams.length,
            itemBuilder: (context, index) {
              final stream = streams[index];
              final account = ref.read(activeAccountProvider);
              final cleanName = ChannelNameCleaner.clean(stream.name);
              final epgChannelId = stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId;
              
              final currentProgram = epgChannelId != null ? currentPrograms[epgChannelId] : null;
              String? currentShowTitle;
              double? showProgress;
              
              if (currentProgram != null) {
                currentShowTitle = currentProgram.title;
                final totalMinutes = currentProgram.stopTime.difference(currentProgram.startTime).inMinutes;
                final elapsedMinutes = now.difference(currentProgram.startTime).inMinutes;
                if (totalMinutes > 0) {
                  showProgress = (elapsedMinutes / totalMinutes).clamp(0.0, 1.0);
                }
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: ChannelIcon(
                  iconUrl: stream.streamIcon,
                  channelName: cleanName,
                ),
                title: Text(cleanName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: currentShowTitle != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            currentShowTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                          if (showProgress != null) ...[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: showProgress,
                                minHeight: 3,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ],
                        ],
                      )
                    : null,
                trailing: const Icon(Icons.play_circle_outline, color: Colors.white70),
                onTap: () {
                  final baseUrl = account?.serverUrl.endsWith('/') == true
                      ? account!.serverUrl.substring(0, account.serverUrl.length - 1)
                      : account?.serverUrl;
                  final url = '$baseUrl/live/${account?.username}/${account?.password}/${stream.streamId}.ts';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MobilePlayerScreen(
                        streamUrl: url,
                        channelId: epgChannelId,
                        channelName: cleanName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class MobilePlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String channelName;
  final String? channelId;
  
  const MobilePlayerScreen({super.key, required this.streamUrl, required this.channelName, this.channelId});

  @override
  State<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}

class _MobilePlayerScreenState extends State<MobilePlayerScreen> {
  @override
  void dispose() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (Platform.isAndroid || Platform.isIOS) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.channelName),
        ),
        body: SafeArea(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPreview(
                  streamUrl: widget.streamUrl,
                  channelId: widget.channelId,
                  channelName: widget.channelName,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: EpgTimelineWidget(channelId: widget.channelId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

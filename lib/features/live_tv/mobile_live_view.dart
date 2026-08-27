import 'package:flutter/material.dart';
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

class MobileLiveChannelsScreen extends ConsumerWidget {
  final String categoryId;
  final String categoryName;
  
  const MobileLiveChannelsScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
      ),
      body: ref.watch(liveStreamsProvider(categoryId)).when(
        data: (streams) {
          return ListView.builder(
            itemCount: streams.length,
            itemBuilder: (context, index) {
              final stream = streams[index];
              final account = ref.read(activeAccountProvider);
              final cleanName = ChannelNameCleaner.clean(stream.name);
              return ListTile(
                leading: ChannelIcon(
                  iconUrl: stream.streamIcon,
                  channelName: cleanName,
                ),
                title: Text(cleanName),
                onTap: () {
                  final baseUrl = account?.serverUrl.endsWith('/') == true ? account!.serverUrl.substring(0, account.serverUrl.length - 1) : account?.serverUrl;
                  final url = '$baseUrl/live/${account?.username}/${account?.password}/${stream.streamId}.ts';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MobilePlayerScreen(
                        streamUrl: url,
                        channelId: stream.epgChannelId != null && stream.epgChannelId!.isNotEmpty ? stream.epgChannelId : stream.streamId,
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

class MobilePlayerScreen extends StatelessWidget {
  final String streamUrl;
  final String channelName;
  final String? channelId;
  
  const MobilePlayerScreen({super.key, required this.streamUrl, required this.channelName, this.channelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(channelName),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoPreview(
                streamUrl: streamUrl,
                channelId: channelId,
                channelName: channelName,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: EpgTimelineWidget(channelId: channelId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

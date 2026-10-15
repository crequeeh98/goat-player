import 'package:flutter/material.dart';
import '../app_updater_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final AppUpdaterService updaterService;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updaterService,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    AppUpdaterService? updaterService,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(
        updateInfo: updateInfo,
        updaterService: updaterService ?? AppUpdaterService(),
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      final downloadedPath = await widget.updaterService.downloadUpdate(
        downloadUrl: widget.updateInfo.downloadUrl,
        fileName: widget.updateInfo.fileName,
        onProgress: (p) {
          if (mounted) {
            setState(() => _progress = p);
          }
        },
      );

      if (!mounted) return;

      await widget.updaterService.installUpdate(downloadedPath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Fehler beim Update: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGerman = Localizations.localeOf(context).languageCode == 'de';

    final titleText = isGerman ? 'Update verfügbar' : 'Update Available';
    final installedText = isGerman
        ? 'Installiert: v${widget.updateInfo.currentVersion} → Neu: v${widget.updateInfo.latestVersion}'
        : 'Installed: v${widget.updateInfo.currentVersion} → New: v${widget.updateInfo.latestVersion}';
    final laterText = isGerman ? 'Später' : 'Later';
    final updateNowText = isGerman ? 'Jetzt aktualisieren' : 'Update Now';
    final downloadingText = isGerman ? 'Wird heruntergeladen...' : 'Downloading...';

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.deepPurple.shade700, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.system_update_rounded, color: Colors.deepPurpleAccent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  installedText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              Text(
                isGerman ? 'Neuerungen:' : 'What\'s new:',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.updateInfo.releaseNotes,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_isDownloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    downloadingText,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              laterText,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ElevatedButton.icon(
          onPressed: _isDownloading ? null : _startUpdate,
          icon: _isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(_isDownloading ? downloadingText : updateNowText),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

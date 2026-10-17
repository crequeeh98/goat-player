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

      await widget.updaterService.installUpdate(downloadedPath, widget.updateInfo.latestVersion);
    } catch (e) {
      if (mounted) {
        final isGerman = Localizations.localeOf(context).languageCode == 'de';
        final errStr = e.toString().toLowerCase();
        final String friendlyMsg;
        if (errStr.contains('socket') ||
            errStr.contains('connection') ||
            errStr.contains('timeout') ||
            errStr.contains('network') ||
            errStr.contains('handshake') ||
            errStr.contains('failed host lookup')) {
          friendlyMsg = isGerman
              ? 'Verbindung getrennt. Bitte Internetverbindung prüfen.'
              : 'Connection interrupted. Please check your internet connection.';
        } else {
          friendlyMsg = isGerman
              ? 'Download fehlgeschlagen. Bitte erneut versuchen.'
              : 'Download failed. Please try again.';
        }
        setState(() {
          _isDownloading = false;
          _errorMessage = friendlyMsg;
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
    final updateNowText = _errorMessage != null
        ? (isGerman ? 'Erneut versuchen' : 'Retry')
        : (isGerman ? 'Jetzt aktualisieren' : 'Update Now');
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
                  child: _buildMarkdownContent(widget.updateInfo.releaseNotes),
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
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
              : Icon(_errorMessage != null ? Icons.refresh_rounded : Icons.download_rounded, size: 18),
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

  Widget _buildMarkdownContent(String rawMarkdown) {
    final lines = rawMarkdown.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headers: #, ##, ###
      if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.substring(4).trim(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            line.substring(3).trim(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            line.substring(2).trim(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ));
      } else if (line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ') ||
          line.trimLeft().startsWith('• ')) {
        // Bullet item
        final trimmed = line.trimLeft();
        final content = trimmed.substring(2).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5, right: 8),
                child: Icon(Icons.circle, size: 5, color: Colors.deepPurpleAccent),
              ),
              Expanded(
                child: _buildRichText(content),
              ),
            ],
          ),
        ));
      } else {
        // Normal paragraph line
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildRichText(line),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildRichText(String text) {
    // Parse bold text **bold**
    final spans = <InlineSpan>[];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: isBold ? Colors.white : Colors.white70,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}

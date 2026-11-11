import 'package:flutter/material.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/widgets/tv_focusable.dart';
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

  /// Extracts exclusively the language section corresponding to [isGerman].
  /// Removes the huge redundant section header (e.g. "### 🇩🇪 Änderungen")
  /// so only clean, localized bullet items are returned.
  static String extractLocalizedChangelog(String rawNotes, bool isGerman) {
    if (rawNotes.trim().isEmpty) return '';
    final normalized = rawNotes.replaceAll('\r\n', '\n');

    final deRegex = RegExp(
      r'(?:^|\n)#{1,4}\s*(?:🇩🇪|[🇩][🇪]|.*[Ää]nderungen|.*Neuerungen|.*German)',
      caseSensitive: false,
    );
    final enRegex = RegExp(
      r'(?:^|\n)#{1,4}\s*(?:🇬🇧|[🇬][🇧]|.*Changes|.*English)',
      caseSensitive: false,
    );

    final deMatch = deRegex.firstMatch(normalized);
    final enMatch = enRegex.firstMatch(normalized);

    if (deMatch != null && enMatch != null) {
      if (isGerman) {
        final start = deMatch.end;
        final end = enMatch.start > start ? enMatch.start : normalized.length;
        return _cleanSection(normalized.substring(start, end));
      } else {
        final start = enMatch.end;
        final nextHeader = RegExp(r'\n---|\n#{1,3}\s+').firstMatch(normalized.substring(start));
        final end = nextHeader != null ? start + nextHeader.start : normalized.length;
        return _cleanSection(normalized.substring(start, end));
      }
    } else if (deMatch != null && isGerman) {
      final start = deMatch.end;
      final nextHeader = RegExp(r'\n---|\n#{1,3}\s+').firstMatch(normalized.substring(start));
      final end = nextHeader != null ? start + nextHeader.start : normalized.length;
      return _cleanSection(normalized.substring(start, end));
    } else if (enMatch != null && !isGerman) {
      final start = enMatch.end;
      final nextHeader = RegExp(r'\n---|\n#{1,3}\s+').firstMatch(normalized.substring(start));
      final end = nextHeader != null ? start + nextHeader.start : normalized.length;
      return _cleanSection(normalized.substring(start, end));
    }

    return _cleanSection(rawNotes);
  }

  static String _cleanSection(String text) {
    var cleaned = text.trim();
    // Strip leading newlines, horizontal rules (---) or header markers (#)
    cleaned = cleaned.replaceFirst(RegExp(r'^(?:[\r\n\s]|---+|#{1,4}\s*)+'), '');
    return cleaned.trim();
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _updateBtnFocusNode = FocusNode(debugLabel: 'update_dialog_update_btn');
  final FocusNode _laterBtnFocusNode = FocusNode(debugLabel: 'update_dialog_later_btn');

  @override
  void dispose() {
    _scrollController.dispose();
    _updateBtnFocusNode.dispose();
    _laterBtnFocusNode.dispose();
    super.dispose();
  }

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
        expectedSha256: widget.updateInfo.expectedSha256,
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
        if (errStr.contains('integrity') || errStr.contains('sha-256') || errStr.contains('untrusted')) {
          friendlyMsg = isGerman
              ? 'Sicherheitsprüfung fehlgeschlagen (Prüfsumme ungültig).'
              : 'Security verification failed (checksum mismatch).';
        } else if (errStr.contains('socket') ||
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

    final localizedNotes = UpdateDialog.extractLocalizedChangelog(widget.updateInfo.releaseNotes, isGerman);

    // Responsive dialog & changelog container sizing
    final double dialogWidth = GoatPlatform.isTv ? 620 : (GoatPlatform.isPhone ? double.infinity : 520);
    final double maxChangelogHeight = GoatPlatform.isTv ? 340 : (GoatPlatform.isPhone ? 240 : 300);

    return AlertDialog(
      backgroundColor: const Color(0xFF161026),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFB388FF).withValues(alpha: 0.5), width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded, color: Color(0xFFB388FF), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFB388FF).withValues(alpha: 0.6), width: 1),
                      ),
                      child: Text(
                        'v${widget.updateInfo.latestVersion}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD8B4FE),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  installedText,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (localizedNotes.isNotEmpty) ...[
              Container(
                constraints: BoxConstraints(maxHeight: maxChangelogHeight),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: !GoatPlatform.isPhone,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: _buildMarkdownContent(localizedNotes, isGerman),
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                      color: Color(0xFFB388FF),
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (!_isDownloading)
          TvFocusable(
            focusNode: _laterBtnFocusNode,
            borderRadius: BorderRadius.circular(8),
            onPressed: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                laterText,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ),
          ),
        TvFocusable(
          focusNode: _updateBtnFocusNode,
          autofocus: GoatPlatform.isTv,
          borderRadius: BorderRadius.circular(8),
          onPressed: _isDownloading ? null : _startUpdate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isDownloading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(
                    _errorMessage != null ? Icons.refresh_rounded : Icons.download_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isDownloading ? downloadingText : updateNowText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownContent(String rawMarkdown, bool isGerman) {
    final lines = rawMarkdown.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 3));
        continue;
      }

      // Check for bullet items
      final isSubBullet = line.startsWith('   - ') ||
          line.startsWith('  - ') ||
          line.startsWith('\t- ') ||
          line.startsWith('   * ') ||
          line.startsWith('  * ');
      final isBullet = isSubBullet ||
          line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ') ||
          line.trimLeft().startsWith('• ');

      if (isBullet) {
        final content = line.trimLeft().substring(2).trim();
        widgets.add(Padding(
          padding: EdgeInsets.only(
            left: isSubBullet ? 14 : 2,
            top: isSubBullet ? 1.5 : 3.0,
            bottom: isSubBullet ? 1.5 : 2.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5.0, right: 6),
                child: Icon(
                  isSubBullet ? Icons.arrow_right_rounded : Icons.circle,
                  size: isSubBullet ? 12 : 5,
                  color: isSubBullet ? const Color(0xFFB388FF) : const Color(0xFF9333EA),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _parseSpans(content)),
                ),
              ),
            ],
          ),
        ));
      } else if (line.startsWith('### ') || line.startsWith('## ') || line.startsWith('# ')) {
        final title = line.replaceFirst(RegExp(r'^#{1,3}\s*'), '').trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB388FF),
              letterSpacing: 0.3,
            ),
          ),
        ));
      } else {
        // Normal text line
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text.rich(
            TextSpan(children: _parseSpans(line.trim())),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  static List<InlineSpan> _parseSpans(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*.*?\*\*|\*.*?\*|`.*?`)');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: Color(0xDDFFFFFF),
          ),
        ));
      }
      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**') && matchedText.length >= 4) {
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ));
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*') && matchedText.length >= 2) {
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.35,
            fontStyle: FontStyle.italic,
            color: Color(0xCCFFFFFF),
          ),
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`') && matchedText.length >= 2) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFB388FF).withValues(alpha: 0.4), width: 0.8),
            ),
            child: Text(
              matchedText.substring(1, matchedText.length - 1),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFD8B4FE),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: Color(0xDDFFFFFF),
        ),
      ));
    }

    return spans;
  }
}

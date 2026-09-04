import 'package:flutter/material.dart';

class ChannelIcon extends StatelessWidget {
  final String? iconUrl;
  final String channelName;
  final double size;

  const ChannelIcon({
    super.key,
    this.iconUrl,
    required this.channelName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (iconUrl != null && iconUrl!.isNotEmpty) {
      final cachePx = (size * 2).round().clamp(64, 160);
      return Image.network(
        iconUrl!,
        width: size,
        height: size,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    final initials = _getInitials(channelName);
    
    // Generate a consistent vibrant color based on the channel name
    final hash = channelName.hashCode;
    final color1 = HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.7, 0.5).toColor();
    final color2 = HSLColor.fromAHSL(1.0, ((hash + 40) % 360).toDouble(), 0.8, 0.4).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
          letterSpacing: 1,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'TV';
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TV';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    // Take first two words
    String first = words[0][0];
    String second = words[1][0];
    // If it's a number like "1", take it
    return '$first$second'.toUpperCase();
  }
}

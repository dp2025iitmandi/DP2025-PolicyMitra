import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/enhanced_video_player_widget.dart';

class VideoPage extends StatefulWidget {
  final String videoUrl;
  final String policyTitle;

  const VideoPage({
    Key? key,
    required this.videoUrl,
    required this.policyTitle,
  }) : super(key: key);

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.policyTitle,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Exit Video',
          ),
        ],
      ),
      body: Center(
        child: EnhancedVideoPlayerWidget(
          videoUrl: widget.videoUrl,
          autoPlay: true,
          isFullscreen: true,
          onFullscreenToggle: null, // Remove callback to prevent exiting
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final bool isFullscreen;
  final VoidCallback? onFullscreenToggle;
  final double? width;
  final double? height;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.showControls = true,
    this.isFullscreen = false,
    this.onFullscreenToggle,
    this.width,
    this.height,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      debugPrint('Initializing video_player with URL: ${widget.videoUrl}');
      
      // Create video player controller
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      
      // Initialize video player
      await _videoPlayerController!.initialize();
      
      // Set video properties
      await _videoPlayerController!.setVolume(1.0);
      await _videoPlayerController!.setLooping(false);
      
      // Add listener for playing state
      _videoPlayerController!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _videoPlayerController!.value.isPlaying;
          });
        }
      });
      
      // Auto play if requested
      if (widget.autoPlay) {
        await _videoPlayerController!.play();
      }
      
      debugPrint('Video player initialized successfully');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Calculate optimal video dimensions based on screen size
    double videoWidth = widget.width ?? screenWidth;
    double videoHeight = widget.height ?? (screenHeight * 0.4); // 40% of screen height for better visibility
    
    if (!_isInitialized || _videoPlayerController == null) {
      return Container(
        width: videoWidth,
        height: videoHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        width: videoWidth,
        height: videoHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Fill container with BoxFit.cover to avoid black bars
                SizedBox(
                  width: videoWidth,
                  height: videoHeight,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoPlayerController!.value.size.width,
                      height: _videoPlayerController!.value.size.height,
                      child: VideoPlayer(_videoPlayerController!),
                    ),
                  ),
                ),
              if (widget.showControls && _showControls)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Top controls
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.onFullscreenToggle != null)
                                IconButton(
                                  onPressed: widget.onFullscreenToggle,
                                  icon: const Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Bottom controls
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              // Progress bar
                              VideoProgressIndicator(
                                _videoPlayerController!,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.red,
                                  backgroundColor: Colors.white24,
                                  bufferedColor: Colors.white38,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Control buttons
                              Row(
                                children: [
                                  // Play/Pause button
                                  IconButton(
                                    onPressed: () {
                                      if (_isPlaying) {
                                        _videoPlayerController!.pause();
                                      } else {
                                        _videoPlayerController!.play();
                                      }
                                    },
                                    icon: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Current time
                                  Text(
                                    _formatDuration(_videoPlayerController!.value.position),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Text(
                                    ' / ',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  // Total duration
                                  Text(
                                    _formatDuration(_videoPlayerController!.value.duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Volume button
                                  IconButton(
                                    onPressed: () {
                                      final currentVolume = _videoPlayerController!.value.volume;
                                      _videoPlayerController!.setVolume(
                                        currentVolume > 0 ? 0.0 : 1.0,
                                      );
                                    },
                                    icon: Icon(
                                      _videoPlayerController!.value.volume > 0
                                          ? Icons.volume_up
                                          : Icons.volume_off,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
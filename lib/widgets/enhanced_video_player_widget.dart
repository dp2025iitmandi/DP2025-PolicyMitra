import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class EnhancedVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool isFullscreen;
  final VoidCallback? onFullscreenToggle;
  final double? width;
  final double? height;

  const EnhancedVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.isFullscreen = false,
    this.onFullscreenToggle,
    this.width,
    this.height,
  });

  @override
  State<EnhancedVideoPlayerWidget> createState() => _EnhancedVideoPlayerWidgetState();
}

class _EnhancedVideoPlayerWidgetState extends State<EnhancedVideoPlayerWidget> {
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild when orientation changes
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeVideo() async {
    try {
      debugPrint('Initializing enhanced video_player with URL: ${widget.videoUrl}');
      
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.setVolume(1.0);
      await _videoPlayerController!.setLooping(false);
      
      _videoPlayerController!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _videoPlayerController!.value.isPlaying;
            _volume = _videoPlayerController!.value.volume;
            _isMuted = _volume == 0.0;
          });
        }
      });
      
      if (widget.autoPlay) {
        await _videoPlayerController!.play();
      }
      
      debugPrint('Enhanced video player initialized successfully');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing enhanced video player: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    // Reset orientation when disposing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _videoPlayerController?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _videoPlayerController!.pause();
    } else {
      _videoPlayerController!.play();
    }
  }

  void _seekForward() {
    final currentPosition = _videoPlayerController!.value.position;
    final newPosition = currentPosition + const Duration(seconds: 5);
    final duration = _videoPlayerController!.value.duration;
    
    if (newPosition < duration) {
      _videoPlayerController!.seekTo(newPosition);
    } else {
      _videoPlayerController!.seekTo(duration);
    }
  }

  void _seekBackward() {
    final currentPosition = _videoPlayerController!.value.position;
    final newPosition = currentPosition - const Duration(seconds: 5);
    
    if (newPosition > Duration.zero) {
      _videoPlayerController!.seekTo(newPosition);
    } else {
      _videoPlayerController!.seekTo(Duration.zero);
    }
  }

  void _toggleMute() {
    if (_isMuted) {
      _videoPlayerController!.setVolume(1.0);
    } else {
      _videoPlayerController!.setVolume(0.0);
    }
  }

  void _setVolume(double volume) {
    _videoPlayerController!.setVolume(volume);
  }

  void _toggleFullscreen() async {
    if (_isFullscreen) {
      // Exit fullscreen - return to portrait
      setState(() {
        _isFullscreen = false;
      });
      
      // Reset orientation and UI mode
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      
      // Don't call parent callback - just stay in the same screen
    } else {
      // Enter fullscreen - lock to landscape
      setState(() {
        _isFullscreen = true;
      });
      
      // Use Future.microtask to ensure state update happens first
      Future.microtask(() async {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Calculate video dimensions based on orientation
    double videoWidth, videoHeight;
    
    if (_isFullscreen) {
      // In fullscreen landscape mode, use entire screen
      videoWidth = screenWidth;
      videoHeight = screenHeight;
    } else {
      // In normal mode, use provided dimensions or default
      videoWidth = widget.width ?? screenWidth;
      videoHeight = widget.height ?? (screenHeight * 0.4);
    }
    
    if (!_isInitialized || _videoPlayerController == null) {
      return Container(
        width: videoWidth,
        height: videoHeight,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: _isFullscreen ? BorderRadius.zero : BorderRadius.circular(8),
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
          borderRadius: _isFullscreen ? BorderRadius.zero : BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: _isFullscreen ? BorderRadius.zero : BorderRadius.circular(8),
          child: Stack(
            children: [
              // Video Player - Use BoxFit.contain to preserve aspect ratio and prevent cropping
              Center(
                child: AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: SizedBox(
                    width: _isFullscreen 
                        ? double.infinity 
                        : (videoWidth < _videoPlayerController!.value.size.width 
                            ? videoWidth 
                            : _videoPlayerController!.value.size.width),
                    height: _isFullscreen 
                        ? double.infinity 
                        : null,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _videoPlayerController!.value.size.width,
                        height: _videoPlayerController!.value.size.height,
                        child: VideoPlayer(_videoPlayerController!),
                      ),
                    ),
                  ),
                ),
              ),
              
              // YouTube-style Control Bar
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(_isFullscreen ? 0.8 : 0.7),
                        ],
                      ),
                    ),
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
                        // YouTube-style control bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Go back 5 seconds
                              IconButton(
                                onPressed: _seekBackward,
                                icon: const Icon(
                                  Icons.replay_5,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: 'Go back 5s',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                              // Play/Pause button
                              IconButton(
                                onPressed: _togglePlayPause,
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                tooltip: _isPlaying ? 'Pause' : 'Play',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                              ),
                              // Go forward 5 seconds
                              IconButton(
                                onPressed: _seekForward,
                                icon: const Icon(
                                  Icons.forward_5,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: 'Go forward 5s',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Time display
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_formatDuration(_videoPlayerController!.value.position)} / ${_formatDuration(_videoPlayerController!.value.duration)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Mute/Unmute button only
                              IconButton(
                                onPressed: _toggleMute,
                                icon: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                tooltip: _isMuted ? 'Unmute' : 'Mute',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                              const SizedBox(width: 2),
                              // Fullscreen button
                              IconButton(
                                onPressed: _toggleFullscreen,
                                icon: Icon(
                                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
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

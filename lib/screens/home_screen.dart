import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/video_cutter_service.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedVideoPath;
  VideoPlayerController? _videoController;
  bool _isCutting = false;
  int _currentSegment = 0;
  int _totalSegments = 0;
  double? _videoDuration;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await _loadVideo(path);
    }
  }

  Future<void> _loadVideo(String path) async {
    _videoController?.dispose();

    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();

    final duration = await VideoCutterService.getVideoDuration(path);
    final totalSegments = (duration / 60).ceil();

    setState(() {
      _selectedVideoPath = path;
      _videoController = controller;
      _videoDuration = duration;
      _totalSegments = totalSegments;
      _currentSegment = 0;
    });
  }

  Future<void> _cutVideo() async {
    if (_selectedVideoPath == null) return;

    setState(() {
      _isCutting = true;
      _currentSegment = 0;
    });

    try {
      final segments = await VideoCutterService.cutVideo(
        _selectedVideoPath!,
        onProgress: (current, total) {
          setState(() {
            _currentSegment = current;
            _totalSegments = total;
          });
        },
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(segmentPaths: segments),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCutting = false);
      }
    }
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Cutter'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Text(
              'Cut videos for\nInstagram Stories',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select a video and split it into 60-second parts',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Video preview or pick button
            if (_videoController != null && _videoController!.value.isInitialized)
              _buildVideoPreview()
            else
              _buildPickVideoButton(),

            const SizedBox(height: 24),

            // Video info
            if (_videoDuration != null) ...[
              _buildInfoCard(),
              const SizedBox(height: 24),
            ],

            // Cut button
            if (_selectedVideoPath != null) _buildCutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPickVideoButton() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF333333),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_rounded, size: 64, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text(
              'Tap to select a video',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _isCutting ? null : _pickVideo,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Change video'),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.timer_outlined,
            'Duration',
            _formatDuration(_videoDuration!),
          ),
          const Divider(color: Color(0xFF333333), height: 24),
          _buildInfoRow(
            Icons.content_cut_rounded,
            'Parts',
            '$_totalSegments ${_totalSegments == 1 ? "part" : "parts"} of 60s',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFE1306C), size: 24),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCutButton() {
    if (_isCutting) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: _totalSegments > 0 ? _currentSegment / _totalSegments : null,
            backgroundColor: const Color(0xFF333333),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE1306C)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            'Cutting part $_currentSegment of $_totalSegments...',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: _cutVideo,
      icon: const Icon(Icons.content_cut_rounded),
      label: const Text(
        'Cut Video',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

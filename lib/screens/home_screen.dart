import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/video_cutter_service.dart';
import '../services/permission_service.dart';
import 'results_screen.dart';

class DurationOption {
  final String label;
  final int seconds;

  const DurationOption(this.label, this.seconds);
}

const _durationOptions = [
  DurationOption('15s', 15),
  DurationOption('30s', 30),
  DurationOption('60s', 60),
  DurationOption('90s', 90),
];

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
  VideoInfo? _videoInfo;
  double _storageUsedMb = 0;

  // Settings
  int _selectedDurationIndex = 2; // Default 60s
  bool _convertToVertical = false;

  int get _segmentSeconds => _durationOptions[_selectedDurationIndex].seconds;

  @override
  void initState() {
    super.initState();
    _loadStorageUsage();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadStorageUsage() async {
    final usage = await VideoCutterService.getStorageUsedMb();
    if (mounted) setState(() => _storageUsedMb = usage);
  }

  Future<void> _pickVideo() async {
    final hasPermission = await PermissionService.requestStoragePermissions();
    if (!hasPermission) {
      if (!mounted) return;
      _showPermissionDeniedDialog();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      await _loadVideo(path);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Permission Required'),
        content: const Text(
          'Story Cutter needs access to your files to select and save videos. '
          'Please grant permission in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              PermissionService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVideo(String path) async {
    _videoController?.dispose();

    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();

    final info = await VideoCutterService.getVideoInfo(path);
    final totalSegments = (info.durationSeconds / _segmentSeconds).ceil();

    setState(() {
      _selectedVideoPath = path;
      _videoController = controller;
      _videoInfo = info;
      _totalSegments = totalSegments;
      _currentSegment = 0;
    });
  }

  void _updateSegmentCount() {
    if (_videoInfo != null) {
      setState(() {
        _totalSegments = (_videoInfo!.durationSeconds / _segmentSeconds).ceil();
      });
    }
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
        segmentSeconds: _segmentSeconds,
        convertToVertical: _convertToVertical,
        onProgress: (current, total) {
          setState(() {
            _currentSegment = current;
            _totalSegments = total;
          });
        },
      );

      if (!mounted) return;

      await _loadStorageUsage();

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

  Future<void> _clearStorage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear All Cut Videos?'),
        content: Text(
          'This will delete ${_storageUsedMb.toStringAsFixed(1)} MB of '
          'previously cut video segments. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await VideoCutterService.clearOutputDirectory();
      await _loadStorageUsage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All cut videos deleted.')),
        );
      }
    }
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins}m ${secs}s';
  }

  String _formatResolution(VideoInfo info) {
    if (info.width == 0 || info.height == 0) return 'Unknown';
    return '${info.width}x${info.height}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Cutter'),
        centerTitle: true,
        actions: [
          if (_storageUsedMb > 0)
            IconButton(
              onPressed: _clearStorage,
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear storage (${_storageUsedMb.toStringAsFixed(1)} MB)',
            ),
        ],
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
              'Select a video and split it into parts',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Video preview or pick button
            if (_videoController != null && _videoController!.value.isInitialized)
              _buildVideoPreview()
            else
              _buildPickVideoButton(),

            const SizedBox(height: 24),

            // Settings: duration selector
            _buildDurationSelector(),
            const SizedBox(height: 16),

            // Settings: vertical format toggle
            _buildVerticalToggle(),
            const SizedBox(height: 24),

            // Video info
            if (_videoInfo != null) ...[
              _buildInfoCard(),
              const SizedBox(height: 24),
            ],

            // Cut button
            if (_selectedVideoPath != null) _buildCutButton(),

            const SizedBox(height: 16),

            // Storage info
            if (_storageUsedMb > 0) _buildStorageInfo(),
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
          border: Border.all(color: const Color(0xFF333333), width: 2),
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

  Widget _buildDurationSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFFE1306C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Segment Duration',
                style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_durationOptions.length, (index) {
              final option = _durationOptions[index];
              final isSelected = index == _selectedDurationIndex;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < _durationOptions.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: _isCutting
                        ? null
                        : () {
                            setState(() => _selectedDurationIndex = index);
                            _updateSegmentCount();
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE1306C) : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE1306C) : const Color(0xFF333333),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.crop_portrait_rounded, color: Color(0xFFE1306C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Convert to 9:16 vertical',
                  style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Adds black bars for horizontal videos',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _convertToVertical,
            onChanged: _isCutting ? null : (value) => setState(() => _convertToVertical = value),
            activeColor: const Color(0xFFE1306C),
          ),
        ],
      ),
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
            _formatDuration(_videoInfo!.durationSeconds),
          ),
          const Divider(color: Color(0xFF333333), height: 24),
          _buildInfoRow(
            Icons.aspect_ratio_rounded,
            'Resolution',
            _formatResolution(_videoInfo!),
          ),
          const Divider(color: Color(0xFF333333), height: 24),
          _buildInfoRow(
            Icons.crop_portrait_rounded,
            'Orientation',
            _videoInfo!.isVertical ? 'Vertical' : 'Horizontal',
          ),
          const Divider(color: Color(0xFF333333), height: 24),
          _buildInfoRow(
            Icons.content_cut_rounded,
            'Parts',
            '$_totalSegments ${_totalSegments == 1 ? "part" : "parts"} of ${_segmentSeconds}s',
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
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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

  Widget _buildStorageInfo() {
    return GestureDetector(
      onTap: _clearStorage,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_rounded, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Text(
              '${_storageUsedMb.toStringAsFixed(1)} MB used by cut videos — tap to clear',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

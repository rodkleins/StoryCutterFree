import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../services/gallery_service.dart';
import '../services/permission_service.dart';

class ResultsScreen extends StatefulWidget {
  final List<String> segmentPaths;

  const ResultsScreen({super.key, required this.segmentPaths});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int _selectedIndex = 0;
  VideoPlayerController? _previewController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPlayingAll = false;
  int _playAllCurrentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPreview(0);
  }

  @override
  void dispose() {
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _loadPreview(int index) async {
    setState(() => _isLoading = true);
    _previewController?.dispose();

    final controller = VideoPlayerController.file(
      File(widget.segmentPaths[index]),
    );
    await controller.initialize();

    if (!mounted) return;

    setState(() {
      _selectedIndex = index;
      _previewController = controller;
      _isLoading = false;
    });
  }

  Future<void> _playAll() async {
    setState(() {
      _isPlayingAll = true;
      _playAllCurrentIndex = 0;
    });

    for (int i = 0; i < widget.segmentPaths.length; i++) {
      if (!_isPlayingAll || !mounted) break;

      setState(() => _playAllCurrentIndex = i);
      await _loadPreview(i);

      if (!mounted || _previewController == null) break;

      _previewController!.addListener(_onPlayAllVideoComplete);
      await _previewController!.play();

      // Wait for the video to finish playing
      await _waitForVideoEnd();
    }

    if (mounted) {
      setState(() => _isPlayingAll = false);
    }
  }

  void _onPlayAllVideoComplete() {}

  Future<void> _waitForVideoEnd() async {
    if (_previewController == null) return;
    final duration = _previewController!.value.duration;
    while (mounted && _isPlayingAll && _previewController != null) {
      final position = _previewController!.value.position;
      if (position >= duration - const Duration(milliseconds: 200)) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  void _stopPlayAll() {
    _previewController?.pause();
    setState(() => _isPlayingAll = false);
  }

  Future<void> _shareSegment(int index) async {
    await Share.shareXFiles(
      [XFile(widget.segmentPaths[index])],
      text: 'Story part ${index + 1}',
    );
  }

  Future<void> _shareAll() async {
    final files = widget.segmentPaths
        .map((path) => XFile(path))
        .toList();
    await Share.shareXFiles(files, text: 'All story parts');
  }

  Future<void> _saveToGallery(int index) async {
    final hasPermission = await PermissionService.requestStoragePermissions();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission required to save to gallery.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await GalleryService.saveToGallery(widget.segmentPaths[index]);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Part ${index + 1} saved to gallery!'
              : 'Failed to save part ${index + 1}.',
        ),
        backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red,
      ),
    );
  }

  Future<void> _saveAllToGallery() async {
    final hasPermission = await PermissionService.requestStoragePermissions();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission required to save to gallery.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final saved = await GalleryService.saveAllToGallery(
      widget.segmentPaths,
      onProgress: (current, total) {
        // Could update UI here if needed
      },
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$saved of ${widget.segmentPaths.length} parts saved to gallery!',
        ),
        backgroundColor: saved > 0 ? const Color(0xFF4CAF50) : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.segmentPaths.length} Parts Ready'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveAllToGallery,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_alt_rounded),
            tooltip: 'Save all to gallery',
          ),
          IconButton(
            onPressed: _shareAll,
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share all parts',
          ),
        ],
      ),
      body: Column(
        children: [
          // Video preview
          Expanded(
            flex: 3,
            child: _buildPreview(),
          ),

          // Play all / action bar
          _buildActionBar(),

          // Segment list
          Expanded(
            flex: 2,
            child: _buildSegmentList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE1306C)),
      );
    }

    if (_previewController == null || !_previewController!.value.isInitialized) {
      return const Center(child: Text('Could not load preview'));
    }

    return GestureDetector(
      onTap: () {
        if (_isPlayingAll) {
          _stopPlayAll();
          return;
        }
        setState(() {
          if (_previewController!.value.isPlaying) {
            _previewController!.pause();
          } else {
            _previewController!.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _previewController!.value.aspectRatio,
                child: VideoPlayer(_previewController!),
              ),
            ),
          ),
          if (!_previewController!.value.isPlaying && !_isPlayingAll)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          // Part badge
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE1306C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isPlayingAll
                    ? 'Playing ${_playAllCurrentIndex + 1} of ${widget.segmentPaths.length}'
                    : 'Part ${_selectedIndex + 1} of ${widget.segmentPaths.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Stop button when playing all
          if (_isPlayingAll)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _stopPlayAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stop_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Stop',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Play All button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isPlayingAll ? _stopPlayAll : _playAll,
              icon: Icon(
                _isPlayingAll ? Icons.stop_rounded : Icons.playlist_play_rounded,
                size: 20,
              ),
              label: Text(_isPlayingAll ? 'Stop Preview' : 'Play All in Sequence'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _isPlayingAll ? Colors.red : const Color(0xFFE1306C),
                side: BorderSide(
                  color: _isPlayingAll ? Colors.red : const Color(0xFFE1306C),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentList() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Upload in order: Part 1 first, last part last',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.segmentPaths.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildSegmentTile(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTile(int index) {
    final isSelected = index == _selectedIndex;
    final isCurrentlyPlaying = _isPlayingAll && index == _playAllCurrentIndex;
    final file = File(widget.segmentPaths[index]);
    final fileSizeMb = file.lengthSync() / (1024 * 1024);

    return Material(
      color: isCurrentlyPlaying
          ? const Color(0xFF2A1030)
          : isSelected
              ? const Color(0xFF2A1A2A)
              : const Color(0xFF252525),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isPlayingAll ? null : () => _loadPreview(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected || isCurrentlyPlaying
                      ? const Color(0xFFE1306C)
                      : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isCurrentlyPlaying
                      ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Part ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${fileSizeMb.toStringAsFixed(1)} MB',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Save to gallery button
              IconButton(
                onPressed: _isPlayingAll ? null : () => _saveToGallery(index),
                icon: const Icon(Icons.save_alt_rounded, color: Color(0xFF4CAF50)),
                tooltip: 'Save to gallery',
                iconSize: 20,
              ),
              // Share button
              IconButton(
                onPressed: _isPlayingAll ? null : () => _shareSegment(index),
                icon: const Icon(Icons.share_rounded, color: Color(0xFFE1306C)),
                tooltip: 'Share part ${index + 1}',
                iconSize: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

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
    await Share.shareXFiles(
      files,
      text: 'All story parts',
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
          if (!_previewController!.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
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
                'Part ${_selectedIndex + 1} of ${widget.segmentPaths.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
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
              'Tap to preview, use share to post on Instagram',
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
    final file = File(widget.segmentPaths[index]);
    final fileSizeMb = file.lengthSync() / (1024 * 1024);

    return Material(
      color: isSelected ? const Color(0xFF2A1A2A) : const Color(0xFF252525),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _loadPreview(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE1306C)
                      : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
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
              IconButton(
                onPressed: () => _shareSegment(index),
                icon: const Icon(
                  Icons.share_rounded,
                  color: Color(0xFFE1306C),
                ),
                tooltip: 'Share part ${index + 1}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

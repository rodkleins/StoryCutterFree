import 'dart:io';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_probe.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoInfo {
  final double durationSeconds;
  final int width;
  final int height;

  VideoInfo({
    required this.durationSeconds,
    required this.width,
    required this.height,
  });

  bool get isVertical => height >= width;
  double get aspectRatio => width / height;
}

class VideoCutterService {
  /// Gets duration and resolution of a video file.
  static Future<VideoInfo> getVideoInfo(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();
    if (info == null) {
      throw Exception('Could not read video information.');
    }

    final durationStr = info.getDuration();
    if (durationStr == null) {
      throw Exception('Could not determine video duration.');
    }

    int width = 0;
    int height = 0;
    final streams = info.getStreams();
    for (final stream in streams) {
      final w = stream.getWidth();
      final h = stream.getHeight();
      if (w != null && h != null && w > 0 && h > 0) {
        width = w;
        height = h;
        break;
      }
    }

    return VideoInfo(
      durationSeconds: double.parse(durationStr),
      width: width,
      height: height,
    );
  }

  /// Gets just the duration for backward compat.
  static Future<double> getVideoDuration(String videoPath) async {
    final info = await getVideoInfo(videoPath);
    return info.durationSeconds;
  }

  /// Cuts a video into segments of [segmentSeconds] seconds each.
  /// If [convertToVertical] is true, pads/crops to 9:16 aspect ratio.
  /// Returns a list of file paths for the generated segments.
  /// [onProgress] is called with (currentSegment, totalSegments).
  static Future<List<String>> cutVideo(
    String videoPath, {
    int segmentSeconds = 60,
    bool convertToVertical = false,
    void Function(int current, int total)? onProgress,
  }) async {
    final videoInfo = await getVideoInfo(videoPath);
    final duration = videoInfo.durationSeconds;
    final totalSegments = (duration / segmentSeconds).ceil();

    final outputDir = await _getOutputDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final segments = <String>[];

    // Always output mp4 when re-encoding for vertical
    final extension = convertToVertical ? '.mp4' : p.extension(videoPath);

    for (int i = 0; i < totalSegments; i++) {
      final startTime = i * segmentSeconds;
      final outputPath = p.join(
        outputDir,
        'story_${timestamp}_part${i + 1}$extension',
      );

      onProgress?.call(i + 1, totalSegments);

      if (convertToVertical && !videoInfo.isVertical) {
        // Re-encode with pad/crop to 9:16
        // Scale to fit width=1080, then pad to 1080x1920 with black bars
        final command = '-y '
            '-ss $startTime '
            '-i "$videoPath" '
            '-t $segmentSeconds '
            '-vf "scale=1080:1080/a*1080,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black" '
            '-c:v libx264 -preset fast -crf 23 '
            '-c:a aac -b:a 128k '
            '-avoid_negative_ts make_zero '
            '"$outputPath"';

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getLogsAsString();
          throw Exception('Failed to cut segment ${i + 1}: $logs');
        }
      } else {
        // Fast copy mode (no re-encoding)
        final command = '-y '
            '-ss $startTime '
            '-i "$videoPath" '
            '-t $segmentSeconds '
            '-c copy '
            '-avoid_negative_ts make_zero '
            '"$outputPath"';

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (!ReturnCode.isSuccess(returnCode)) {
          // Fallback: re-encode if copy fails (keyframe issues)
          final reEncodeCommand = '-y '
              '-ss $startTime '
              '-i "$videoPath" '
              '-t $segmentSeconds '
              '-c:v libx264 -preset ultrafast -crf 23 '
              '-c:a aac -b:a 128k '
              '-avoid_negative_ts make_zero '
              '"$outputPath"';

          final reEncodeSession = await FFmpegKit.execute(reEncodeCommand);
          final reEncodeReturnCode = await reEncodeSession.getReturnCode();

          if (!ReturnCode.isSuccess(reEncodeReturnCode)) {
            final logs = await reEncodeSession.getLogsAsString();
            throw Exception('Failed to cut segment ${i + 1}: $logs');
          }
        }
      }

      segments.add(outputPath);
    }

    return segments;
  }

  /// Returns the output directory for cut videos.
  static Future<String> _getOutputDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(appDir.path, 'StoryCutter'));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir.path;
  }

  /// Returns the total size of cut files in MB.
  static Future<double> getStorageUsedMb() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(appDir.path, 'StoryCutter'));
    if (!await outputDir.exists()) return 0;

    double totalBytes = 0;
    await for (final entity in outputDir.list()) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    return totalBytes / (1024 * 1024);
  }

  /// Deletes all previously cut segments from the output directory.
  static Future<void> clearOutputDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(appDir.path, 'StoryCutter'));
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
  }
}

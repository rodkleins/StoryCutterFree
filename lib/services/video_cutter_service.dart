import 'dart:io';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_probe.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoCutterService {
  static const int segmentDurationSeconds = 60;

  /// Gets the duration of a video file in seconds.
  static Future<double> getVideoDuration(String videoPath) async {
    final session = await FFprobeKit.getMediaInformation(videoPath);
    final info = session.getMediaInformation();
    if (info == null) {
      throw Exception('Could not read video information.');
    }
    final durationStr = info.getDuration();
    if (durationStr == null) {
      throw Exception('Could not determine video duration.');
    }
    return double.parse(durationStr);
  }

  /// Cuts a video into segments of [segmentDurationSeconds] seconds each.
  /// Returns a list of file paths for the generated segments.
  /// [onProgress] is called with (currentSegment, totalSegments).
  static Future<List<String>> cutVideo(
    String videoPath, {
    void Function(int current, int total)? onProgress,
  }) async {
    final duration = await getVideoDuration(videoPath);
    final totalSegments = (duration / segmentDurationSeconds).ceil();

    final outputDir = await _getOutputDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(videoPath);
    final segments = <String>[];

    for (int i = 0; i < totalSegments; i++) {
      final startTime = i * segmentDurationSeconds;
      final outputPath = p.join(
        outputDir,
        'story_${timestamp}_part${i + 1}$extension',
      );

      onProgress?.call(i + 1, totalSegments);

      // Use FFmpeg to cut the segment without re-encoding for speed.
      // -ss before -i for fast seeking, -t for duration, -c copy for no re-encode.
      final command = '-y '
          '-ss $startTime '
          '-i "$videoPath" '
          '-t $segmentDurationSeconds '
          '-c copy '
          '-avoid_negative_ts make_zero '
          '"$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        // If copy fails (e.g. keyframe issues), retry with re-encoding
        final reEncodeCommand = '-y '
            '-ss $startTime '
            '-i "$videoPath" '
            '-t $segmentDurationSeconds '
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

  /// Deletes all previously cut segments from the output directory.
  static Future<void> clearOutputDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(p.join(appDir.path, 'StoryCutter'));
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
  }
}

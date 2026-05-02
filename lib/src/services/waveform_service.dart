import 'package:file_picker/file_picker.dart';

import '../models/track_model.dart';
import 'audio_engine_bridge.dart';
import 'waveform_cache.dart';

class WaveformService {
  WaveformService({
    required AudioEngineBridge audioEngine,
    required WaveformCache cache,
  }) : _audioEngine = audioEngine,
       _cache = cache;

  final AudioEngineBridge _audioEngine;
  final WaveformCache _cache;

  int _counter = 0;
  int _trackCounter = 0;

  static const List<String> _supportedMediaExtensions = <String>[
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'opus',
    'amr',
    '3gp',
    'mp4',
    'm4v',
    'mov',
    'mkv',
    'webm',
    'avi',
    'mpeg',
    'mpg',
  ];

  Future<List<TrackModel>> importTracks() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _supportedMediaExtensions,
    );
    if (result == null) {
      return const <TrackModel>[];
    }

    final tracks = <TrackModel>[];
    for (final PlatformFile file in result.files) {
      final path = file.path;
      if (path == null || path.isEmpty) {
        continue;
      }
      final clip = await loadClip(path: path, preferredName: file.name);
      tracks.add(_trackFromClip(clip));
    }
    return tracks;
  }

  Future<TrackClipModel?> importClip() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: _supportedMediaExtensions,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return loadClip(path: path, preferredName: file.name);
  }

  Future<TrackClipModel> loadRecordedClip(String path) {
    return loadClip(
      path: path,
      preferredName:
          'Recording ${DateTime.now().toIso8601String().substring(11, 19)}',
    );
  }

  Future<TrackClipModel> loadClip({
    required String path,
    required String preferredName,
    int startMs = 0,
    int sourceOffsetMs = 0,
    int? durationMs,
  }) async {
    final clipId = createClipId();
    final cached = await _cache.read(path);
    final payload = await _audioEngine.loadTrack(id: clipId, filePath: path);
    final peaks = cached?.peaks.isNotEmpty == true
        ? cached!.peaks
        : payload.waveformPeaks;

    if (cached == null || cached.peaks.isEmpty) {
      await _cache.write(
        sourceKey: path,
        durationMs: payload.durationMs,
        peaks: payload.waveformPeaks,
      );
    }

    final sourceDurationMs = cached?.durationMs ?? payload.durationMs;
    return TrackClipModel(
      id: clipId,
      name: preferredName.isEmpty ? _basename(path) : preferredName,
      filePath: path,
      startMs: startMs,
      durationMs: durationMs ?? payload.durationMs,
      sourceOffsetMs: sourceOffsetMs,
      sourceDurationMs: sourceDurationMs,
      waveformPeaks: peaks,
    );
  }

  TrackModel _trackFromClip(TrackClipModel clip) {
    _trackCounter += 1;
    return TrackModel(
      id: 'track_${DateTime.now().microsecondsSinceEpoch}_$_trackCounter',
      name: clip.name,
      volume: 1,
      pan: 0,
      reverb: 0,
      muted: false,
      solo: false,
      recordArmed: false,
      clips: <TrackClipModel>[clip],
    );
  }

  String createClipId() {
    _counter += 1;
    return 'clip_${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }

  String _basename(String value) {
    return value
        .split(RegExp(r'[\\/]'))
        .where((String part) => part.isNotEmpty)
        .last;
  }
}

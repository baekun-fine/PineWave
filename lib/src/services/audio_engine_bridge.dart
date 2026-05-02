import 'package:flutter/services.dart';

import '../models/track_model.dart';

class AudioEngineBridge {
  static const MethodChannel _methodChannel = MethodChannel(
    'music_daw_player/audio_engine',
  );
  static const EventChannel _eventChannel = EventChannel(
    'music_daw_player/audio_engine/events',
  );

  late final Stream<PlaybackPosition> _positionStream = _eventChannel
      .receiveBroadcastStream()
      .map((dynamic event) {
        final payload = Map<String, dynamic>.from(
          event as Map<dynamic, dynamic>,
        );
        return PlaybackPosition(
          positionMs: (payload['positionMs'] as num? ?? 0).round(),
          durationMs: (payload['durationMs'] as num? ?? 0).round(),
          isPlaying: payload['isPlaying'] as bool? ?? false,
          recordingLevel: (payload['recordingLevel'] as num? ?? 0)
              .toDouble()
              .clamp(0, 1)
              .toDouble(),
        );
      })
      .asBroadcastStream();

  Stream<PlaybackPosition> get positionStream => _positionStream;

  Future<LoadedTrackPayload> loadTrack({
    required String id,
    required String filePath,
  }) async {
    final payload = await _invokeMap('loadTrack', <String, Object?>{
      'id': id,
      'filePath': filePath,
    });
    return LoadedTrackPayload(
      durationMs: (payload['durationMs'] as num? ?? 0).round(),
      waveformPeaks: (payload['waveformPeaks'] as List<dynamic>? ?? const [])
          .map((dynamic value) => (value as num).toDouble())
          .toList(growable: false),
    );
  }

  Future<void> removeTrack(String id) async {
    await _methodChannel.invokeMethod<void>('removeTrack', <String, Object?>{
      'id': id,
    });
  }

  Future<void> play() => _methodChannel.invokeMethod<void>('play');

  Future<void> pause() => _methodChannel.invokeMethod<void>('pause');

  Future<void> seek(int positionMs) async {
    await _methodChannel.invokeMethod<void>('seek', <String, Object?>{
      'positionMs': positionMs,
    });
  }

  Future<void> setSpeed(double speed) async {
    await _methodChannel.invokeMethod<void>('setSpeed', <String, Object?>{
      'speed': speed,
    });
  }

  Future<void> setTrackVolume({
    required String id,
    required double volume,
  }) async {
    await _methodChannel.invokeMethod<void>('setTrackVolume', <String, Object?>{
      'id': id,
      'volume': volume,
    });
  }

  Future<void> setTrackPan({required String id, required double pan}) async {
    await _methodChannel.invokeMethod<void>('setTrackPan', <String, Object?>{
      'id': id,
      'pan': pan,
    });
  }

  Future<void> setTrackReverb({
    required String id,
    required double reverb,
  }) async {
    await _methodChannel.invokeMethod<void>('setTrackReverb', <String, Object?>{
      'id': id,
      'reverb': reverb,
    });
  }

  Future<void> setTrackReverbSettings({
    required String id,
    required ReverbSettings settings,
  }) async {
    await _methodChannel.invokeMethod<void>(
      'setTrackReverbSettings',
      <String, Object?>{'id': id, ...settings.toPlatformMap()},
    );
  }

  Future<void> setTrackMute({required String id, required bool muted}) async {
    await _methodChannel.invokeMethod<void>('setTrackMute', <String, Object?>{
      'id': id,
      'muted': muted,
    });
  }

  Future<void> setTrackStart({required String id, required int startMs}) async {
    await _methodChannel.invokeMethod<void>('setTrackStart', <String, Object?>{
      'id': id,
      'startMs': startMs,
    });
  }

  Future<void> setTrackRegion({
    required String id,
    required int startMs,
    required int sourceOffsetMs,
    required int durationMs,
  }) async {
    await _methodChannel.invokeMethod<void>('setTrackRegion', <String, Object?>{
      'id': id,
      'startMs': startMs,
      'sourceOffsetMs': sourceOffsetMs,
      'durationMs': durationMs,
    });
  }

  Future<AudioRenderResult> mixTracks({
    required List<String> ids,
    required String outputDirectory,
    required String outputFileName,
  }) async {
    final payload = await _invokeMap('mixTracks', <String, Object?>{
      'ids': ids,
      'outputDirectory': outputDirectory,
      'outputFileName': outputFileName,
    });
    return AudioRenderResult(filePath: payload['filePath'] as String? ?? '');
  }

  Future<String?> pickOutputDirectory() async {
    final path = await _methodChannel.invokeMethod<String>(
      'pickOutputDirectory',
    );
    if (path == null || path.isEmpty) {
      return null;
    }
    return path;
  }

  Future<String> writeSessionFile({
    required String directoryUri,
    required String fileName,
    required String contents,
  }) async {
    final payload = await _invokeMap('writeSessionFile', <String, Object?>{
      'directoryUri': directoryUri,
      'fileName': fileName,
      'contents': contents,
    });
    return payload['filePath'] as String? ?? '';
  }

  Future<SessionFilePayload> readSessionFile({
    required String directoryUri,
    required String fileName,
  }) async {
    final payload = await _invokeMap('readSessionFile', <String, Object?>{
      'directoryUri': directoryUri,
      'fileName': fileName,
    });
    return SessionFilePayload(
      filePath: payload['filePath'] as String? ?? '',
      contents: payload['contents'] as String? ?? '',
    );
  }

  Future<VocalSeparationResult> separateVocalBacking({
    required List<String> ids,
    required String outputDirectory,
    required String outputBaseName,
  }) async {
    final payload = await _invokeMap('separateVocalBacking', <String, Object?>{
      'ids': ids,
      'outputDirectory': outputDirectory,
      'outputBaseName': outputBaseName,
    });
    return VocalSeparationResult(
      vocalsFilePath: payload['vocalsFilePath'] as String? ?? '',
      backingFilePath: payload['backingFilePath'] as String? ?? '',
    );
  }

  Future<void> startRecording() async {
    await _methodChannel.invokeMethod<void>('startRecording');
  }

  Future<String> stopRecording() async {
    final payload = await _invokeMap(
      'stopRecording',
      const <String, Object?>{},
    );
    return payload['filePath'] as String? ?? '';
  }

  Future<Map<String, dynamic>> _invokeMap(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final payload = await _methodChannel.invokeMethod<dynamic>(
      method,
      arguments,
    );
    if (payload is Map<Object?, Object?>) {
      return payload.map<String, dynamic>(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    return const <String, dynamic>{};
  }
}

class SessionFilePayload {
  const SessionFilePayload({required this.filePath, required this.contents});

  final String filePath;
  final String contents;
}

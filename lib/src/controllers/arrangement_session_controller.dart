import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import '../services/audio_engine_bridge.dart';
import '../services/waveform_cache.dart';
import '../services/waveform_service.dart';

class ArrangementSessionController extends ChangeNotifier {
  ArrangementSessionController({
    AudioEngineBridge? audioEngine,
    WaveformService? waveformService,
  }) : this._(audioEngine ?? AudioEngineBridge(), waveformService);

  ArrangementSessionController._(
    AudioEngineBridge audioEngine,
    WaveformService? waveformService,
  ) : _audioEngine = audioEngine,
      _waveformService =
          waveformService ??
          WaveformService(
            audioEngine: audioEngine,
            cache: const WaveformCache(),
          ) {
    _positionSubscription = _audioEngine.positionStream.listen(
      _handlePositionUpdate,
    );
  }

  static const int _emptyTrackDurationMs = 30000;
  static const String _sessionFileName = 'music_daw_session.json';

  final AudioEngineBridge _audioEngine;
  final WaveformService _waveformService;
  final List<TrackModel> _tracks = <TrackModel>[];
  final List<double> _recordingPeaks = <double>[];

  StreamSubscription<PlaybackPosition>? _positionSubscription;
  Timer? _recordingUiTimer;

  bool _isImporting = false;
  String? _loadingMessage;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _autoStoppingAtEnd = false;
  int _positionMs = 0;
  int _durationMs = 0;
  int _recordingStartPositionMs = 0;
  int _recordingElapsedMs = 0;
  double _recordingLevel = 0;
  double _speed = 1;
  int _emptyTrackCounter = 0;
  DateTime? _recordingStartedAt;

  List<TrackModel> get tracks => List<TrackModel>.unmodifiable(_tracks);
  bool get hasTracks => _tracks.isNotEmpty;
  bool get isImporting => _isImporting;
  String? get loadingMessage => _loadingMessage;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get hasRecordArmedTrack =>
      _tracks.any((TrackModel track) => track.recordArmed);
  bool get hasMixSelection =>
      _tracks.any((TrackModel track) => track.mixSelected && track.hasAudio);
  bool get hasSplittableSelection {
    final selectedCount = _tracks
        .where((TrackModel track) => track.mixSelected && track.hasAudio)
        .length;
    final audioCount = _tracks
        .where((TrackModel track) => track.hasAudio)
        .length;
    return selectedCount > 0 || audioCount == 1;
  }

  int get positionMs => _positionMs;
  int get durationMs => _durationMs;
  int get recordingStartPositionMs => _recordingStartPositionMs;
  int get recordingElapsedMs => _recordingElapsedMs;
  double get recordingLevel => _recordingLevel;
  List<double> get recordingPeaks => List<double>.unmodifiable(_recordingPeaks);
  double get speed => _speed;

  Future<void> importTracks() async {
    if (_isImporting) {
      return;
    }
    _setLoading('Loading audio/video files...');
    try {
      final imported = await _waveformService.importTracks();
      if (imported.isEmpty) {
        return;
      }
      _tracks.addAll(imported);
      _durationMs = _calculateDuration();
      _positionMs = min(_positionMs, _durationMs);
      await _syncTrackAudibility();
    } finally {
      _clearLoading();
    }
  }

  Future<void> importClipIntoTrack(String trackId) async {
    if (_isImporting) {
      return;
    }
    final index = _tracks.indexWhere((TrackModel track) => track.id == trackId);
    if (index == -1) {
      return;
    }
    _setLoading('Loading audio/video file...');
    try {
      final clip = await _waveformService.importClip();
      if (clip == null) {
        return;
      }
      final track = _tracks[index];
      await _removeNativeClips(track.clips);
      final nextClip = clip.copyWith(startMs: _positionMs);
      _tracks[index] = track.copyWith(
        name: track.name.isEmpty ? nextClip.name : track.name,
        clips: <TrackClipModel>[nextClip],
      );
      await _audioEngine.setTrackRegion(
        id: nextClip.id,
        startMs: nextClip.startMs,
        sourceOffsetMs: nextClip.sourceOffsetMs,
        durationMs: nextClip.durationMs,
      );
      await _applyTrackControlsToClip(_tracks[index], nextClip.id);
      _durationMs = _calculateDuration();
      await _syncTrackAudibility();
    } finally {
      _clearLoading();
    }
  }

  void addEmptyTrack() {
    _emptyTrackCounter += 1;
    _tracks.add(
      TrackModel(
        id: 'empty_${DateTime.now().microsecondsSinceEpoch}_$_emptyTrackCounter',
        name: 'Audio $_emptyTrackCounter',
        volume: 1,
        pan: 0,
        reverb: 0,
        muted: false,
        solo: false,
        recordArmed: false,
        fallbackDurationMs: _emptyTrackDurationMs,
      ),
    );
    _durationMs = _calculateDuration();
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    if (!hasTracks) {
      return;
    }
    if (_isPlaying) {
      await _audioEngine.pause();
      _isPlaying = false;
    } else {
      if (_durationMs > 0 && _positionMs >= _durationMs - 20) {
        _positionMs = 0;
        await _audioEngine.seek(0);
      }
      await _audioEngine.play();
      _isPlaying = true;
    }
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    Object? recordingError;
    StackTrace? recordingStackTrace;
    if (_isRecording) {
      try {
        await stopRecording();
      } catch (error, stackTrace) {
        recordingError = error;
        recordingStackTrace = stackTrace;
      }
    }
    if (_isPlaying) {
      await _audioEngine.pause();
    }
    _isPlaying = false;
    _positionMs = 0;
    notifyListeners();
    if (hasTracks) {
      await _audioEngine.seek(0);
    }
    if (recordingError != null) {
      Error.throwWithStackTrace(
        recordingError,
        recordingStackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> toggleRecording() async {
    if (_isRecording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  }

  Future<void> startRecording() async {
    if (_isRecording) {
      return;
    }
    final armedIndex = _tracks.indexWhere(
      (TrackModel track) => track.recordArmed,
    );
    if (armedIndex == -1) {
      throw Exception('Arm one track before recording.');
    }

    _recordingStartPositionMs = _positionMs;
    _recordingElapsedMs = 0;
    _recordingLevel = 0;
    _recordingPeaks.clear();
    _recordingStartedAt = null;

    await _audioEngine.startRecording();
    _isRecording = true;
    _isPlaying = true;
    _recordingStartedAt = DateTime.now();
    _startRecordingUiTimer();
    notifyListeners();

    await _syncTrackAudibility();
    if (_tracks.any((TrackModel track) => track.hasAudio)) {
      await _audioEngine.play();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) {
      return;
    }
    final armedIndex = _tracks.indexWhere(
      (TrackModel track) => track.recordArmed,
    );
    String path = '';
    try {
      path = await _audioEngine.stopRecording();
    } finally {
      _isRecording = false;
      _stopRecordingUiTimer();
      _recordingLevel = 0;
      if (!_tracks.any((TrackModel track) => track.hasAudio)) {
        _isPlaying = false;
      }
      notifyListeners();
    }
    if (path.isEmpty) {
      await _syncTrackAudibility();
      return;
    }

    _setLoading('Loading recording...');
    try {
      final recordedClip = await _waveformService.loadRecordedClip(path);
      if (armedIndex == -1) {
        final track = _trackFromRecordedClip(recordedClip);
        _tracks.add(track);
        await _prepareClipForTrack(track, track.clips.first);
      } else {
        await _overwriteTrackWithRecording(
          trackIndex: armedIndex,
          recordedClip: recordedClip,
        );
      }
      _durationMs = _calculateDuration();
      _positionMs = min(_positionMs, _durationMs);
      await _syncTrackAudibility();
    } finally {
      _clearLoading();
    }
  }

  Future<void> seekTo(int positionMs) async {
    if (!hasTracks) {
      return;
    }
    final int safePosition = positionMs.clamp(0, _durationMs);
    final bool shouldResume = _isPlaying && !_isRecording;
    _positionMs = safePosition;
    notifyListeners();
    await _audioEngine.seek(safePosition);
    if (shouldResume && safePosition < _durationMs) {
      await _audioEngine.play();
      _isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> setSpeed(double value) async {
    final double safeSpeed = value.clamp(0.5, 2.0);
    _speed = safeSpeed;
    notifyListeners();
    await _audioEngine.setSpeed(safeSpeed);
  }

  Future<void> setTrackVolume(String trackId, double volume) async {
    final double safeVolume = volume.clamp(0, 1);
    final track = _updateTrack(
      trackId,
      (TrackModel track) => track.copyWith(volume: safeVolume),
    );
    if (track != null) {
      await Future.wait(
        track.clips.map(
          (TrackClipModel clip) =>
              _audioEngine.setTrackVolume(id: clip.id, volume: safeVolume),
        ),
      );
    }
  }

  Future<void> setTrackPan(String trackId, double pan) async {
    final double safePan = pan.clamp(-1, 1);
    final track = _updateTrack(
      trackId,
      (TrackModel track) => track.copyWith(pan: safePan),
    );
    if (track != null) {
      await Future.wait(
        track.clips.map(
          (TrackClipModel clip) =>
              _audioEngine.setTrackPan(id: clip.id, pan: safePan),
        ),
      );
    }
  }

  Future<void> setTrackReverb(String trackId, double reverb) async {
    final double safeReverb = reverb.clamp(0, 1);
    final track = _updateTrack(
      trackId,
      (TrackModel track) => track.copyWith(reverb: safeReverb),
    );
    if (track != null) {
      await Future.wait(
        track.clips.map(
          (TrackClipModel clip) =>
              _audioEngine.setTrackReverb(id: clip.id, reverb: safeReverb),
        ),
      );
    }
  }

  Future<void> setTrackReverbSettings(
    String trackId,
    ReverbSettings settings,
  ) async {
    final safeSettings = settings.copyWith(
      mix: settings.mix.clamp(0, 1).toDouble(),
      roomSize: settings.roomSize.clamp(0, 1).toDouble(),
      decay: settings.decay.clamp(0, 1).toDouble(),
      damp: settings.damp.clamp(0, 1).toDouble(),
      preDelayMs: settings.preDelayMs.clamp(0, 120).toDouble(),
      width: settings.width.clamp(0, 1).toDouble(),
    );
    final track = _updateTrack(
      trackId,
      (TrackModel track) => track.copyWith(reverbSettings: safeSettings),
    );
    if (track != null) {
      await Future.wait(
        track.clips.map(
          (TrackClipModel clip) => _audioEngine.setTrackReverbSettings(
            id: clip.id,
            settings: safeSettings,
          ),
        ),
      );
    }
  }

  Future<void> setTrackMuted(String trackId, bool muted) async {
    _updateTrack(trackId, (TrackModel track) => track.copyWith(muted: muted));
    await _syncTrackAudibility();
  }

  Future<void> setTrackSolo(String trackId, bool solo) async {
    for (var index = 0; index < _tracks.length; index += 1) {
      final track = _tracks[index];
      _tracks[index] = track.copyWith(solo: solo && track.id == trackId);
    }
    notifyListeners();
    await _syncTrackAudibility();
  }

  void setTrackRecordArmed(String trackId, bool recordArmed) {
    for (var index = 0; index < _tracks.length; index += 1) {
      final track = _tracks[index];
      _tracks[index] = track.copyWith(
        recordArmed: recordArmed && track.id == trackId,
      );
    }
    notifyListeners();
  }

  void setTrackMixSelected(String trackId, bool selected) {
    _updateTrack(
      trackId,
      (TrackModel track) => track.copyWith(mixSelected: selected),
    );
  }

  Future<void> moveTrackBy(String trackId, int deltaMs) async {
    if (deltaMs == 0) {
      return;
    }
    final index = _tracks.indexWhere((TrackModel track) => track.id == trackId);
    if (index == -1) {
      return;
    }
    final track = _tracks[index];
    if (!track.hasAudio) {
      return;
    }
    final int safeDelta = max(
      -track.clips.map((TrackClipModel clip) => clip.startMs).reduce(min),
      deltaMs,
    );
    if (safeDelta == 0) {
      return;
    }
    final nextClips = track.clips
        .map(
          (TrackClipModel clip) =>
              clip.copyWith(startMs: clip.startMs + safeDelta),
        )
        .toList(growable: false);
    _tracks[index] = track.copyWith(clips: nextClips);
    _durationMs = _calculateDuration();
    notifyListeners();
    await Future.wait(nextClips.map(_setClipRegion));
  }

  Future<void> clearTrackAudio(String trackId) async {
    if (_isRecording &&
        _tracks.any(
          (TrackModel track) => track.id == trackId && track.recordArmed,
        )) {
      await stopRecording();
    }
    final index = _tracks.indexWhere((TrackModel track) => track.id == trackId);
    if (index == -1) {
      return;
    }
    final track = _tracks[index];
    await _removeNativeClips(track.clips);
    _tracks[index] = track.copyWith(clips: const <TrackClipModel>[]);
    _durationMs = _calculateDuration();
    if (_positionMs > _durationMs) {
      _positionMs = _durationMs;
      await _audioEngine.seek(_durationMs);
    }
    await _syncTrackAudibility();
    notifyListeners();
  }

  Future<void> removeTrack(String trackId) async {
    if (_isRecording &&
        _tracks.any(
          (TrackModel track) => track.id == trackId && track.recordArmed,
        )) {
      await stopRecording();
    }
    final index = _tracks.indexWhere((TrackModel track) => track.id == trackId);
    if (index == -1) {
      return;
    }
    await _removeNativeClips(_tracks[index].clips);
    _tracks.removeAt(index);
    _durationMs = _calculateDuration();
    if (_tracks.isEmpty) {
      _positionMs = 0;
      _isPlaying = false;
    } else if (_positionMs > _durationMs) {
      _positionMs = _durationMs;
      await _audioEngine.seek(_durationMs);
    }
    await _syncTrackAudibility();
    notifyListeners();
  }

  Future<String?> mixSelectedTracks({String? outputFileName}) async {
    final selectedTracks = _selectedAudioTracks();
    if (selectedTracks.isEmpty) {
      throw Exception('Select one or more Mix tracks before mixing.');
    }
    if (_isRecording) {
      throw Exception('Stop recording before mixing tracks.');
    }
    final outputDirectory = await _audioEngine.pickOutputDirectory();
    if (outputDirectory == null || outputDirectory.isEmpty) {
      return null;
    }

    _setLoading('Mixing selected tracks to MP3...');
    try {
      await _pauseForOfflineRender();
      final safeFileName = _ensureExtension(
        _safeFileName(outputFileName ?? _timestampedName('Mix', 'mp3'), 'mix'),
        'mp3',
      );
      final result = await _audioEngine.mixTracks(
        ids: _clipIdsForTracks(selectedTracks),
        outputDirectory: outputDirectory,
        outputFileName: safeFileName,
      );
      if (result.filePath.isEmpty) {
        throw Exception('Mix render failed.');
      }
      final clip = await _waveformService.loadClip(
        path: result.filePath,
        preferredName: safeFileName,
      );
      final track = TrackModel(
        id: 'mix_${DateTime.now().microsecondsSinceEpoch}',
        name: clip.name,
        volume: 1,
        pan: 0,
        reverb: 0,
        muted: false,
        solo: false,
        recordArmed: false,
        clips: <TrackClipModel>[clip],
      );
      _tracks.add(track);
      await _prepareClipForTrack(track, clip);
      _durationMs = _calculateDuration();
      await _syncTrackAudibility();
      return result.filePath;
    } finally {
      _clearLoading();
    }
  }

  Future<String?> separateSelectedTracks({String? outputBaseName}) async {
    var selectedTracks = _selectedAudioTracks();
    if (selectedTracks.isEmpty) {
      final audioTracks = _tracks
          .where((TrackModel track) => track.hasAudio)
          .toList(growable: false);
      if (audioTracks.length == 1) {
        selectedTracks = audioTracks;
      }
    }
    if (selectedTracks.isEmpty) {
      throw Exception('Select one or more Mix tracks before splitting.');
    }
    if (_isRecording) {
      throw Exception('Stop recording before splitting vocals.');
    }
    final outputDirectory = await _audioEngine.pickOutputDirectory();
    if (outputDirectory == null || outputDirectory.isEmpty) {
      return null;
    }

    _setLoading('Splitting vocal and backing MP3 files...');
    try {
      await _pauseForOfflineRender();
      final safeBaseName = _safeFileName(
        outputBaseName ?? _timestampedName('Split', 'mp3'),
        'split',
      ).replaceFirst(RegExp(r'\.mp3$', caseSensitive: false), '');
      final vocalsFileName = '${safeBaseName}_vocals.mp3';
      final backingFileName = '${safeBaseName}_backing.mp3';
      final result = await _audioEngine.separateVocalBacking(
        ids: _clipIdsForTracks(selectedTracks),
        outputDirectory: outputDirectory,
        outputBaseName: safeBaseName,
      );
      if (result.vocalsFilePath.isEmpty || result.backingFilePath.isEmpty) {
        throw Exception('Vocal split failed.');
      }

      final vocalsClip = await _waveformService.loadClip(
        path: result.vocalsFilePath,
        preferredName: vocalsFileName,
      );
      final backingClip = await _waveformService.loadClip(
        path: result.backingFilePath,
        preferredName: backingFileName,
      );
      final vocalsTrack = TrackModel(
        id: 'vocals_${DateTime.now().microsecondsSinceEpoch}',
        name: vocalsClip.name,
        volume: 1,
        pan: 0,
        reverb: 0,
        muted: false,
        solo: false,
        recordArmed: false,
        clips: <TrackClipModel>[vocalsClip],
      );
      final backingTrack = TrackModel(
        id: 'backing_${DateTime.now().microsecondsSinceEpoch}',
        name: backingClip.name,
        volume: 1,
        pan: 0,
        reverb: 0,
        muted: false,
        solo: false,
        recordArmed: false,
        clips: <TrackClipModel>[backingClip],
      );
      _tracks.addAll(<TrackModel>[vocalsTrack, backingTrack]);
      await Future.wait(<Future<void>>[
        _prepareClipForTrack(vocalsTrack, vocalsClip),
        _prepareClipForTrack(backingTrack, backingClip),
      ]);
      _durationMs = _calculateDuration();
      await _syncTrackAudibility();
      return outputDirectory;
    } finally {
      _clearLoading();
    }
  }

  Future<String?> saveSession({String? fileName}) async {
    final directoryUri = await _audioEngine.pickOutputDirectory();
    if (directoryUri == null || directoryUri.isEmpty) {
      return null;
    }
    _setLoading('Saving session...');
    try {
      final safeFileName = _ensureExtension(
        _safeFileName(fileName ?? _sessionFileName, 'music_daw_session'),
        'json',
      );
      final payload = <String, Object?>{
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'positionMs': _positionMs,
        'speed': _speed,
        'tracks': _tracks.map((TrackModel track) => track.toJson()).toList(),
      };
      return _audioEngine.writeSessionFile(
        directoryUri: directoryUri,
        fileName: safeFileName,
        contents: const JsonEncoder.withIndent('  ').convert(payload),
      );
    } finally {
      _clearLoading();
    }
  }

  Future<String?> loadSession({String? fileName}) async {
    if (_isRecording) {
      await stopRecording();
    }
    final directoryUri = await _audioEngine.pickOutputDirectory();
    if (directoryUri == null || directoryUri.isEmpty) {
      return null;
    }

    _setLoading('Loading session...');
    try {
      if (_isPlaying) {
        await _audioEngine.pause();
      }
      _isPlaying = false;
      await _removeNativeClips(
        _tracks.expand((TrackModel track) => track.clips).toList(),
      );
      final sessionFile = await _audioEngine.readSessionFile(
        directoryUri: directoryUri,
        fileName: _ensureExtension(
          _safeFileName(fileName ?? _sessionFileName, 'music_daw_session'),
          'json',
        ),
      );
      final payload = jsonDecode(sessionFile.contents) as Map<String, dynamic>;
      final trackPayloads = payload['tracks'] as List<dynamic>? ?? const [];
      _tracks.clear();
      for (final dynamic trackPayload in trackPayloads) {
        if (trackPayload is Map<String, dynamic>) {
          final restored = await _restoreTrack(trackPayload);
          if (restored != null) {
            _tracks.add(restored);
          }
        }
      }
      _speed = (payload['speed'] as num? ?? 1)
          .toDouble()
          .clamp(0.5, 2.0)
          .toDouble();
      _durationMs = _calculateDuration();
      _positionMs = (payload['positionMs'] as num? ?? 0)
          .round()
          .clamp(0, _durationMs)
          .toInt();
      await _audioEngine.setSpeed(_speed);
      await _audioEngine.seek(_positionMs);
      await _syncTrackAudibility();
      return sessionFile.filePath;
    } finally {
      _clearLoading();
    }
  }

  void _handlePositionUpdate(PlaybackPosition state) {
    final bool wasPlaying = _isPlaying;
    final int liveRecordingEndMs = _isRecording
        ? _recordingStartPositionMs + _recordingElapsedMs
        : 0;
    _durationMs = max(
      max(_calculateDuration(), state.durationMs),
      liveRecordingEndMs,
    );

    if (!_isRecording &&
        wasPlaying &&
        _durationMs > 0 &&
        (state.positionMs >= _durationMs - 20 ||
            (!state.isPlaying && state.positionMs >= state.durationMs - 20))) {
      _isPlaying = false;
      _positionMs = 0;
      notifyListeners();
      unawaited(_stopAtTimelineEnd());
      return;
    }

    final int nativePosition = state.positionMs.clamp(
      0,
      max(_durationMs, state.durationMs),
    );
    final int livePosition = max(
      nativePosition,
      liveRecordingEndMs,
    ).clamp(0, _durationMs).toInt();
    _positionMs = _isRecording ? livePosition : nativePosition;
    _isPlaying = _isRecording || state.isPlaying;
    if (_isRecording) {
      _recordingLevel = state.recordingLevel.clamp(0, 1).toDouble();
      _appendRecordingPeak(_recordingLevel);
    }
    notifyListeners();
  }

  Future<void> _stopAtTimelineEnd() async {
    if (_autoStoppingAtEnd) {
      return;
    }
    _autoStoppingAtEnd = true;
    try {
      await _audioEngine.pause();
      if (hasTracks) {
        await _audioEngine.seek(0);
      }
    } finally {
      _autoStoppingAtEnd = false;
    }
  }

  TrackModel? _updateTrack(
    String trackId,
    TrackModel Function(TrackModel track) update,
  ) {
    final index = _tracks.indexWhere((TrackModel track) => track.id == trackId);
    if (index == -1) {
      return null;
    }
    _tracks[index] = update(_tracks[index]);
    _durationMs = _calculateDuration();
    notifyListeners();
    return _tracks[index];
  }

  void _setLoading(String message) {
    _isImporting = true;
    _loadingMessage = message;
    notifyListeners();
  }

  void _clearLoading() {
    _isImporting = false;
    _loadingMessage = null;
    notifyListeners();
  }

  Future<void> _overwriteTrackWithRecording({
    required int trackIndex,
    required TrackClipModel recordedClip,
  }) async {
    final target = _tracks[trackIndex];
    final int overwriteStartMs = _recordingStartPositionMs;
    final TrackClipModel recording = recordedClip.copyWith(
      startMs: overwriteStartMs,
      durationMs: recordedClip.durationMs,
      sourceOffsetMs: 0,
    );
    final int overwriteEndMs = recording.endMs;
    final nextClips = <TrackClipModel>[];
    final clipsToRemove = <TrackClipModel>[];
    final segmentsToLoad = <TrackClipModel>[];

    for (final clip in target.clips) {
      final bool overlaps =
          clip.startMs < overwriteEndMs && clip.endMs > overwriteStartMs;
      if (!overlaps) {
        nextClips.add(clip);
        continue;
      }

      clipsToRemove.add(clip);
      if (clip.startMs < overwriteStartMs) {
        final leftDurationMs = overwriteStartMs - clip.startMs;
        final leftClip = clip.copyWith(
          id: _waveformService.createClipId(),
          durationMs: leftDurationMs,
        );
        nextClips.add(leftClip);
        segmentsToLoad.add(leftClip);
      }
      if (clip.endMs > overwriteEndMs) {
        final skippedMs = overwriteEndMs - clip.startMs;
        final rightClip = clip.copyWith(
          id: _waveformService.createClipId(),
          startMs: overwriteEndMs,
          durationMs: clip.endMs - overwriteEndMs,
          sourceOffsetMs: clip.sourceOffsetMs + skippedMs,
        );
        nextClips.add(rightClip);
        segmentsToLoad.add(rightClip);
      }
    }

    nextClips.add(recording);
    nextClips.sort(
      (TrackClipModel a, TrackClipModel b) => a.startMs.compareTo(b.startMs),
    );
    await _removeNativeClips(clipsToRemove);
    await Future.wait(segmentsToLoad.map(_loadExistingClipSegment));
    await Future.wait(
      segmentsToLoad.map(
        (TrackClipModel clip) => _applyTrackControlsToClip(target, clip.id),
      ),
    );

    _tracks[trackIndex] = target.copyWith(clips: nextClips, recordArmed: false);
    await _prepareClipForTrack(_tracks[trackIndex], recording);
  }

  TrackModel _trackFromRecordedClip(TrackClipModel clip) {
    return TrackModel(
      id: 'track_${DateTime.now().microsecondsSinceEpoch}',
      name: clip.name,
      volume: 1,
      pan: 0,
      reverb: 0,
      muted: false,
      solo: false,
      recordArmed: false,
      clips: <TrackClipModel>[
        clip.copyWith(startMs: _recordingStartPositionMs),
      ],
    );
  }

  Future<void> _loadExistingClipSegment(TrackClipModel clip) async {
    await _audioEngine.loadTrack(id: clip.id, filePath: clip.filePath);
    await _setClipRegion(clip);
  }

  Future<void> _prepareClipForTrack(
    TrackModel track,
    TrackClipModel clip,
  ) async {
    await _setClipRegion(clip);
    await _applyTrackControlsToClip(track, clip.id);
  }

  Future<void> _setClipRegion(TrackClipModel clip) {
    return _audioEngine.setTrackRegion(
      id: clip.id,
      startMs: clip.startMs,
      sourceOffsetMs: clip.sourceOffsetMs,
      durationMs: clip.durationMs,
    );
  }

  Future<void> _applyTrackControlsToClip(
    TrackModel track,
    String clipId,
  ) async {
    await Future.wait(<Future<void>>[
      _audioEngine.setTrackVolume(id: clipId, volume: track.volume),
      _audioEngine.setTrackPan(id: clipId, pan: track.pan),
      _audioEngine.setTrackReverb(id: clipId, reverb: track.reverb),
      _audioEngine.setTrackReverbSettings(
        id: clipId,
        settings: track.reverbSettings,
      ),
    ]);
  }

  Future<void> _removeNativeClips(List<TrackClipModel> clips) {
    return Future.wait(
      clips.map((TrackClipModel clip) => _audioEngine.removeTrack(clip.id)),
    );
  }

  List<TrackModel> _selectedAudioTracks() {
    return _tracks
        .where((TrackModel track) => track.mixSelected && track.hasAudio)
        .toList(growable: false);
  }

  List<String> _clipIdsForTracks(List<TrackModel> tracks) {
    return tracks
        .expand((TrackModel track) => track.clips)
        .map((TrackClipModel clip) => clip.id)
        .toList(growable: false);
  }

  Future<void> _pauseForOfflineRender() async {
    if (!_isPlaying) {
      return;
    }
    await _audioEngine.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<TrackModel?> _restoreTrack(Map<String, dynamic> payload) async {
    final clipPayloads = payload['clips'] as List<dynamic>? ?? const [];
    final clips = <TrackClipModel>[];
    for (final dynamic clipPayload in clipPayloads) {
      if (clipPayload is! Map<String, dynamic>) {
        continue;
      }
      final path = clipPayload['filePath'] as String? ?? '';
      if (path.isEmpty) {
        continue;
      }
      try {
        clips.add(
          await _waveformService.loadClip(
            path: path,
            preferredName: clipPayload['name'] as String? ?? '',
            startMs: (clipPayload['startMs'] as num? ?? 0).round(),
            sourceOffsetMs: (clipPayload['sourceOffsetMs'] as num? ?? 0)
                .round(),
            durationMs: (clipPayload['durationMs'] as num?)?.round(),
          ),
        );
      } catch (_) {
        // Missing files are skipped so the rest of the session can load.
      }
    }

    final reverbPayload = payload['reverbSettings'];
    final track = TrackModel(
      id:
          payload['id'] as String? ??
          'track_${DateTime.now().microsecondsSinceEpoch}',
      name: payload['name'] as String? ?? 'Audio',
      volume: (payload['volume'] as num? ?? 1)
          .toDouble()
          .clamp(0, 1)
          .toDouble(),
      pan: (payload['pan'] as num? ?? 0).toDouble().clamp(-1, 1).toDouble(),
      reverb: (payload['reverb'] as num? ?? 0)
          .toDouble()
          .clamp(0, 1)
          .toDouble(),
      reverbSettings: reverbPayload is Map<String, dynamic>
          ? ReverbSettings.fromJson(reverbPayload)
          : ReverbSettings.defaultValue,
      muted: payload['muted'] as bool? ?? false,
      solo: false,
      recordArmed: false,
      mixSelected: payload['mixSelected'] as bool? ?? false,
      fallbackDurationMs:
          (payload['fallbackDurationMs'] as num? ?? _emptyTrackDurationMs)
              .round(),
      clips: clips,
    );
    await Future.wait(
      clips.map((TrackClipModel clip) => _prepareClipForTrack(track, clip)),
    );
    return track;
  }

  String _timestampedName(String prefix, String extension) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    return '$prefix $timestamp.$extension';
  }

  String _safeFileName(String value, String fallback) {
    final withoutPath = value.split(RegExp(r'[\\/]')).last.trim();
    final sanitized = withoutPath
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final trimmed = sanitized.replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _ensureExtension(String fileName, String extension) {
    final normalizedExtension = extension.startsWith('.')
        ? extension.substring(1)
        : extension;
    if (fileName.toLowerCase().endsWith('.$normalizedExtension')) {
      return fileName;
    }
    return '$fileName.$normalizedExtension';
  }

  int _calculateDuration() {
    if (_tracks.isEmpty) {
      return 0;
    }
    return _tracks.fold<int>(0, (int longest, TrackModel track) {
      final int trackEnd = track.hasAudio
          ? track.endMs
          : track.fallbackDurationMs;
      return max(longest, trackEnd);
    });
  }

  Future<void> _syncTrackAudibility() async {
    final bool hasSolo = _tracks.any((TrackModel track) => track.solo);
    await Future.wait(
      _tracks.expand((TrackModel track) {
        final bool effectiveMuted =
            track.muted ||
            (hasSolo && !track.solo) ||
            (_isRecording && track.recordArmed);
        return track.clips.map(
          (TrackClipModel clip) =>
              _audioEngine.setTrackMute(id: clip.id, muted: effectiveMuted),
        );
      }),
    );
  }

  void _appendRecordingPeak(double level) {
    final double safeLevel = level.clamp(0, 1).toDouble();
    _recordingPeaks.add(safeLevel);
    if (_recordingPeaks.length > 4000) {
      _recordingPeaks.removeRange(0, _recordingPeaks.length - 4000);
    }
  }

  void _startRecordingUiTimer() {
    _recordingUiTimer?.cancel();
    _recordingUiTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final startedAt = _recordingStartedAt;
      if (!_isRecording || startedAt == null) {
        return;
      }
      _recordingElapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final int liveRecordingEndMs =
          _recordingStartPositionMs + _recordingElapsedMs;
      _durationMs = max(_calculateDuration(), liveRecordingEndMs);
      _positionMs = max(
        _positionMs,
        liveRecordingEndMs,
      ).clamp(0, _durationMs).toInt();
      notifyListeners();
    });
  }

  void _stopRecordingUiTimer() {
    _recordingUiTimer?.cancel();
    _recordingUiTimer = null;
    _recordingStartedAt = null;
    _recordingElapsedMs = 0;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stopRecordingUiTimer();
    if (_isRecording) {
      _audioEngine.stopRecording();
    }
    super.dispose();
  }
}

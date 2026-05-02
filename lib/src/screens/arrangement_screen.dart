import 'dart:math';

import 'package:flutter/material.dart';

import '../controllers/arrangement_session_controller.dart';
import '../models/track_model.dart';
import '../widgets/timeline_ruler.dart';
import '../widgets/track_lane.dart';
import 'help_screen.dart';

class ArrangementScreen extends StatefulWidget {
  const ArrangementScreen({super.key});

  @override
  State<ArrangementScreen> createState() => _ArrangementScreenState();
}

class _ArrangementScreenState extends State<ArrangementScreen> {
  static const List<double> _speedPresets = <double>[0.5, 1.0, 1.5, 2.0];
  static const double _minZoom = 1;
  static const double _maxZoom = 64;

  late final ArrangementSessionController _controller;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerVerticalScrollController = ScrollController();

  double? _scrubPreviewMs;
  double _zoom = 1;
  bool _moveMode = false;
  bool _syncingVerticalScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = ArrangementSessionController();
    _verticalScrollController.addListener(() {
      _syncVerticalScroll(
        source: _verticalScrollController,
        target: _headerVerticalScrollController,
      );
    });
    _headerVerticalScrollController.addListener(() {
      _syncVerticalScroll(
        source: _headerVerticalScrollController,
        target: _verticalScrollController,
      );
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _headerVerticalScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncVerticalScroll({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_syncingVerticalScroll || !source.hasClients || !target.hasClients) {
      return;
    }
    final double targetOffset = source.offset
        .clamp(0.0, target.position.maxScrollExtent)
        .toDouble();
    if ((target.offset - targetOffset).abs() < 0.5) {
      return;
    }
    _syncingVerticalScroll = true;
    try {
      target.jumpTo(targetOffset);
    } finally {
      _syncingVerticalScroll = false;
    }
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '');
      _showPopupMessage(message, isError: true);
    }
  }

  Future<void> _runGuardedWithMessage(
    Future<Object?> Function() action,
    String message, {
    String Function(Object? result)? successMessage,
  }) async {
    try {
      final result = await action();
      if (result == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      final text = successMessage?.call(result) ?? message;
      _showPopupMessage(text);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorMessage = error.toString().replaceFirst('Exception: ', '');
      _showPopupMessage(errorMessage, isError: true);
    }
  }

  void _showPopupMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFF3A1018)
            : const Color(0xFF071C1A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 96),
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
        closeIconColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isError ? const Color(0xFFFF4D6D) : const Color(0xFF00E0A4),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  double _fitPixelsPerSecond(double viewportWidth) {
    final double durationSeconds = max(_controller.durationMs / 1000, 1);
    return max(1.0, viewportWidth - 8) / durationSeconds;
  }

  void _setZoom(double value) {
    setState(() {
      _zoom = value.clamp(_minZoom, _maxZoom).toDouble();
    });
  }

  double _zoomStep(double value) {
    if (value < 4) {
      return 0.5;
    }
    if (value < 16) {
      return 2;
    }
    return 8;
  }

  void _openReverbSettings(TrackModel track) {
    var draftSettings = track.reverbSettings;

    void applySettings(ReverbSettings settings) {
      draftSettings = settings;
      _runGuarded(
        () => _controller.setTrackReverbSettings(track.id, draftSettings),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10141A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return _ReverbSettingsSheet(
              trackName: track.name,
              settings: draftSettings,
              onPresetSelected: (ReverbPreset preset) {
                setSheetState(() {
                  draftSettings = preset.settings;
                });
                applySettings(preset.settings);
              },
              onSettingsChanged: (ReverbSettings settings) {
                setSheetState(() {
                  draftSettings = settings.copyWith(presetId: 'custom');
                });
                applySettings(draftSettings);
              },
            );
          },
        );
      },
    );
  }

  void _openHelp() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen()));
  }

  Future<String?> _promptFileName({
    required String title,
    required String label,
    required String initialValue,
    required String extensionHint,
    String? helperText,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10141A),
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: label,
              helperText: helperText ?? 'Extension: $extensionHint',
              suffixText: extensionHint,
            ),
            onSubmitted: (_) {
              Navigator.of(context).pop(controller.text);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<Object?> _saveSessionWithName() async {
    final fileName = await _promptFileName(
      title: 'Save Session',
      label: 'Session file name',
      initialValue: 'music_daw_session',
      extensionHint: '.json',
    );
    if (fileName == null) {
      return null;
    }
    return _controller.saveSession(fileName: fileName);
  }

  Future<Object?> _loadSessionWithName() async {
    final fileName = await _promptFileName(
      title: 'Load Session',
      label: 'Session file name',
      initialValue: 'music_daw_session',
      extensionHint: '.json',
    );
    if (fileName == null) {
      return null;
    }
    return _controller.loadSession(fileName: fileName);
  }

  Future<Object?> _mixSelectedWithName() async {
    final fileName = await _promptFileName(
      title: 'Mix Tracks',
      label: 'MP3 file name',
      initialValue: 'pinewave_mix',
      extensionHint: '.mp3',
    );
    if (fileName == null) {
      return null;
    }
    return _controller.mixSelectedTracks(outputFileName: fileName);
  }

  Future<Object?> _splitSelectedWithName() async {
    final baseName = await _promptFileName(
      title: 'Split Vocal / Backing',
      label: 'Base file name',
      initialValue: 'pinewave_split',
      extensionHint: '_vocals.mp3 / _backing.mp3',
      helperText: 'Creates two files using this base name.',
    );
    if (baseName == null) {
      return null;
    }
    return _controller.separateSelectedTracks(outputBaseName: baseName);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final int displayPositionMs =
            (_scrubPreviewMs ?? _controller.positionMs.toDouble()).round();

        return Scaffold(
          backgroundColor: const Color(0xFF050608),
          body: Stack(
            children: <Widget>[
              SafeArea(
                child: Column(
                  children: <Widget>[
                    _StudioTopBar(
                      isImporting: _controller.isImporting,
                      trackCount: _controller.tracks.length,
                      canMix: _controller.hasMixSelection,
                      canSplit: _controller.hasSplittableSelection,
                      onAddTrack: _controller.addEmptyTrack,
                      onOpenFiles: () => _runGuarded(_controller.importTracks),
                      onSaveSession: () => _runGuardedWithMessage(
                        _saveSessionWithName,
                        'Session saved.',
                        successMessage: (Object? path) =>
                            'Session saved: $path',
                      ),
                      onLoadSession: () => _runGuardedWithMessage(
                        _loadSessionWithName,
                        'Session loaded.',
                        successMessage: (Object? path) =>
                            'Session loaded: $path',
                      ),
                      onMixSelected: () => _runGuardedWithMessage(
                        _mixSelectedWithName,
                        'Selected tracks mixed to an MP3 file.',
                        successMessage: (Object? path) =>
                            'Mixed MP3 saved: $path',
                      ),
                      onSplitSelected: () => _runGuardedWithMessage(
                        _splitSelectedWithName,
                        'Vocal and backing MP3 files created.',
                        successMessage: (Object? path) =>
                            'Split MP3 files saved in: $path',
                      ),
                      onHelp: _openHelp,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                        child: _controller.hasTracks
                            ? _ArrangementDeck(
                                tracks: _controller.tracks,
                                durationMs: _controller.durationMs,
                                positionMs: displayPositionMs,
                                zoom: _zoom,
                                moveMode: _moveMode,
                                isPlaying: _controller.isPlaying,
                                isRecording: _controller.isRecording,
                                recordingStartPositionMs:
                                    _controller.recordingStartPositionMs,
                                recordingElapsedMs:
                                    _controller.recordingElapsedMs,
                                recordingLevel: _controller.recordingLevel,
                                recordingPeaks: _controller.recordingPeaks,
                                minZoom: _minZoom,
                                maxZoom: _maxZoom,
                                horizontalController:
                                    _horizontalScrollController,
                                verticalController: _verticalScrollController,
                                headerVerticalController:
                                    _headerVerticalScrollController,
                                fitPixelsPerSecond: _fitPixelsPerSecond,
                                onZoomChanged: _setZoom,
                                onZoomOut: () =>
                                    _setZoom(_zoom - _zoomStep(_zoom)),
                                onZoomIn: () =>
                                    _setZoom(_zoom + _zoomStep(_zoom)),
                                onFit: () => _setZoom(1),
                                onMoveModeChanged: (bool value) {
                                  setState(() {
                                    _moveMode = value;
                                  });
                                },
                                onSeek: (double fraction) => _runGuarded(
                                  () => _controller.seekTo(
                                    (_controller.durationMs * fraction).round(),
                                  ),
                                ),
                                onClearAudio: (TrackModel track) => _runGuarded(
                                  () => _controller.clearTrackAudio(track.id),
                                ),
                                onLoadFile: (TrackModel track) => _runGuarded(
                                  () =>
                                      _controller.importClipIntoTrack(track.id),
                                ),
                                onMuteChanged: (TrackModel track, bool muted) =>
                                    _runGuarded(
                                      () => _controller.setTrackMuted(
                                        track.id,
                                        muted,
                                      ),
                                    ),
                                onSoloChanged: (TrackModel track, bool solo) =>
                                    _runGuarded(
                                      () => _controller.setTrackSolo(
                                        track.id,
                                        solo,
                                      ),
                                    ),
                                onRecordArmedChanged:
                                    (TrackModel track, bool recordArmed) {
                                      _controller.setTrackRecordArmed(
                                        track.id,
                                        recordArmed,
                                      );
                                    },
                                onMixSelectedChanged:
                                    (TrackModel track, bool selected) {
                                      _controller.setTrackMixSelected(
                                        track.id,
                                        selected,
                                      );
                                    },
                                onVolumeChanged:
                                    (TrackModel track, double value) =>
                                        _runGuarded(
                                          () => _controller.setTrackVolume(
                                            track.id,
                                            value,
                                          ),
                                        ),
                                onPanChanged:
                                    (TrackModel track, double value) =>
                                        _runGuarded(
                                          () => _controller.setTrackPan(
                                            track.id,
                                            value,
                                          ),
                                        ),
                                onReverbChanged:
                                    (TrackModel track, double value) =>
                                        _runGuarded(
                                          () => _controller.setTrackReverb(
                                            track.id,
                                            value,
                                          ),
                                        ),
                                onReverbDetails: _openReverbSettings,
                                onDeleteTrack: (TrackModel track) =>
                                    _runGuarded(
                                      () => _controller.removeTrack(track.id),
                                    ),
                                onMoveByMs: (TrackModel track, int deltaMs) =>
                                    _runGuarded(
                                      () => _controller.moveTrackBy(
                                        track.id,
                                        deltaMs,
                                      ),
                                    ),
                              )
                            : _EmptyState(
                                onAddTrack: _controller.addEmptyTrack,
                                onOpenFiles: () =>
                                    _runGuarded(_controller.importTracks),
                              ),
                      ),
                    ),
                    _BottomTransportDock(
                      isPlaying: _controller.isPlaying,
                      isRecording: _controller.isRecording,
                      hasTracks: _controller.hasTracks,
                      canRecord:
                          _controller.hasRecordArmedTrack ||
                          _controller.isRecording,
                      currentPositionMs: displayPositionMs,
                      totalDurationMs: _controller.durationMs,
                      speed: _controller.speed,
                      speedPresets: _speedPresets,
                      onPlayPause: () =>
                          _runGuarded(_controller.togglePlayback),
                      onStop: () => _runGuarded(_controller.stopPlayback),
                      onRecord: () => _runGuarded(_controller.toggleRecording),
                      onSeekStart: () {
                        setState(() {
                          _scrubPreviewMs = _controller.positionMs.toDouble();
                        });
                      },
                      onSeekChanged: (double value) {
                        setState(() {
                          _scrubPreviewMs = value;
                        });
                      },
                      onSeekEnd: (double value) async {
                        setState(() {
                          _scrubPreviewMs = null;
                        });
                        await _runGuarded(
                          () => _controller.seekTo(value.round()),
                        );
                      },
                      onSpeedSelected: (double value) =>
                          _runGuarded(() => _controller.setSpeed(value)),
                    ),
                  ],
                ),
              ),
              if (_controller.isImporting)
                _LoadingOverlay(
                  message: _controller.loadingMessage ?? 'Working...',
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: const Color(0xAA050608),
          child: Center(
            child: Container(
              width: 230,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF11161D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF26303B)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x8800E0A4),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox.square(
                    dimension: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF00E0A4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Please wait...',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioTopBar extends StatelessWidget {
  const _StudioTopBar({
    required this.isImporting,
    required this.trackCount,
    required this.canMix,
    required this.canSplit,
    required this.onAddTrack,
    required this.onOpenFiles,
    required this.onSaveSession,
    required this.onLoadSession,
    required this.onMixSelected,
    required this.onSplitSelected,
    required this.onHelp,
  });

  final bool isImporting;
  final int trackCount;
  final bool canMix;
  final bool canSplit;
  final VoidCallback onAddTrack;
  final VoidCallback onOpenFiles;
  final VoidCallback onSaveSession;
  final VoidCallback onLoadSession;
  final VoidCallback onMixSelected;
  final VoidCallback onSplitSelected;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 58,
      color: const Color(0xFF050608),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
              'assets/branding/pinewave_icon.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PineWave',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$trackCount tracks',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Add empty track',
            onPressed: onAddTrack,
            icon: const Icon(Icons.add_box_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Open files',
            onPressed: isImporting ? null : onOpenFiles,
            icon: isImporting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Help',
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          PopupMenuButton<_ProjectAction>(
            tooltip: 'Project actions',
            enabled: !isImporting,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (_ProjectAction action) {
              switch (action) {
                case _ProjectAction.save:
                  onSaveSession();
                  break;
                case _ProjectAction.load:
                  onLoadSession();
                  break;
                case _ProjectAction.mix:
                  onMixSelected();
                  break;
                case _ProjectAction.split:
                  onSplitSelected();
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<_ProjectAction>>[
                const PopupMenuItem<_ProjectAction>(
                  value: _ProjectAction.save,
                  child: Text('Save session'),
                ),
                const PopupMenuItem<_ProjectAction>(
                  value: _ProjectAction.load,
                  child: Text('Load session'),
                ),
                PopupMenuItem<_ProjectAction>(
                  value: _ProjectAction.mix,
                  enabled: canMix,
                  child: const Text('Mix selected (.mp3)'),
                ),
                PopupMenuItem<_ProjectAction>(
                  value: _ProjectAction.split,
                  enabled: canSplit,
                  child: const Text('Split vocal/backing (.mp3)'),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

enum _ProjectAction { save, load, mix, split }

class _ArrangementDeck extends StatelessWidget {
  const _ArrangementDeck({
    required this.tracks,
    required this.durationMs,
    required this.positionMs,
    required this.zoom,
    required this.moveMode,
    required this.isPlaying,
    required this.isRecording,
    required this.recordingStartPositionMs,
    required this.recordingElapsedMs,
    required this.recordingLevel,
    required this.recordingPeaks,
    required this.minZoom,
    required this.maxZoom,
    required this.horizontalController,
    required this.verticalController,
    required this.headerVerticalController,
    required this.fitPixelsPerSecond,
    required this.onZoomChanged,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFit,
    required this.onMoveModeChanged,
    required this.onSeek,
    required this.onClearAudio,
    required this.onLoadFile,
    required this.onMuteChanged,
    required this.onSoloChanged,
    required this.onRecordArmedChanged,
    required this.onMixSelectedChanged,
    required this.onVolumeChanged,
    required this.onPanChanged,
    required this.onReverbChanged,
    required this.onReverbDetails,
    required this.onDeleteTrack,
    required this.onMoveByMs,
  });

  final List<TrackModel> tracks;
  final int durationMs;
  final int positionMs;
  final double zoom;
  final bool moveMode;
  final bool isPlaying;
  final bool isRecording;
  final int recordingStartPositionMs;
  final int recordingElapsedMs;
  final double recordingLevel;
  final List<double> recordingPeaks;
  final double minZoom;
  final double maxZoom;
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final ScrollController headerVerticalController;
  final double Function(double viewportWidth) fitPixelsPerSecond;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFit;
  final ValueChanged<bool> onMoveModeChanged;
  final ValueChanged<double> onSeek;
  final ValueChanged<TrackModel> onClearAudio;
  final ValueChanged<TrackModel> onLoadFile;
  final void Function(TrackModel track, bool muted) onMuteChanged;
  final void Function(TrackModel track, bool solo) onSoloChanged;
  final void Function(TrackModel track, bool recordArmed) onRecordArmedChanged;
  final void Function(TrackModel track, bool selected) onMixSelectedChanged;
  final void Function(TrackModel track, double value) onVolumeChanged;
  final void Function(TrackModel track, double value) onPanChanged;
  final void Function(TrackModel track, double value) onReverbChanged;
  final ValueChanged<TrackModel> onReverbDetails;
  final ValueChanged<TrackModel> onDeleteTrack;
  final void Function(TrackModel track, int deltaMs) onMoveByMs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double timelineHeight = 30;
        const double timelineGap = 2;
        final double viewportWidth = max(240, constraints.maxWidth - 20);
        final double timelineViewportWidth = max(
          120,
          viewportWidth - trackHeaderWidth,
        );
        final double pixelsPerSecond =
            fitPixelsPerSecond(timelineViewportWidth) * zoom;
        final double arrangementWidth = max(
          timelineViewportWidth,
          (durationMs / 1000) * pixelsPerSecond,
        );
        final bool hasSolo = tracks.any((TrackModel value) => value.solo);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF090B10),
            border: Border.all(color: const Color(0xFF23262C)),
          ),
          child: Column(
            children: <Widget>[
              _ZoomStrip(
                zoom: zoom,
                moveMode: moveMode,
                minZoom: minZoom,
                maxZoom: maxZoom,
                onZoomChanged: onZoomChanged,
                onZoomOut: onZoomOut,
                onZoomIn: onZoomIn,
                onFit: onFit,
                onMoveModeChanged: onMoveModeChanged,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: trackHeaderWidth,
                        child: Column(
                          children: <Widget>[
                            const SizedBox(
                              height: timelineHeight,
                              child: ColoredBox(color: Color(0xFF15181D)),
                            ),
                            const SizedBox(height: timelineGap),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: headerVerticalController,
                                child: Column(
                                  children: <Widget>[
                                    for (final track in tracks) ...<Widget>[
                                      TrackHeaderLane(
                                        track: track,
                                        positionMs: positionMs,
                                        isPlaying: isPlaying,
                                        hasSolo: hasSolo,
                                        moveMode: moveMode,
                                        isRecordingTarget:
                                            isRecording && track.recordArmed,
                                        recordingElapsedMs: recordingElapsedMs,
                                        recordingLevel: recordingLevel,
                                        onLoadFile: () => onLoadFile(track),
                                        onVolumeChanged: (double value) =>
                                            onVolumeChanged(track, value),
                                        onPanChanged: (double value) =>
                                            onPanChanged(track, value),
                                        onReverbChanged: (double value) =>
                                            onReverbChanged(track, value),
                                        onReverbDetails: () =>
                                            onReverbDetails(track),
                                        onMuteChanged: (bool muted) =>
                                            onMuteChanged(track, muted),
                                        onSoloChanged: (bool solo) =>
                                            onSoloChanged(track, solo),
                                        onRecordArmedChanged:
                                            (bool recordArmed) =>
                                                onRecordArmedChanged(
                                                  track,
                                                  recordArmed,
                                                ),
                                        onMixSelectedChanged: (bool selected) =>
                                            onMixSelectedChanged(
                                              track,
                                              selected,
                                            ),
                                        onClearAudio: () => onClearAudio(track),
                                        onDeleteTrack: () =>
                                            onDeleteTrack(track),
                                        onMoveByMs: (int deltaMs) =>
                                            onMoveByMs(track, deltaMs),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            Scrollbar(
                              controller: horizontalController,
                              thumbVisibility: true,
                              notificationPredicate:
                                  (ScrollNotification notification) {
                                    return notification.metrics.axis ==
                                        Axis.horizontal;
                                  },
                              child: SingleChildScrollView(
                                controller: horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: arrangementWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      TimelineRuler(
                                        width: arrangementWidth,
                                        durationMs: durationMs,
                                        positionMs: positionMs,
                                        pixelsPerSecond: pixelsPerSecond,
                                        onSeek: onSeek,
                                      ),
                                      const SizedBox(height: timelineGap),
                                      Expanded(
                                        child: Scrollbar(
                                          controller: verticalController,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: verticalController,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                for (final track
                                                    in tracks) ...<Widget>[
                                                  TrackWaveformLane(
                                                    track: track,
                                                    sessionDurationMs:
                                                        durationMs,
                                                    width: arrangementWidth,
                                                    positionMs: positionMs,
                                                    pixelsPerSecond:
                                                        pixelsPerSecond,
                                                    isPlaying: isPlaying,
                                                    hasSolo: hasSolo,
                                                    moveMode: moveMode,
                                                    isRecordingTarget:
                                                        isRecording &&
                                                        track.recordArmed,
                                                    recordingStartPositionMs:
                                                        recordingStartPositionMs,
                                                    recordingElapsedMs:
                                                        recordingElapsedMs,
                                                    recordingPeaks:
                                                        recordingPeaks,
                                                    onSeek: onSeek,
                                                    onMoveByMs: (int deltaMs) =>
                                                        onMoveByMs(
                                                          track,
                                                          deltaMs,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            _PlayheadOverlay(
                              viewportWidth: timelineViewportWidth,
                              horizontalOffset: horizontalController.hasClients
                                  ? horizontalController.offset
                                  : 0,
                              playheadPositionPx:
                                  (positionMs / 1000) * pixelsPerSecond,
                              topOffset: timelineHeight + timelineGap,
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
        );
      },
    );
  }
}

class _ZoomStrip extends StatelessWidget {
  const _ZoomStrip({
    required this.zoom,
    required this.moveMode,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFit,
    required this.onMoveModeChanged,
  });

  final double zoom;
  final bool moveMode;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFit;
  final ValueChanged<bool> onMoveModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final SliderThemeData sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 2,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
    );

    return SizedBox(
      height: 34,
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Zoom out',
            onPressed: zoom <= minZoom ? null : onZoomOut,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Expanded(
            child: SliderTheme(
              data: sliderTheme,
              child: Slider(
                value: zoom,
                min: minZoom,
                max: maxZoom,
                onChanged: onZoomChanged,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: zoom >= maxZoom ? null : onZoomIn,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
          TextButton(
            onPressed: onFit,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              '${zoom.toStringAsFixed(1)}x',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: moveMode ? 'Move mode on' : 'Move mode off',
            onPressed: () => onMoveModeChanged(!moveMode),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: moveMode
                  ? const Color(0xFF00E0A4)
                  : const Color(0xFF1A1E25),
              foregroundColor: moveMode ? Colors.black : Colors.white70,
            ),
            icon: const Icon(Icons.open_with_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ReverbSettingsSheet extends StatelessWidget {
  const _ReverbSettingsSheet({
    required this.trackName,
    required this.settings,
    required this.onPresetSelected,
    required this.onSettingsChanged,
  });

  final String trackName;
  final ReverbSettings settings;
  final ValueChanged<ReverbPreset> onPresetSelected;
  final ValueChanged<ReverbSettings> onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFF00E0A4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Vocal Reverb',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Presets',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final preset in ReverbSettings.presets)
                    ChoiceChip(
                      label: Text(preset.name),
                      selected: settings.presetId == preset.id,
                      onSelected: (_) => onPresetSelected(preset),
                      selectedColor: const Color(0xFF00E0A4),
                      backgroundColor: const Color(0xFF1B2028),
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: settings.presetId == preset.id
                            ? Colors.black
                            : Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                      side: const BorderSide(color: Color(0xFF303844)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _presetDescription(settings.presetId),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 18),
              _ReverbParameterSlider(
                label: 'Mix',
                valueLabel: '${(settings.mix * 100).round()}%',
                value: settings.mix,
                min: 0,
                max: 1,
                onChanged: (double value) =>
                    onSettingsChanged(settings.copyWith(mix: value)),
              ),
              _ReverbParameterSlider(
                label: 'Room',
                valueLabel: '${(settings.roomSize * 100).round()}%',
                value: settings.roomSize,
                min: 0,
                max: 1,
                onChanged: (double value) =>
                    onSettingsChanged(settings.copyWith(roomSize: value)),
              ),
              _ReverbParameterSlider(
                label: 'Decay',
                valueLabel: '${(settings.decay * 100).round()}%',
                value: settings.decay,
                min: 0,
                max: 1,
                onChanged: (double value) =>
                    onSettingsChanged(settings.copyWith(decay: value)),
              ),
              _ReverbParameterSlider(
                label: 'Damp',
                valueLabel: '${(settings.damp * 100).round()}%',
                value: settings.damp,
                min: 0,
                max: 1,
                onChanged: (double value) =>
                    onSettingsChanged(settings.copyWith(damp: value)),
              ),
              _ReverbParameterSlider(
                label: 'Pre-delay',
                valueLabel: '${settings.preDelayMs.round()} ms',
                value: settings.preDelayMs,
                min: 0,
                max: 120,
                onChanged: (double value) =>
                    onSettingsChanged(settings.copyWith(preDelayMs: value)),
              ),
              _ReverbParameterSlider(
                label: 'Width',
                valueLabel: '${(settings.width * 100).round()}%',
                value: settings.width,
                min: 0,
                max: 1,
                onChanged: (double value) =>
                    onSettingsChanged(settings.copyWith(width: value)),
              ),
              const SizedBox(height: 10),
              Text(
                'Rev 슬라이더는 전체 리버브 양이고, 여기 값들은 리버브의 색깔과 공간감을 정합니다.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _presetDescription(String presetId) {
    for (final preset in ReverbSettings.presets) {
      if (preset.id == presetId) {
        return preset.description;
      }
    }
    return '직접 조정한 커스텀 리버브';
  }
}

class _ReverbParameterSlider extends StatelessWidget {
  const _ReverbParameterSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 46,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF00E0A4),
                inactiveTrackColor: const Color(0xFF303844),
                thumbColor: const Color(0xFF00E0A4),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomTransportDock extends StatelessWidget {
  const _BottomTransportDock({
    required this.isPlaying,
    required this.isRecording,
    required this.hasTracks,
    required this.canRecord,
    required this.currentPositionMs,
    required this.totalDurationMs,
    required this.speed,
    required this.speedPresets,
    required this.onPlayPause,
    required this.onStop,
    required this.onRecord,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onSpeedSelected,
  });

  final bool isPlaying;
  final bool isRecording;
  final bool hasTracks;
  final bool canRecord;
  final int currentPositionMs;
  final int totalDurationMs;
  final double speed;
  final List<double> speedPresets;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onRecord;
  final VoidCallback onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final ValueChanged<double> onSpeedSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double sliderMax = max(1, totalDurationMs).toDouble();
    final double sliderValue = currentPositionMs
        .clamp(0, sliderMax.round())
        .toDouble();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF14161B),
        border: Border(top: BorderSide(color: Color(0xFF2C3038))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  _formatDuration(currentPositionMs),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 8,
                      ),
                    ),
                    child: Slider(
                      value: sliderValue,
                      max: sliderMax,
                      onChangeStart: hasTracks ? (_) => onSeekStart() : null,
                      onChanged: hasTracks ? onSeekChanged : null,
                      onChangeEnd: hasTracks ? onSeekEnd : null,
                    ),
                  ),
                ),
                Text(
                  _formatDuration(totalDurationMs),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const Spacer(),
                _RoundTransportButton(
                  tooltip: 'Stop',
                  onPressed: hasTracks ? onStop : null,
                  icon: Icons.stop_rounded,
                  color: const Color(0xFFE9EEF6),
                  foregroundColor: const Color(0xFF111318),
                ),
                const SizedBox(width: 14),
                _RecordButton(
                  isRecording: isRecording,
                  onPressed: canRecord ? onRecord : null,
                ),
                const SizedBox(width: 14),
                _RoundTransportButton(
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  onPressed: hasTracks ? onPlayPause : null,
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: const Color(0xFF00E0A4),
                  foregroundColor: const Color(0xFF03110D),
                ),
                const Spacer(),
                PopupMenuButton<double>(
                  tooltip: 'Speed',
                  initialValue: speed,
                  onSelected: onSpeedSelected,
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<double>>[
                      for (final preset in speedPresets)
                        PopupMenuItem<double>(
                          value: preset,
                          child: Text('${preset.toStringAsFixed(1)}x'),
                        ),
                    ];
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${speed.toStringAsFixed(1)}x',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundTransportButton extends StatelessWidget {
  const _RoundTransportButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.color,
    required this.foregroundColor,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filled(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          backgroundColor: color,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white38,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.isRecording, required this.onPressed});

  final bool isRecording;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isRecording ? 'Stop recording' : 'Record',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: isRecording ? 52 : 46,
        height: isRecording ? 52 : 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onPressed == null
                ? Colors.white24
                : isRecording
                ? const Color(0xFFFF3355)
                : Colors.white70,
            width: 2,
          ),
          color: isRecording
              ? const Color(0x33FF3355)
              : onPressed == null
              ? const Color(0xFF15171B)
              : const Color(0xFF201012),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            isRecording ? Icons.stop_rounded : Icons.fiber_manual_record,
            color: onPressed == null ? Colors.white24 : const Color(0xFFFF1744),
          ),
        ),
      ),
    );
  }
}

class _PlayheadOverlay extends StatelessWidget {
  const _PlayheadOverlay({
    required this.viewportWidth,
    required this.horizontalOffset,
    required this.playheadPositionPx,
    required this.topOffset,
  });

  final double viewportWidth;
  final double horizontalOffset;
  final double playheadPositionPx;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final double localX = playheadPositionPx - horizontalOffset;
    if (localX < 0 || localX > viewportWidth) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: localX - 1,
      top: topOffset,
      bottom: 0,
      child: IgnorePointer(
        child: Container(width: 2, color: const Color(0xFF11C9FF)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTrack, required this.onOpenFiles});

  final VoidCallback onAddTrack;
  final VoidCallback onOpenFiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF090B10),
        border: Border.all(color: const Color(0xFF23262C)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.multitrack_audio_rounded,
                size: 48,
                color: Color(0xFF00E0A4),
              ),
              const SizedBox(height: 14),
              Text(
                'PineWave',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: onAddTrack,
                    icon: const Icon(Icons.add_box_rounded),
                    label: const Text('Add Track'),
                  ),
                  FilledButton.icon(
                    onPressed: onOpenFiles,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Open Files'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(int milliseconds) {
  final Duration duration = Duration(
    milliseconds: milliseconds.clamp(0, 1 << 31),
  );
  final String minutes = duration.inMinutes
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  final String seconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  if (duration.inHours > 0) {
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

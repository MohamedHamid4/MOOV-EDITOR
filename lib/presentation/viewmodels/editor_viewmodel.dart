import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/entities/clip.dart';
import '../../domain/entities/keyframe.dart';
import '../../domain/entities/project.dart';
import '../../services/export/video_export_service.dart';
import '../../services/video/video_thumbnail_service.dart';

/// Deep snapshot of clip state for undo/redo.
class _EditorSnapshot {
  _EditorSnapshot(List<Clip> clips) : clips = List.from(clips);
  final List<Clip> clips;
}

class EditorViewModel extends ChangeNotifier {
  EditorViewModel({
    required Project project,
    ProjectRepository? repo,
    SettingsRepository? settings,
  })  : _project = project,
        _repo = repo ?? ProjectRepository(),
        _settings = settings ?? SettingsRepository() {
    _undoStack.add(_EditorSnapshot(_project.clips));
    _startAutoSave();
  }

  final ProjectRepository _repo;
  final SettingsRepository _settings;

  Project _project;
  Clip? _selectedClip;
  Duration _playheadPosition = Duration.zero;
  double _zoom = AppConstants.defaultPixelsPerSecond;
  bool _snapEnabled = true;
  bool _propertiesPanelOpen = false;
  int _selectedPropertiesTab = 0;
  bool _isSaving = false;
  String? _saveStatus;
  Timer? _autoSaveTimer;

  /// IDs of clips that are currently in an overlap conflict (shown in red).
  Set<String> _conflictingClipIds = {};

  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];

  // ── Getters ───────────────────────────────────────────────────────────────

  Project get project => _project;
  List<Clip> get clips => _project.clips;
  Clip? get selectedClip => _selectedClip;
  Duration get playheadPosition => _playheadPosition;
  double get zoom => _zoom;
  bool get snapEnabled => _snapEnabled;
  bool get propertiesPanelOpen => _propertiesPanelOpen;
  int get selectedPropertiesTab => _selectedPropertiesTab;
  bool get isSaving => _isSaving;
  String? get saveStatus => _saveStatus;
  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;
  Set<String> get conflictingClipIds => _conflictingClipIds;

  /// Track 0: videos and images (the "Media" track).
  List<Clip> get mediaClips => clips.where((c) => c.trackIndex == 0).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  // Legacy alias used by some widgets.
  List<Clip> get videoClips => mediaClips;

  List<Clip> get audioClips => clips.where((c) => c.trackIndex == 1).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// Track 2: text overlays only.
  List<Clip> get textClips => clips.where((c) => c.trackIndex == 2).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  // Legacy alias.
  List<Clip> get overlayClips => textClips;

  List<Clip> clipsAtTime(Duration t) =>
      clips.where((c) => c.startTime <= t && c.endTime > t).toList();

  Duration get totalDuration => _project.duration;

  // ── Clip operations ───────────────────────────────────────────────────────

  Future<void> addVideoClip(String filePath) async {
    final id = const Uuid().v4();
    final newStartTime = _nextStartTime(0);
    _mutate((clips) => clips..add(Clip(
      id: id,
      type: ClipType.video,
      trackIndex: 0,
      startTime: newStartTime,
      duration: const Duration(seconds: 5),
      sourceIn: Duration.zero,
      sourceOut: const Duration(seconds: 5),
      filePath: filePath,
    )));
    _fetchVideoMetadata(id, filePath);
  }

  void _fetchVideoMetadata(String clipId, String filePath) async {
    final durationMs = await VideoExportService.getVideoDurationMs(filePath) ?? 5000;
    final thumbPath = await VideoThumbnailService.generateThumbnail(
      videoPath: filePath,
      positionMs: 0,
    );
    _updateClip(clipId, (c) => c.copyWith(
      duration: Duration(milliseconds: durationMs),
      sourceOut: Duration(milliseconds: durationMs),
      thumbnailPath: thumbPath,
    ));
  }

  Future<void> addAudioClip(String filePath) async {
    final id = const Uuid().v4();
    final newStartTime = _nextStartTime(1);
    _mutate((clips) => clips..add(Clip(
      id: id,
      type: ClipType.audio,
      trackIndex: 1,
      startTime: newStartTime,
      duration: const Duration(seconds: 5),
      filePath: filePath,
    )));
    _fetchAudioMetadata(id, filePath);
  }

  void _fetchAudioMetadata(String clipId, String filePath) async {
    final durationMs = await VideoExportService.getVideoDurationMs(filePath) ?? 5000;
    _updateClip(clipId, (c) => c.copyWith(
      duration: Duration(milliseconds: durationMs),
    ));
  }

  Future<void> addImageClip(String filePath) async {
    final newStartTime = _nextStartTime(0);
    final clip = Clip(
      id: const Uuid().v4(),
      type: ClipType.image,
      trackIndex: 0,
      startTime: newStartTime,
      duration: const Duration(seconds: 5),
      sourceIn: Duration.zero,
      sourceOut: const Duration(seconds: 5),
      filePath: filePath,
      thumbnailPath: filePath,
    );
    _mutate((clips) => clips..add(clip));
  }

  /// Creates a text clip starting at the playhead.
  /// Position defaults to centre (kf.x=0, kf.y=0, normalized −1…1).
  void addTextClip({
    String text = 'Text',
    double fontSize = 48,
    String colorHex = '#FFFFFF',
  }) {
    const initialKf = Keyframe(timeMs: 0, x: 0, y: 0, scale: 1.0, opacity: 1.0);
    final clip = Clip(
      id: const Uuid().v4(),
      type: ClipType.text,
      trackIndex: 2,
      startTime: _playheadPosition,
      duration: const Duration(seconds: 5),
      keyframes: [initialKf],
      textData: TextClipData(text: text, fontSize: fontSize, colorHex: colorHex),
    );
    _mutate((clips) => clips..add(clip));
    selectClip(clip.id);
    openPropertiesPanel(tab: 0);
  }

  /// Moves a clip in real-time during a drag gesture without pushing an undo state.
  /// Call [commitClipMove] on drag end to push a snapshot.
  void movingClip(String id, Duration newStart, int trackIndex) {
    final clamped = Duration(
        milliseconds: newStart.inMilliseconds.clamp(0, 3600000));
    final snapped =
        _snapEnabled ? _snapTime(clamped, excludeId: id) : clamped;

    final mutable = List<Clip>.from(_project.clips);
    final idx = mutable.indexWhere((c) => c.id == id);
    if (idx == -1) return;

    final moving = mutable[idx];
    final end = snapped + moving.duration;

    final conflicts = mutable
        .where((c) =>
            c.id != id &&
            c.trackIndex == trackIndex &&
            c.startTime < end &&
            c.endTime > snapped)
        .toList();

    _conflictingClipIds = conflicts.isEmpty
        ? {}
        : {id, ...conflicts.map((c) => c.id)};

    mutable[idx] = moving.copyWith(startTime: snapped, trackIndex: trackIndex);
    _project = _project
        .copyWith(clips: mutable, updatedAt: DateTime.now())
        .withRecalculatedDuration();
    notifyListeners();
  }

  /// Commits the current clip positions as a new undo snapshot after a drag ends.
  void commitClipMove(String id) {
    _conflictingClipIds = {};
    _undoStack.add(_EditorSnapshot(_project.clips));
    if (_undoStack.length > AppConstants.maxUndoHistory) _undoStack.removeAt(0);
    _redoStack.clear();
    notifyListeners();
  }

  void moveClip(String id, Duration newStart, int newTrack) {
    final candidate = _snapEnabled ? _snapTime(newStart, excludeId: id) : newStart;
    final moving = clips.firstWhere((c) => c.id == id, orElse: () => clips.first);
    final candidateEnd = candidate + moving.duration;

    // Detect overlaps on the target track.
    final conflicts = clips
        .where((c) =>
            c.id != id &&
            c.trackIndex == newTrack &&
            c.startTime < candidateEnd &&
            c.endTime > candidate)
        .toList();

    if (conflicts.isNotEmpty) {
      // Highlight conflicts; snap to the nearest non-overlapping position.
      _conflictingClipIds = {id, ...conflicts.map((c) => c.id)};
      notifyListeners();
      return;
    }

    _conflictingClipIds = {};
    _mutate((clips) {
      final idx = clips.indexWhere((c) => c.id == id);
      if (idx == -1) return;
      clips[idx] = clips[idx].copyWith(startTime: candidate, trackIndex: newTrack);
    });
  }

  /// Clears the overlap-conflict highlight set (call after drag ends).
  void clearConflicts() {
    if (_conflictingClipIds.isEmpty) return;
    _conflictingClipIds = {};
    notifyListeners();
  }

  void trimClip(String id, {Duration? newSourceIn, Duration? newSourceOut}) {
    _mutate((clips) {
      final idx = clips.indexWhere((c) => c.id == id);
      if (idx == -1) return;
      final c = clips[idx];
      final srcIn = newSourceIn ?? c.sourceIn;
      final srcOut = newSourceOut ?? c.sourceOut;
      final newDuration = srcOut - srcIn;
      if (newDuration.inMilliseconds <= 100) return;
      clips[idx] = c.copyWith(
        sourceIn: srcIn,
        sourceOut: srcOut,
        duration: Duration(
          milliseconds: (newDuration.inMilliseconds / c.speed).round(),
        ),
      );
    });
  }

  void splitClipAtPlayhead() {
    final active = clips.where((c) =>
        c.startTime < _playheadPosition && c.endTime > _playheadPosition);
    if (active.isEmpty) return;

    _mutate((clips) {
      final toSplit = active.toList();
      for (final clip in toSplit) {
        final localTime = _playheadPosition - clip.startTime;
        final srcSplit = clip.sourceIn + localTime;

        final left = clip.copyWith(
          sourceOut: srcSplit,
          duration: localTime,
        );
        final right = clip.copyWith(
          id: const Uuid().v4(),
          startTime: _playheadPosition,
          sourceIn: srcSplit,
          duration: clip.endTime - _playheadPosition,
        );

        final idx = clips.indexWhere((c) => c.id == clip.id);
        clips[idx] = left;
        clips.add(right);
      }
    });
  }

  void deleteClip(String id) {
    _mutate((clips) => clips.removeWhere((c) => c.id == id));
    if (_selectedClip?.id == id) {
      _selectedClip = null;
      _propertiesPanelOpen = false;
    }
  }

  void duplicateClip(String id) {
    final src = clips.firstWhere((c) => c.id == id);
    final copy = src.copyWith(
      id: const Uuid().v4(),
      startTime: src.endTime,
    );
    _mutate((clips) => clips..add(copy));
  }

  void setClipSpeed(String id, double speed) {
    _mutate((clips) {
      final idx = clips.indexWhere((c) => c.id == id);
      if (idx == -1) return;
      final c = clips[idx];
      final sourceDur = c.sourceOut - c.sourceIn;
      clips[idx] = c.copyWith(
        speed: speed,
        duration: Duration(
          milliseconds: (sourceDur.inMilliseconds / speed).round(),
        ),
      );
    });
  }

  void setClipVolume(String id, double volume) {
    _updateClip(id, (c) => c.copyWith(volume: volume));
  }

  void setColorFilter(String id, ClipColorFilter filter) {
    _updateClip(id, (c) => c.copyWith(colorFilter: filter));
  }

  void setTransitionIn(String id, ClipTransition t) {
    _updateClip(id, (c) => c.copyWith(transitionIn: t));
  }

  void setTransitionOut(String id, ClipTransition t) {
    _updateClip(id, (c) => c.copyWith(transitionOut: t));
  }

  void setTextData(String id, TextClipData data) {
    _updateClip(id, (c) => c.copyWith(textData: data));
  }

  // ── Keyframes ─────────────────────────────────────────────────────────────

  /// Creates or updates a keyframe at the current playhead for the selected clip.
  void upsertKeyframeAtPlayhead({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
  }) {
    if (_selectedClip == null) return;
    final localMs = (_playheadPosition - _selectedClip!.startTime).inMilliseconds;
    if (localMs < 0) return;

    _mutate((clips) {
      final idx = clips.indexWhere((c) => c.id == _selectedClip!.id);
      if (idx == -1) return;
      final clip = clips[idx];
      final existing = clip.keyframes.indexWhere((k) => k.timeMs == localMs);

      final Keyframe kf;
      if (existing != -1) {
        final prev = clip.keyframes[existing];
        kf = prev.copyWith(
          x: x ?? prev.x,
          y: y ?? prev.y,
          scale: scale ?? prev.scale,
          rotation: rotation ?? prev.rotation,
          opacity: opacity ?? prev.opacity,
        );
        final updated = List<Keyframe>.from(clip.keyframes)..[existing] = kf;
        clips[idx] = clip.copyWith(keyframes: updated);
      } else {
        final interpolated = KeyframeInterpolator.interpolateAt(
          keyframes: clip.keyframes,
          localTimeMs: localMs,
        );
        kf = interpolated.copyWith(
          timeMs: localMs,
          x: x ?? interpolated.x,
          y: y ?? interpolated.y,
          scale: scale ?? interpolated.scale,
          rotation: rotation ?? interpolated.rotation,
          opacity: opacity ?? interpolated.opacity,
        );
        clips[idx] = clip.copyWith(
          keyframes: List.from(clip.keyframes)..add(kf),
        );
      }
      _selectedClip = clips[idx];
    });
  }

  void deleteKeyframe(String clipId, int timeMs) {
    _mutate((clips) {
      final idx = clips.indexWhere((c) => c.id == clipId);
      if (idx == -1) return;
      final clip = clips[idx];
      final updated = clip.keyframes.where((k) => k.timeMs != timeMs).toList();
      clips[idx] = clip.copyWith(keyframes: updated);
      if (_selectedClip?.id == clipId) _selectedClip = clips[idx];
    });
  }

  void setKeyframeEasing(String clipId, int timeMs, EasingCurve easing) {
    _mutate((clips) {
      final idx = clips.indexWhere((c) => c.id == clipId);
      if (idx == -1) return;
      final clip = clips[idx];
      final kfIdx = clip.keyframes.indexWhere((k) => k.timeMs == timeMs);
      if (kfIdx == -1) return;
      final updated = List<Keyframe>.from(clip.keyframes)
        ..[kfIdx] = clip.keyframes[kfIdx].copyWith(easing: easing);
      clips[idx] = clip.copyWith(keyframes: updated);
      if (_selectedClip?.id == clipId) _selectedClip = clips[idx];
    });
  }

  /// Returns the interpolated transform for [clip] at [playheadPosition].
  Keyframe getInterpolatedTransform(Clip clip) {
    final localMs = (_playheadPosition - clip.startTime).inMilliseconds;
    return KeyframeInterpolator.interpolateAt(
      keyframes: clip.keyframes,
      localTimeMs: localMs.clamp(0, clip.duration.inMilliseconds),
    );
  }

  // ── Selection & UI state ─────────────────────────────────────────────────

  void selectClip(String? id) {
    _selectedClip = id == null ? null : clips.firstWhere((c) => c.id == id, orElse: () => clips.first);
    notifyListeners();
  }

  void openPropertiesPanel({int tab = 0}) {
    _propertiesPanelOpen = true;
    _selectedPropertiesTab = tab;
    notifyListeners();
  }

  void closePropertiesPanel() {
    _propertiesPanelOpen = false;
    notifyListeners();
  }

  void setPropertiesTab(int tab) {
    _selectedPropertiesTab = tab;
    notifyListeners();
  }

  void setPlayheadPosition(Duration pos) {
    final ms = pos.inMilliseconds.clamp(0, totalDuration.inMilliseconds);
    _playheadPosition = Duration(milliseconds: ms);
    notifyListeners();
  }

  void setZoom(double zoom) {
    _zoom = zoom.clamp(AppConstants.minPixelsPerSecond, AppConstants.maxPixelsPerSecond);
    notifyListeners();
  }

  void toggleSnap() {
    _snapEnabled = !_snapEnabled;
    notifyListeners();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  void undo() {
    if (!canUndo) return;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    _applySnapshot(_undoStack.last);
  }

  void redo() {
    if (!canRedo) return;
    final snap = _redoStack.removeLast();
    _undoStack.add(snap);
    _applySnapshot(snap);
  }

  void _applySnapshot(_EditorSnapshot snap) {
    _project = _project.copyWith(clips: List.from(snap.clips)).withRecalculatedDuration();
    _selectedClip = null;
    notifyListeners();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _startAutoSave() async {
    final enabled = await _settings.getAutoSave();
    if (!enabled) return;
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: AppConstants.autoSaveIntervalSeconds),
      (_) => saveProject(),
    );
  }

  Future<void> saveProject() async {
    _isSaving = true;
    _saveStatus = 'Saving…';
    notifyListeners();
    try {
      await _repo.save(_project);
      _saveStatus = 'Saved ✓';
    } catch (_) {
      _saveStatus = 'Save failed';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void renameProject(String name) {
    _project = _project.copyWith(name: name.trim(), updatedAt: DateTime.now());
    notifyListeners();
    saveProject();
  }

  Future<void> syncToCloud() async {
    await _repo.syncToCloud(_project);
    _project = _project.copyWith(cloudSynced: true);
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _mutate(void Function(List<Clip> clips) fn) {
    final mutable = List<Clip>.from(_project.clips);
    fn(mutable);
    _project = _project
        .copyWith(clips: mutable, updatedAt: DateTime.now())
        .withRecalculatedDuration();

    _undoStack.add(_EditorSnapshot(mutable));
    if (_undoStack.length > AppConstants.maxUndoHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
    notifyListeners();
  }

  void _updateClip(String id, Clip Function(Clip) updater) {
    _mutate((clips) {
      final idx = clips.indexWhere((c) => c.id == id);
      if (idx == -1) return;
      clips[idx] = updater(clips[idx]);
      if (_selectedClip?.id == id) _selectedClip = clips[idx];
    });
  }

  /// Finds the next available start time on [trackIndex] with no overlap.
  Duration _nextStartTime(int trackIndex) {
    final trackClips = clips.where((c) => c.trackIndex == trackIndex).toList();
    if (trackClips.isEmpty) return Duration.zero;
    trackClips.sort((a, b) => a.endTime.compareTo(b.endTime));
    return trackClips.last.endTime;
  }

  Duration _snapTime(Duration t, {String? excludeId}) {
    const threshold = Duration(milliseconds: 200);
    Duration snapped = t;

    // Snap to second boundaries
    final secs = Duration(seconds: t.inSeconds);
    if ((t - secs).abs() < threshold) snapped = secs;

    // Snap to other clips' edges
    for (final c in clips) {
      if (c.id == excludeId) continue;
      if ((t - c.startTime).abs() < threshold) snapped = c.startTime;
      if ((t - c.endTime).abs() < threshold) snapped = c.endTime;
    }

    // Snap to playhead
    if ((_playheadPosition - t).abs() < threshold) snapped = _playheadPosition;

    return snapped;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:libtorrent_bridge/libtorrent_bridge.dart';
import '../models/torrent_models.dart';

class TorrentManager extends ChangeNotifier {
  final LibtorrentBridge _bridge = LibtorrentBridge();
  StreamSubscription<String>? _subscription;

  List<TorrentSnapshot> _torrents = [];
  bool _initialized = false;
  String _downloadPath = '';

  // Set of torrent infoHashes added by the user that are waiting for file selection
  final Set<String> _pendingSelectionHashes = {};
  
  // The current torrent that needs file selection dialog displayed in the UI
  TorrentSnapshot? _activeSelectionTarget;

  List<TorrentSnapshot> get torrents => _torrents;
  bool get isInitialized => _initialized;
  String get downloadPath => _downloadPath;
  TorrentSnapshot? get activeSelectionTarget => _activeSelectionTarget;

  // Global session download & upload speeds
  int get totalDownloadRate => _torrents.fold(0, (sum, t) => sum + t.downloadRate);
  int get totalUploadRate => _torrents.fold(0, (sum, t) => sum + t.uploadRate);

  /// Initializes the torrent session by preparing the directories.
  /// Downloads are put directly in the Documents directory so they show up in iOS Files App.
  /// Metadata and resume databases are hidden in the Library directory to keep the Files App folder clean.
  Future<void> initSession() async {
    if (_initialized) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      _downloadPath = docDir.path;

      final libDir = await getLibraryDirectory();
      final torrentsDir = Directory('${libDir.path}/.torrents');
      final resumeDir = Directory('${libDir.path}/.resume');

      if (!await torrentsDir.exists()) {
        await torrentsDir.create(recursive: true);
      }
      if (!await resumeDir.exists()) {
        await resumeDir.create(recursive: true);
      }

      await _bridge.startSession(
        downloadPath: _downloadPath,
        torrentsPath: torrentsDir.path,
        fastResumePath: resumeDir.path,
      );

      _subscription = _bridge.torrentsStream.listen(_onTorrentsUpdate);
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing torrent session: $e');
    }
  }

  /// Adds a torrent magnet link to the engine.
  Future<void> addMagnetLink(String magnetUrl) async {
    if (!_initialized) await initSession();
    
    try {
      final cleanUrl = magnetUrl.trim();
      if (!cleanUrl.startsWith('magnet:?')) {
        throw Exception('Invalid magnet URL format');
      }

      final infoHash = await _bridge.addTorrent(cleanUrl);
      final normalizedHash = infoHash.toLowerCase();
      
      // Mark this torrent as waiting for metadata and file selection
      _pendingSelectionHashes.add(normalizedHash);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding magnet link: $e');
      rethrow;
    }
  }

  /// Starts downloading the selected files by indices, configuring engine priority and resuming the torrent.
  Future<void> startDownload(String infoHash, List<int> selectedIndices) async {
    final normalizedHash = infoHash.toLowerCase();
    _pendingSelectionHashes.remove(normalizedHash);
    if (_activeSelectionTarget?.infoHash.toLowerCase() == normalizedHash) {
      _activeSelectionTarget = null;
    }

    await _bridge.setFilesPriority(infoHash, selectedIndices);
    await _bridge.resumeTorrent(infoHash);
    notifyListeners();
  }

  /// Discards the torrent without downloading anything.
  Future<void> cancelDownload(String infoHash) async {
    final normalizedHash = infoHash.toLowerCase();
    _pendingSelectionHashes.remove(normalizedHash);
    if (_activeSelectionTarget?.infoHash.toLowerCase() == normalizedHash) {
      _activeSelectionTarget = null;
    }
    
    await removeTorrent(infoHash, deleteFiles: true);
  }

  /// Pause download.
  Future<void> pauseTorrent(String infoHash) async {
    await _bridge.pauseTorrent(infoHash);
  }

  /// Resume download.
  Future<void> resumeTorrent(String infoHash) async {
    await _bridge.resumeTorrent(infoHash);
  }

  /// Remove torrent from the session, optionally deleting downloaded files.
  Future<void> removeTorrent(String infoHash, {required bool deleteFiles}) async {
    final normalizedHash = infoHash.toLowerCase();
    _pendingSelectionHashes.remove(normalizedHash);
    if (_activeSelectionTarget?.infoHash.toLowerCase() == normalizedHash) {
      _activeSelectionTarget = null;
    }

    await _bridge.removeTorrent(infoHash, deleteFiles);
    _torrents.removeWhere((t) => t.infoHash.toLowerCase() == normalizedHash);
    notifyListeners();
  }

  /// Clears the currently displayed selection target after the UI shows the bottom sheet.
  void clearActiveSelectionTarget() {
    _activeSelectionTarget = null;
    notifyListeners();
  }

  void _onTorrentsUpdate(String jsonString) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final updatedTorrents = decoded
          .map((item) => TorrentSnapshot.fromJson(item as Map<String, dynamic>))
          .toList();

      _torrents = updatedTorrents;

      // Check if any pending torrent has fetched metadata and needs file selection
      for (final torrent in _torrents) {
        final hash = torrent.infoHash.toLowerCase();
        if (_pendingSelectionHashes.contains(hash) && torrent.hasMetadata) {
          // Found a torrent that just completed fetching metadata!
          // We set it as the active target for the UI selection sheet
          _activeSelectionTarget = torrent;
          _pendingSelectionHashes.remove(hash);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing torrents update: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

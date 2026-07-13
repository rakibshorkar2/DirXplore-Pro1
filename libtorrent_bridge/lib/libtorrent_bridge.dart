import 'dart:async';
import 'package:flutter/services.dart';

class LibtorrentBridge {
  static const MethodChannel _methodChannel = MethodChannel('libtorrent_bridge/methods');
  static const EventChannel _eventChannel = EventChannel('libtorrent_bridge/events');

  /// Starts the torrent session with the given directories.
  Future<void> startSession({
    required String downloadPath,
    required String torrentsPath,
    required String fastResumePath,
  }) async {
    await _methodChannel.invokeMethod('startSession', {
      'downloadPath': downloadPath,
      'torrentsPath': torrentsPath,
      'fastResumePath': fastResumePath,
    });
  }

  /// Adds a magnet link. Returns the torrent infoHash.
  Future<String> addTorrent(String magnetUrl) async {
    final String infoHash = await _methodChannel.invokeMethod('addTorrent', {
      'magnetUrl': magnetUrl,
    }) as String;
    return infoHash;
  }

  /// Pauses a torrent.
  Future<void> pauseTorrent(String infoHash) async {
    await _methodChannel.invokeMethod('pauseTorrent', {
      'infoHash': infoHash,
    });
  }

  /// Resumes a torrent.
  Future<void> resumeTorrent(String infoHash) async {
    await _methodChannel.invokeMethod('resumeTorrent', {
      'infoHash': infoHash,
    });
  }

  /// Removes a torrent, optionally deleting downloaded files.
  Future<void> removeTorrent(String infoHash, bool deleteFiles) async {
    await _methodChannel.invokeMethod('removeTorrent', {
      'infoHash': infoHash,
      'deleteFiles': deleteFiles,
    });
  }

  /// Configures file priorities (Selected files get default priority (4), unselected get dontDownload (0)).
  Future<void> setFilesPriority(String infoHash, List<int> selectedIndices) async {
    await _methodChannel.invokeMethod('setFilesPriority', {
      'infoHash': infoHash,
      'selectedIndices': selectedIndices,
    });
  }

  /// Stream of JSON-serialized torrent status updates.
  Stream<String> get torrentsStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event as String);
  }
}

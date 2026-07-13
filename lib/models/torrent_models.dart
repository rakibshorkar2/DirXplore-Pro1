enum TorrentState {
  checkingFiles,
  downloadingMetadata,
  downloading,
  finished,
  seeding,
  checkingResumeData,
  paused,
  storageError,
  unknown
}

class TorrentFileEntry {
  final int index;
  final String name;
  final String path;
  final int size;
  final int downloaded;
  final int priority; // 0 = dont download, >0 = download

  TorrentFileEntry({
    required this.index,
    required this.name,
    required this.path,
    required this.size,
    required this.downloaded,
    required this.priority,
  });

  bool get isSelected => priority > 0;
  double get progress => size > 0 ? downloaded / size : 0.0;

  factory TorrentFileEntry.fromJson(Map<String, dynamic> json) {
    return TorrentFileEntry(
      index: json['index'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      downloaded: json['downloaded'] as int? ?? 0,
      priority: json['priority'] as int? ?? 0,
    );
  }
}

class TorrentSnapshot {
  final String infoHash;
  final String name;
  final TorrentState state;
  final double progress;
  final double progressWanted;
  final int numberOfPeers;
  final int numberOfSeeds;
  final int downloadRate; // bytes/sec
  final int uploadRate; // bytes/sec
  final bool hasMetadata;
  final int total;
  final int totalDone;
  final int totalWanted;
  final int totalWantedDone;
  final bool isPaused;
  final bool isFinished;
  final bool isSeed;
  final List<TorrentFileEntry> files;

  TorrentSnapshot({
    required this.infoHash,
    required this.name,
    required this.state,
    required this.progress,
    required this.progressWanted,
    required this.numberOfPeers,
    required this.numberOfSeeds,
    required this.downloadRate,
    required this.uploadRate,
    required this.hasMetadata,
    required this.total,
    required this.totalDone,
    required this.totalWanted,
    required this.totalWantedDone,
    required this.isPaused,
    required this.isFinished,
    required this.isSeed,
    required this.files,
  });

  String get stateString {
    switch (state) {
      case TorrentState.checkingFiles:
        return 'Checking files';
      case TorrentState.downloadingMetadata:
        return 'Fetching metadata';
      case TorrentState.downloading:
        return 'Downloading';
      case TorrentState.finished:
        return 'Finished';
      case TorrentState.seeding:
        return 'Seeding';
      case TorrentState.checkingResumeData:
        return 'Checking resume data';
      case TorrentState.paused:
        return 'Paused';
      case TorrentState.storageError:
        return 'Storage error';
      case TorrentState.unknown:
        return 'Unknown';
    }
  }

  // Calculate remaining download time in seconds
  int? get eta {
    if (downloadRate <= 0) return null;
    final remainingBytes = totalWanted - totalWantedDone;
    if (remainingBytes <= 0) return 0;
    return (remainingBytes / downloadRate).ceil();
  }

  factory TorrentSnapshot.fromJson(Map<String, dynamic> json) {
    final stateStr = json['state'] as String? ?? 'unknown';
    TorrentState tState;
    switch (stateStr) {
      case 'checkingFiles':
        tState = TorrentState.checkingFiles;
        break;
      case 'downloadingMetadata':
        tState = TorrentState.downloadingMetadata;
        break;
      case 'downloading':
        tState = TorrentState.downloading;
        break;
      case 'finished':
        tState = TorrentState.finished;
        break;
      case 'seeding':
        tState = TorrentState.seeding;
        break;
      case 'checkingResumeData':
        tState = TorrentState.checkingResumeData;
        break;
      case 'paused':
        tState = TorrentState.paused;
        break;
      case 'storageError':
        tState = TorrentState.storageError;
        break;
      default:
        tState = TorrentState.unknown;
    }

    final filesJson = json['files'] as List<dynamic>? ?? [];
    final filesList = filesJson
        .map((f) => TorrentFileEntry.fromJson(f as Map<String, dynamic>))
        .toList();

    return TorrentSnapshot(
      infoHash: json['infoHash'] as String? ?? '',
      name: json['name'] as String? ?? '',
      state: tState,
      progress: (json['progress'] as num? ?? 0.0).toDouble(),
      progressWanted: (json['progressWanted'] as num? ?? 0.0).toDouble(),
      numberOfPeers: json['numberOfPeers'] as int? ?? 0,
      numberOfSeeds: json['numberOfSeeds'] as int? ?? 0,
      downloadRate: json['downloadRate'] as int? ?? 0,
      uploadRate: json['uploadRate'] as int? ?? 0,
      hasMetadata: json['hasMetadata'] as bool? ?? false,
      total: json['total'] as int? ?? 0,
      totalDone: json['totalDone'] as int? ?? 0,
      totalWanted: json['totalWanted'] as int? ?? 0,
      totalWantedDone: json['totalWantedDone'] as int? ?? 0,
      isPaused: json['isPaused'] as bool? ?? false,
      isFinished: json['isFinished'] as bool? ?? false,
      isSeed: json['isSeed'] as bool? ?? false,
      files: filesList,
    );
  }
}

import Flutter
import UIKit
import LibTorrent

public class LibtorrentBridgePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var session: Session?
  private var eventSink: FlutterEventSink?
  private var updateTimer: Timer?
  private let queue = DispatchQueue(label: "com.dirxplorerakib.pro.libtorrent_bridge")
  
  // Track torrents where we have already auto-configured priorities to zero upon metadata retrieval
  private var prioritiesInitialized = Set<String>()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LibtorrentBridgePlugin()
    
    let methodChannel = FlutterMethodChannel(name: "libtorrent_bridge/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    
    let eventChannel = FlutterEventChannel(name: "libtorrent_bridge/events", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    
    switch call.method {
    case "startSession":
      guard let downloadPath = args?["downloadPath"] as? String,
            let torrentsPath = args?["torrentsPath"] as? String,
            let fastResumePath = args?["fastResumePath"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing session paths", details: nil))
        return
      }
      startSession(downloadPath: downloadPath, torrentsPath: torrentsPath, fastResumePath: fastResumePath)
      result(nil)
      
    case "addTorrent":
      guard let magnetUrl = args?["magnetUrl"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing magnetUrl", details: nil))
        return
      }
      addTorrent(magnetUrl: magnetUrl, result: result)
      
    case "pauseTorrent":
      guard let infoHash = args?["infoHash"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash", details: nil))
        return
      }
      pauseTorrent(infoHash: infoHash)
      result(nil)
      
    case "resumeTorrent":
      guard let infoHash = args?["infoHash"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing infoHash", details: nil))
        return
      }
      resumeTorrent(infoHash: infoHash)
      result(nil)
      
    case "removeTorrent":
      guard let infoHash = args?["infoHash"] as? String,
            let deleteFiles = args?["deleteFiles"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters for removeTorrent", details: nil))
        return
      }
      removeTorrent(infoHash: infoHash, deleteFiles: deleteFiles)
      result(nil)
      
    case "setFilesPriority":
      guard let infoHash = args?["infoHash"] as? String,
            let selectedIndices = args?["selectedIndices"] as? [Int] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing parameters for setFilesPriority", details: nil))
        return
      }
      setFilesPriority(infoHash: infoHash, selectedIndices: selectedIndices)
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Stream Handler (EventChannel)
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    startTimer()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    stopTimer()
    return nil
  }

  // MARK: - Timer Control
  private func startTimer() {
    guard updateTimer == nil else { return }
    updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.queue.async {
        self?.sendUpdatesToFlutter()
      }
    }
  }

  private func stopTimer() {
    updateTimer?.invalidate()
    updateTimer = nil
  }

  // MARK: - Engine Functions
  private func startSession(downloadPath: String, torrentsPath: String, fastResumePath: String) {
    let downloadURL = URL(fileURLWithPath: downloadPath)
    let torrentsURL = URL(fileURLWithPath: torrentsPath)
    let fastResumeURL = URL(fileURLWithPath: fastResumePath)

    let settings = Session.Settings()
    settings.port = 6881
    settings.maxActiveTorrents = 12
    settings.maxDownloadingTorrents = 6
    settings.isDhtEnabled = true
    settings.isLsdEnabled = true
    settings.isUtpEnabled = true
    settings.isUpnpEnabled = true
    settings.isNatEnabled = true
    
    // Efficiency options
    settings.preallocateStorage = false 

    self.session = Session(initWith: downloadURL, torrentsPath: torrentsURL, fastResumePath: fastResumeURL, settings: settings, storages: [:])
    self.session?.addDelegate(self)
  }

  private func addTorrent(magnetUrl: String, result: @escaping FlutterResult) {
    guard let session = session else {
      result(FlutterError(code: "NO_SESSION", message: "Session is not initialized", details: nil))
      return
    }
    
    guard let encodedUrl = magnetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let magnetURL = URL(string: encodedUrl) else {
      result(FlutterError(code: "INVALID_URL", message: "Could not parse magnet URL", details: nil))
      return
    }

    let magnet = MagnetURI(unsafeWithMagnetURI: magnetURL)
    if let handle = session.addTorrent(magnet) {
      let infoHash = (handle.infoHashes.best as Data).hex
      handle.updateSnapshot()
      result(infoHash)
    } else {
      result(FlutterError(code: "ADD_FAILED", message: "Engine failed to add magnet link", details: nil))
    }
  }

  private func pauseTorrent(infoHash: String) {
    findTorrent(infoHash: infoHash)?.pause()
    sendUpdatesToFlutter()
  }

  private func resumeTorrent(infoHash: String) {
    findTorrent(infoHash: infoHash)?.resume()
    sendUpdatesToFlutter()
  }

  private func removeTorrent(infoHash: String, deleteFiles: Bool) {
    let lowerInfoHash = infoHash.lowercased()
    prioritiesInitialized.remove(lowerInfoHash)
    
    if let handle = findTorrent(infoHash: infoHash) {
      session?.removeTorrent(handle, deleteFiles: deleteFiles)
    }
    sendUpdatesToFlutter()
  }

  private func setFilesPriority(infoHash: String, selectedIndices: [Int]) {
    guard let handle = findTorrent(infoHash: infoHash) else { return }
    let selectedSet = Set(selectedIndices)
    let snapshot = handle.snapshot
    
    if snapshot.isValid && snapshot.hasMetadata {
      // Mark as initialized so our automatic check doesn't overwrite this selection
      let lowerInfoHash = infoHash.lowercased()
      prioritiesInitialized.insert(lowerInfoHash)
      
      for file in snapshot.files {
        let isSelected = selectedSet.contains(Int(file.index))
        let priorityVal: UInt8 = isSelected ? 4 : 0 // 4 = default, 0 = dont download
        let priority = FileEntry.Priority(rawValue: priorityVal) ?? .dontDownload
        handle.setFilePriority(priority, at: NSInteger(file.index))
      }
    }
    sendUpdatesToFlutter()
  }

  private func findTorrent(infoHash: String) -> TorrentHandle? {
    return session?.torrents.first { (($0.infoHashes.best as Data).hex).lowercased() == infoHash.lowercased() }
  }

  // MARK: - Serialization & Updates
  private func sendUpdatesToFlutter() {
    guard let eventSink = eventSink, let session = session else { return }
    
    var torrentsArray: [[String: Any]] = []
    for torrent in session.torrents {
      torrent.updateSnapshot()
      
      let infoHash = (torrent.infoHashes.best as Data).hex.lowercased()
      
      // Check if this torrent has just fetched metadata, but we haven't set its priorities yet.
      // If so, zero-out all files priority and pause it immediately so it doesn't download files automatically.
      if torrent.snapshot.hasMetadata && !prioritiesInitialized.contains(infoHash) {
        torrent.setAllFilesPriority(.dontDownload)
        torrent.pause()
        prioritiesInitialized.insert(infoHash)
        torrent.updateSnapshot() // Refresh snapshot with new state
      }

      if let dict = serializeTorrent(torrent) {
        torrentsArray.append(dict)
      }
    }
    
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: torrentsArray, options: [])
      if let jsonString = String(data: jsonData, encoding: .utf8) {
        DispatchQueue.main.async {
          eventSink(jsonString)
        }
      }
    } catch {
      print("Error serializing torrents: \(error)")
    }
  }

  private func serializeTorrent(_ handle: TorrentHandle) -> [String: Any]? {
    let snapshot = handle.snapshot
    guard snapshot.isValid else { return nil }
    
    let infoHash = (handle.infoHashes.best as Data).hex
    
    var stateStr = "unknown"
    switch snapshot.state {
    case .checkingFiles: stateStr = "checkingFiles"
    case .downloadingMetadata: stateStr = "downloadingMetadata"
    case .downloading: stateStr = "downloading"
    case .finished: stateStr = "finished"
    case .seeding: stateStr = "seeding"
    case .checkingResumeData: stateStr = "checkingResumeData"
    case .paused: stateStr = "paused"
    case .storageError: stateStr = "storageError"
    @unknown default: stateStr = "unknown"
    }
    
    var filesList: [[String: Any]] = []
    if snapshot.hasMetadata {
      for file in snapshot.files {
        filesList.append([
          "index": file.index,
          "name": file.name,
          "path": file.path,
          "size": file.size,
          "downloaded": file.downloaded,
          "priority": file.priority.rawValue
        ])
      }
    }
    
    let dict: [String: Any] = [
      "infoHash": infoHash,
      "name": snapshot.name,
      "state": stateStr,
      "progress": snapshot.progress,
      "progressWanted": snapshot.progressWanted,
      "numberOfPeers": snapshot.numberOfPeers,
      "numberOfSeeds": snapshot.numberOfSeeds,
      "downloadRate": snapshot.downloadRate,
      "uploadRate": snapshot.uploadRate,
      "hasMetadata": snapshot.hasMetadata,
      "total": snapshot.total,
      "totalDone": snapshot.totalDone,
      "totalWanted": snapshot.totalWanted,
      "totalWantedDone": snapshot.totalWantedDone,
      "isPaused": snapshot.isPaused,
      "isFinished": snapshot.isFinished,
      "isSeed": snapshot.isSeed,
      "files": filesList
    ]
    
    return dict
  }
}

// MARK: - SessionDelegate
extension LibtorrentBridgePlugin: SessionDelegate {
  public func torrentManager(_ manager: Session, didAddTorrent torrent: TorrentHandle) {
    queue.async {
      self.sendUpdatesToFlutter()
    }
  }

  public func torrentManager(_ manager: Session, didRemoveTorrentWithHash hashesData: TorrentHashes) {
    queue.async {
      self.sendUpdatesToFlutter()
    }
  }

  public func torrentManager(_ manager: Session, didReceiveUpdateForTorrent torrent: TorrentHandle) {
    // Relying on 1 Hz timer to throttle updates and keep battery/CPU/GPU usage to a minimum.
  }

  public func torrentManager(_ manager: Session, didErrorOccur error: Error) {
    print("LibTorrent Error occurred: \(error)")
  }
}

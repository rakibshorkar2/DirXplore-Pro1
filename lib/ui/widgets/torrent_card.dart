import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/torrent_models.dart';

class TorrentCard extends StatelessWidget {
  final TorrentSnapshot torrent;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  const TorrentCard({
    super.key,
    required this.torrent,
    required this.onTap,
    required this.onPlayPause,
  });

  // Format bytes per second
  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = 0;
    double speed = bytesPerSec.toDouble();
    while (speed >= 1024 && i < suffixes.length - 1) {
      speed /= 1024;
      i++;
    }
    return '${speed.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Format bytes to human size
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Format remaining time
  String _formatEta(int? seconds) {
    if (seconds == null || seconds < 0) return '--:--';
    if (seconds > 86400 * 7) return '∞';
    
    final duration = Duration(seconds: seconds);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Color _getStatusColor() {
    switch (torrent.state) {
      case TorrentState.downloading:
        return const Color(0xFF6C5CE7);
      case TorrentState.finished:
      case TorrentState.seeding:
        return const Color(0xFF00FF87);
      case TorrentState.paused:
        return Colors.white.withOpacity(0.4);
      case TorrentState.downloadingMetadata:
        return Colors.amberAccent;
      case TorrentState.storageError:
        return Colors.redAccent;
      default:
        return Colors.white.withOpacity(0.7);
    }
  }

  IconData _getStatusIcon() {
    switch (torrent.state) {
      case TorrentState.downloading:
        return Icons.cloud_download_outlined;
      case TorrentState.finished:
      case TorrentState.seeding:
        return Icons.check_circle_outline;
      case TorrentState.paused:
        return Icons.pause_circle_outline;
      case TorrentState.downloadingMetadata:
        return Icons.wifi_tethering;
      case TorrentState.storageError:
        return Icons.warning_amber_rounded;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final pct = (torrent.progress * 100).toStringAsFixed(1);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F2F).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Play/Pause Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              torrent.name.isNotEmpty ? torrent.name : (torrent.hasMetadata ? 'Unnamed Torrent' : 'Fetching Metadata...'),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Status row
                            Row(
                              children: [
                                Icon(
                                  _getStatusIcon(),
                                  color: statusColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  torrent.stateString,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                                if (torrent.state == TorrentState.downloading && torrent.eta != null) ...[
                                  Text(
                                    '  •  ETA: ',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                  Text(
                                    _formatEta(torrent.eta),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Play/Pause Action
                      IconButton(
                        onPressed: onPlayPause,
                        icon: Icon(
                          torrent.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: torrent.isPaused ? const Color(0xFF00FF87) : Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.04),
                          padding: const EdgeInsets.all(8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar & Stats
                  if (torrent.hasMetadata) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatBytes(torrent.totalWantedDone)} / ${_formatBytes(torrent.totalWanted)}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: torrent.progressWanted.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          torrent.state == TorrentState.paused
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFF6C5CE7),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ] else ...[
                    // Metadata fetch progress
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                        minHeight: 4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Speeds and Peers info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // DL Speed
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_circle_down_outlined,
                            color: torrent.downloadRate > 0 ? const Color(0xFF6C5CE7) : Colors.white.withOpacity(0.3),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatSpeed(torrent.downloadRate),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: torrent.downloadRate > 0 ? Colors.white : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                      // UL Speed
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_circle_up_outlined,
                            color: torrent.uploadRate > 0 ? const Color(0xFF00FF87) : Colors.white.withOpacity(0.3),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatSpeed(torrent.uploadRate),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: torrent.uploadRate > 0 ? Colors.white : Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                      // Peers info
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.white.withOpacity(0.3),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'S: ${torrent.numberOfSeeds} • P: ${torrent.numberOfPeers}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
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

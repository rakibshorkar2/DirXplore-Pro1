import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/torrent_models.dart';
import '../../services/torrent_manager.dart';

class TorrentDetailSheet extends StatefulWidget {
  final String infoHash;

  const TorrentDetailSheet({
    super.key,
    required this.infoHash,
  });

  @override
  State<TorrentDetailSheet> createState() => _TorrentDetailSheetState();
}

class _TorrentDetailSheetState extends State<TorrentDetailSheet> {
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

  // Share finished files
  void _shareFile(TorrentFileEntry file, String downloadDirectory) {
    final filePath = '$downloadDirectory/${file.path}';
    final ioFile = File(filePath);
    
    if (ioFile.existsSync()) {
      Share.shareXFiles([XFile(filePath)], text: 'Share ${file.name}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File is not fully downloaded yet or does not exist at path: ${file.name}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Delete Dialog
  void _showDeleteDialog(BuildContext context, TorrentManager manager, TorrentSnapshot torrent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Torrent',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove this torrent?',
          style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.6))),
          ),
          TextButton(
            onPressed: () {
              manager.removeTorrent(torrent.infoHash, deleteFiles: false);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close sheet
            },
            child: Text(
              'Remove Torrent Only',
              style: GoogleFonts.outfit(color: Colors.amberAccent, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              manager.removeTorrent(torrent.infoHash, deleteFiles: true);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close sheet
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(
              'Remove Torrent & Files',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TorrentManager>(context);
    
    // Find torrent in latest active list
    final torrentList = manager.torrents.where((t) => t.infoHash.toLowerCase() == widget.infoHash.toLowerCase());
    if (torrentList.isEmpty) {
      return Container(
        height: 100,
        color: const Color(0xFF12131C),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final torrent = torrentList.first;
    final pct = (torrent.progress * 100).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12131C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Torrent title and state
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  torrent.name.isNotEmpty ? torrent.name : 'Fetching Metadata...',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showDeleteDialog(context, manager, torrent),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hash: ${torrent.infoHash.toUpperCase()}',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.white.withOpacity(0.25),
            ),
          ),
          const SizedBox(height: 16),

          // Action bar (Pause / Resume)
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      if (torrent.isPaused) {
                        manager.resumeTorrent(torrent.infoHash);
                      } else {
                        manager.pauseTorrent(torrent.infoHash);
                      }
                    },
                    icon: Icon(
                      torrent.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: torrent.isPaused ? const Color(0xFF00FF87) : Colors.amberAccent,
                      size: 18,
                    ),
                    label: Text(
                      torrent.isPaused ? 'Resume Torrent' : 'Pause Torrent',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Statistics Grid
          Row(
            children: [
              _buildStatCard('Speed', _formatSpeed(torrent.downloadRate), Icons.arrow_circle_down_outlined, const Color(0xFF6C5CE7)),
              const SizedBox(width: 12),
              _buildStatCard('Progress', '$pct%', Icons.percent, const Color(0xFF00FF87)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Total Size', _formatBytes(torrent.total), Icons.storage, Colors.amberAccent),
              const SizedBox(width: 12),
              _buildStatCard('Peers', 'S: \${torrent.numberOfSeeds} • P: \${torrent.numberOfPeers}', Icons.people_outline, Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 20),

          // File section header
          Text(
            'Downloaded Files',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),

          // File List
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
              child: torrent.hasMetadata
                  ? ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: torrent.files.length,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.white.withOpacity(0.03),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final file = torrent.files[index];
                        final isSelected = file.isSelected;
                        final isFinished = file.downloaded == file.size && file.size > 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? (isFinished ? Icons.check_box_outlined : Icons.download_outlined)
                                    : Icons.remove_circle_outline,
                                color: isSelected
                                    ? (isFinished ? const Color(0xFF00FF87) : const Color(0xFF6C5CE7))
                                    : Colors.white.withOpacity(0.2),
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: file.progress,
                                          backgroundColor: Colors.white.withOpacity(0.03),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isFinished ? const Color(0xFF00FF87) : const Color(0xFF6C5CE7),
                                          ),
                                          minHeight: 3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatBytes(file.size),
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  if (isSelected)
                                    Text(
                                      '${(file.progress * 100).toStringAsFixed(0)}%',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                ],
                              ),
                              // Share button for finished files
                              if (isFinished) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _shareFile(file, manager.downloadPath),
                                  icon: const Icon(Icons.share_outlined, size: 14, color: Color(0xFFa8a3ff)),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.04),
                                    padding: const EdgeInsets.all(6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Waiting for torrent metadata...',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ).animate().slideY(begin: 0.1, duration: 250.ms, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

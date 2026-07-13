import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/torrent_manager.dart';
import 'widgets/torrent_card.dart';
import 'widgets/file_select_sheet.dart';
import 'widgets/torrent_detail_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _magnetController = TextEditingController();

  @override
  void dispose() {
    _magnetController.dispose();
    super.dispose();
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

  // Dialog to paste magnet link
  void _showAddMagnetSheet(BuildContext context, TorrentManager manager) async {
    _magnetController.clear();
    
    // Auto-detect clipboard data for quick paste
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      final text = clipboardData.text!.trim();
      if (text.startsWith('magnet:?')) {
        _magnetController.text = text;
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Text(
              'Add Torrent Link',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste a magnet link to start fetching metadata',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _magnetController,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'magnet:?xt=urn:btih:...',
                hintStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.2)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF6C5CE7)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFa8a3ff)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final magnet = _magnetController.text.trim();
                  if (magnet.isNotEmpty) {
                    Navigator.pop(context);
                    try {
                      await manager.addMagnetLink(magnet);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Added magnet link. Fetching metadata...'),
                            backgroundColor: Colors.amber,
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Add Torrent',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 0.1, duration: 250.ms, curve: Curves.easeOutQuad),
    );
  }

  void _showDetailSheet(BuildContext context, String infoHash) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TorrentDetailSheet(infoHash: infoHash),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TorrentManager>(context);

    // Watch for automatic popup triggers when metadata finishes loading
    if (manager.activeSelectionTarget != null) {
      final target = manager.activeSelectionTarget!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Clear active target immediately to prevent loops
        manager.clearActiveSelectionTarget();
        
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withOpacity(0.5),
          builder: (context) => FileSelectSheet(
            torrent: target,
            onDownload: (indices) {
              manager.startDownload(target.infoHash, indices);
              Navigator.pop(context);
            },
            onCancel: () {
              manager.cancelDownload(target.infoHash);
              Navigator.pop(context);
            },
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      body: Stack(
        children: [
          // Background Glows (using radial soft containers)
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6C5CE7).withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FF87).withOpacity(0.04),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DirXplore Pro',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'iPhone 15 Pro Edition',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6C5CE7),
                            ),
                          ),
                        ],
                      ),
                      // Battery saver indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF87).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00FF87).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: Color(0xFF00FF87),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Eco Mode',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF00FF87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Global Speed / Stats Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1F2F).withOpacity(0.8),
                          const Color(0xFF12131C).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Down Speed
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_circle_down_outlined,
                                    color: Color(0xFF6C5CE7),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Download',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatSpeed(manager.totalDownloadRate),
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Divider
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        const SizedBox(width: 16),
                        // Up Speed
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_circle_up_outlined,
                                    color: Color(0xFF00FF87),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Upload',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatSpeed(manager.totalUploadRate),
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 350.ms).slideY(begin: 0.05),
                  const SizedBox(height: 24),

                  // Torrent List Header
                  Text(
                    'Active Downloads',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scrollable List
                  Expanded(
                    child: manager.torrents.isEmpty
                        ? _buildEmptyState(context, manager)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: manager.torrents.length,
                            itemBuilder: (context, index) {
                              final torrent = manager.torrents[index];
                              return TorrentCard(
                                torrent: torrent,
                                onTap: () => _showDetailSheet(context, torrent.infoHash),
                                onPlayPause: () {
                                  if (torrent.isPaused) {
                                    manager.resumeTorrent(torrent.infoHash);
                                  } else {
                                    manager.pauseTorrent(torrent.infoHash);
                                  }
                                },
                              ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.02);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFa8a3ff)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddMagnetSheet(context, manager),
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildEmptyState(BuildContext context, TorrentManager manager) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dynamic pulsing container
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.04),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.link_rounded,
              size: 48,
              color: const Color(0xFF6C5CE7).withOpacity(0.6),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1500.ms, curve: Curves.easeInOut),
          const SizedBox(height: 24),
          Text(
            'No Active Torrents',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the plus button below to paste a magnet link and begin downloading to your iPhone.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white.withOpacity(0.4),
                height: 1.5,
              ),
            ),
          ),
        ],
      ).animate().fade(duration: 400.ms),
    );
  }
}

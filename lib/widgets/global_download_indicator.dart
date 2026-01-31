import 'package:flutter/material.dart';
import '../services/download_manager.dart';

const kOrangeGradient = LinearGradient(
  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class GlobalDownloadIndicator extends StatelessWidget {
  const GlobalDownloadIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadManager = DownloadManager();

    return StreamBuilder<DownloadProgress?>(
      stream: downloadManager.progressStream,
      builder: (context, snapshot) {
        final download = snapshot.data;

        if (download == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildModernDownloadUI(download),
        );
      },
    );
  }

  Widget _buildModernDownloadUI(DownloadProgress download) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0), // No margin - sits on nav bar
      decoration: BoxDecoration(
        gradient: _getStatusGradient(download.status),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ultra-thin progress bar
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: download.progress,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          
          // Super minimal status row - almost invisible
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _getModernStatusIcon(download.status),
                const SizedBox(width: 8),
                Text(
                  download.statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (download.status != DownloadStatus.completed &&
                    download.status != DownloadStatus.failed) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${(download.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getModernStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
      case DownloadStatus.watermarking:
      case DownloadStatus.saving:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        );
      case DownloadStatus.completed:
        return Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: Color(0xFF4CAF50),
            size: 10,
          ),
        );
      case DownloadStatus.failed:
        return Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close,
            color: Color(0xFFF44336),
            size: 10,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  LinearGradient _getStatusGradient(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case DownloadStatus.failed:
        return const LinearGradient(
          colors: [Color(0xFFF44336), Color(0xFFE57373)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return kOrangeGradient;
    }
  }
}
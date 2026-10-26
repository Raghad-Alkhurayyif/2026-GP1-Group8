import 'package:flutter/material.dart';

import '../services/analysis_notice.dart';
import '../theme/mata_theme.dart';

/// A quiet panel that says what went wrong and what to try next.
class AnalysisNoticeCard extends StatelessWidget {
  const AnalysisNoticeCard({required this.notice, this.onDismiss, super.key});

  final AnalysisNotice notice;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return MataGlass(
      radius: 18,
      opacity: 0.82,
      borderColor: MataColors.amber.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: MataColors.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: MataText.body(
                    color: MataColors.cocoa,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notice.message,
                  style: MataText.body(
                    color: MataColors.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  notice.suggestion,
                  style: MataText.body(
                    color: MataColors.brown,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 6, 8),
                child: Icon(
                  Icons.close_rounded,
                  color: MataColors.faint,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

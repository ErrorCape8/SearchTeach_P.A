import 'package:flutter/material.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../notifications/notifications_page.dart';

const kAdminOrange = Color(0xFFEA580C);
const kAdminOrangeDark = Color(0xFFC2410C);

class AdminHeader extends StatelessWidget {
  const AdminHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.isEditing = false,
    this.onBack,
    this.showLogo = true,
  });

  final String title;
  final String subtitle;
  final bool isEditing;
  final VoidCallback? onBack;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: kAdminOrange,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF57A1B),
            Color(0xFFEA580C),
            Color(0xFFC75C14),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 12),
            child: Row(
              children: [
                if (isEditing) ...[
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ] else if (showLogo) ...[
                  Container(
                    width: 92,
                    height: 58,
                    alignment: Alignment.center,
                    child: const BrandLogo(width: 92, height: 58),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const NotificationBellButton(accentColor: kAdminOrange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

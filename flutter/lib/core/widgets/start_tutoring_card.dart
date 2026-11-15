import 'package:flutter/material.dart';
import '../neu/neu.dart';

class StartTutoringCard extends StatelessWidget {
  const StartTutoringCard({
    required this.subject,
    required this.timeLabel,
    required this.modalityLabel,
    required this.attendeesLabel,
    required this.accentColor,
    required this.buttonLabel,
    required this.onAction,
    this.actionIcon,
    super.key,
  });

  final String subject;
  final String timeLabel;
  final String modalityLabel;
  final String attendeesLabel;
  final Color accentColor;
  final String buttonLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12141E3C),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            subject,
                            style: neuPoppins(
                              size: 16,
                              weight: FontWeight.w700,
                              color: Neu.heading,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: Neu.muted),
                              const SizedBox(width: 7),
                              Text(timeLabel,
                                  style: neuBody(size: 13, color: Neu.muted)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 15, color: Neu.muted),
                              const SizedBox(width: 7),
                              Text(modalityLabel,
                                  style: neuBody(size: 13, color: Neu.muted)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.people_outline_rounded,
                                  size: 15, color: Neu.muted),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  attendeesLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: neuBody(size: 13, color: Neu.muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 13),
                        elevation: 1,
                      ),
                      child: Text(
                        buttonLabel,
                        style: neuPoppins(
                          size: 13,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

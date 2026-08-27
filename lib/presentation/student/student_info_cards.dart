import 'package:flutter/material.dart';

/// Short contextual safety guidance shown beneath the core transport action.
/// Safety content is intentionally visually distinct from paid placements.
class SafetyTipCard extends StatelessWidget {
  const SafetyTipCard({super.key});

  static const _tips = <String>[
    'Wait inside the designated boarding area and away from moving traffic.',
    'Allow passengers to alight before boarding the shuttle.',
    'At night, wait in a well-lit area and stay near other students where possible.',
    'Keep phones and valuables secure while boarding and alighting.',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Safety tip',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(tip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reserved, clearly labelled advertising placement.
///
/// No personal trip data is exposed to advertisers. A future backend can
/// choose a campaign from coarse campus zones and return aggregate campaign
/// analytics only.
class SponsoredSlotCard extends StatelessWidget {
  const SponsoredSlotCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.campaign_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sponsored',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  const Text('Campus partner offers will appear here.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

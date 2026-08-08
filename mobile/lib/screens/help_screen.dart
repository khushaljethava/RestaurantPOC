import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('How to refund', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Open the receipt → Refund. Manager PIN required for staff. Partial refunds pick lines.'),
          SizedBox(height: 16),
          Text('How to settle', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Settlement → mark settled → counterparty confirms received.'),
          SizedBox(height: 16),
          Text('Who to call', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Ask your stall owner/manager. Platform support: support@example.com'),
        ],
      ),
    );
  }
}

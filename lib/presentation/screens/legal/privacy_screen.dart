import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          'Privacy Policy\n\n'
          'Last updated: January 2025\n\n'
          '1. Information We Collect\n\n'
          'Moov Editor collects the following information:\n'
          '• Account information: email address and display name when you register.\n'
          '• Usage data: anonymous analytics to improve the App (no personally '
          'identifiable information is sent).\n'
          '• Device information: device model and OS version for crash reporting.\n\n'
          '2. How We Use Your Information\n\n'
          'We use your information to:\n'
          '• Provide and maintain your account.\n'
          '• Save and sync your projects (if cloud sync is enabled).\n'
          '• Improve and personalise your experience.\n'
          '• Send important service updates.\n\n'
          '3. Data Storage\n\n'
          'Your projects and media are stored locally on your device. If you enable '
          'cloud sync, project metadata is stored in Firebase Firestore. We do not '
          'sell your data to third parties.\n\n'
          '4. Third-Party Services\n\n'
          'The App uses the following third-party services:\n'
          '• Firebase (Google) — authentication and optional cloud storage.\n'
          '• Google Sign-In — optional authentication method.\n\n'
          '5. Your Rights\n\n'
          'You may request deletion of your account and associated data at any time '
          'by contacting support@moov-editor.com. Local data can be deleted by '
          'uninstalling the App.\n\n'
          '6. Children\'s Privacy\n\n'
          'Moov Editor is not directed at children under 13. We do not knowingly '
          'collect personal information from children.\n\n'
          '7. Changes to This Policy\n\n'
          'We may update this Privacy Policy periodically. We will notify you of '
          'significant changes via the App or email.\n\n'
          '8. Contact Us\n\n'
          'For privacy-related questions, contact us at support@moov-editor.com.',
          style: TextStyle(height: 1.6, fontSize: 14),
        ),
      ),
    );
  }
}

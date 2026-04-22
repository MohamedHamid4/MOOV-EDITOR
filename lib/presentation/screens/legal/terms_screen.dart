import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          'Terms of Service\n\n'
          'Last updated: January 2025\n\n'
          '1. Acceptance of Terms\n\n'
          'By downloading and using Moov Editor ("the App"), you agree to be bound by '
          'these Terms of Service. If you do not agree to these terms, please do not '
          'use the App.\n\n'
          '2. Use of the App\n\n'
          'Moov Editor is provided for personal and commercial video editing purposes. '
          'You agree not to use the App for any unlawful purpose or in any way that '
          'could damage, disable, or impair the App.\n\n'
          '3. User Content\n\n'
          'You retain all rights to the content you create using Moov Editor. We do not '
          'claim ownership over your videos, projects, or other creative works. You are '
          'solely responsible for ensuring you have the right to use any media '
          'imported into the App.\n\n'
          '4. Privacy\n\n'
          'Your use of the App is also governed by our Privacy Policy, which is '
          'incorporated into these Terms by reference.\n\n'
          '5. Disclaimers\n\n'
          'The App is provided "as is" without warranties of any kind. We do not '
          'guarantee that the App will be error-free or uninterrupted.\n\n'
          '6. Limitation of Liability\n\n'
          'To the maximum extent permitted by law, we shall not be liable for any '
          'indirect, incidental, special, or consequential damages arising from your '
          'use of the App.\n\n'
          '7. Changes to Terms\n\n'
          'We reserve the right to modify these Terms at any time. Continued use of '
          'the App after any changes constitutes acceptance of the new Terms.\n\n'
          '8. Contact\n\n'
          'If you have questions about these Terms, please contact us at '
          'support@moov-editor.com.',
          style: TextStyle(height: 1.6, fontSize: 14),
        ),
      ),
    );
  }
}

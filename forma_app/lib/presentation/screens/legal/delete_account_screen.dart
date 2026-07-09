import 'package:flutter/material.dart';
import '../../theme.dart';
import 'legal_layout.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalLayout(
      title: 'Delete Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete Your ${Branding.appName.toUpperCase()} Account',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          LegalParagraph(
            'We are sorry to see you go. If you decide to delete your ${Branding.appName} account, please read the instructions below to understand the process and what happens to your data.',
          ),
          LegalTextSection(
            title: 'How to Delete Your Account',
            children: [
              const LegalParagraph(
                'You can request account deletion in one of two ways:',
              ),
              LegalParagraph(
                '1. In the ${Branding.appName} Mobile Application:\nNavigate to: Profile → Settings (Gear icon) → Delete Account → Confirm with your password.',
              ),
              LegalParagraph(
                '2. Request via Email:\nSend an email to nadhalabs@gmail.com from the registered email address associated with your ${Branding.appName} account, with the subject line "Delete my ${Branding.appName} account".',
              ),
            ],
          ),
          const LegalTextSection(
            title: 'What Happens to Your Data?',
            children: [
              LegalParagraph(
                'Once your account deletion request is processed, the following information will be permanently deleted or anonymized:',
              ),
              LegalBulletPoint('Your account profile (first name, last name, username, and bio)'),
              LegalBulletPoint('Your username/email association'),
              LegalBulletPoint('Your uploaded drops, photos, and video media'),
              LegalBulletPoint('Your comments, reactions (fires/likes), and followers/following data'),
            ],
          ),
          const LegalTextSection(
            title: 'Data Retention Policy',
            children: [
              LegalParagraph(
                'Please note that some limited records may be retained in our secure backups for a transitional period if required for compliance with legal obligations, platform security, abuse prevention, or backup recovery purposes. Once these retention obligations expire, the data is completely expunged.',
              ),
            ],
          ),
          const LegalTextSection(
            title: 'Contact Us',
            children: [
              LegalParagraph(
                'If you have any difficulties deleting your account or have questions about your data deletion, please reach out to us at:',
              ),
              LegalParagraph('Developer: Nadha Labs'),
              LegalParagraph('Email: nadhalabs@gmail.com'),
            ],
          ),
        ],
      ),
    );
  }
}

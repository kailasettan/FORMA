import 'package:flutter/material.dart';
import '../../theme.dart';
import 'legal_layout.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalLayout(
      title: 'Privacy Policy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy Policy for ${Branding.appName.toUpperCase()}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Last Updated: July 9, 2026',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          LegalParagraph(
            'At ${Branding.appName}, developed by Nadha Labs, we are committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your personal information when you use our mobile application and related services.',
          ),
          LegalTextSection(
            title: '1. Information We Collect',
            children: [
              LegalParagraph(
                '${Branding.appName} may collect various types of information that you provide directly to us while using the application, including:',
              ),
              const LegalBulletPoint('Name or username'),
              const LegalBulletPoint('Email address'),
              const LegalBulletPoint('Profile photo'),
              const LegalBulletPoint('Uploaded photos, videos, and drops'),
              const LegalBulletPoint('Captions and comments'),
              const LegalBulletPoint('Reactions, likes, and fires'),
              const LegalBulletPoint('Follower and following information'),
              const LegalBulletPoint('Optional location information explicitly added by you'),
              const LegalBulletPoint('Authentication and security-related data'),
            ],
          ),
          LegalTextSection(
            title: '2. How We Use Your Information',
            children: [
              LegalParagraph(
                'We use the information we collect for various purposes to provide and improve the ${Branding.appName} experience, including:',
              ),
              const LegalBulletPoint('Account creation and secure login processes'),
              const LegalBulletPoint('Displaying your profile and posts to other users in accordance with your settings'),
              const LegalBulletPoint('Processing uploads and presenting media on the platform'),
              const LegalBulletPoint('Enabling social features such as comments, reactions, and follows'),
              const LegalBulletPoint('Maintaining platform security, preventing abuse, and improving our services'),
            ],
          ),
          const LegalTextSection(
            title: '3. Third-Party Service Providers',
            children: [
              LegalParagraph(
                'We may use trusted third-party service providers to assist us in delivering, maintaining, and protecting our services. These providers process data for purposes such as hosting, media storage, email communications, and infrastructure delivery. Examples of such service providers include Railway, Cloudinary, Resend, and Cloudflare.',
              ),
            ],
          ),
          const LegalTextSection(
            title: '4. Data Sharing and Protection',
            children: [
              LegalParagraph(
                'We respect your privacy. ${Branding.appName} does not sell user data to third parties. We implement reasonable administrative, technical, and physical security measures to safeguard your personal data against unauthorized access, alteration, or disclosure.',
              ),
            ],
          ),
          const LegalTextSection(
            title: '5. Account Deletion',
            children: [
              LegalParagraph(
                'You have control over your data. You can request the permanent deletion of your account and associated personal data at any time. This can be initiated directly within the app settings (Profile → Settings → Delete Account) or by emailing nadhalabs@gmail.com from your registered email address.',
              ),
            ],
          ),
          LegalTextSection(
            title: '6. Children\'s Privacy',
            children: [
              LegalParagraph(
                '${Branding.appName} is not intended for use by minors or children except as permitted by applicable local laws. If you are a minor, you should use the application only with appropriate consent or as allowed by applicable law.',
              ),
            ],
          ),
          LegalTextSection(
            title: '7. Policy Updates',
            children: [
              LegalParagraph(
                'We may update this Privacy Policy from time to time. When changes are made, we will update the "Last Updated" date at the top of this policy. Continued use of ${Branding.appName} following any updates indicates your acceptance of the revised policy.',
              ),
            ],
          ),
          const LegalTextSection(
            title: '8. Contact Us',
            children: [
              LegalParagraph(
                'If you have any questions, concerns, or requests regarding this Privacy Policy or your data, please contact us at:',
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

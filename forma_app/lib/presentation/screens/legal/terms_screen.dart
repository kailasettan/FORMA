import 'package:flutter/material.dart';
import '../../theme.dart';
import 'legal_layout.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalLayout(
      title: 'Terms & Conditions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terms & Conditions for ${Branding.appName.toUpperCase()}',
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
            'Welcome to ${Branding.appName}! By accessing or using the ${Branding.appName} mobile application and platform, you agree to be bound by these Terms & Conditions. Please read them carefully. If you do not agree to these terms, you should not access or use our services.',
          ),
          LegalTextSection(
            title: '1. Agreement to Terms',
            children: [
              LegalParagraph(
                'These terms represent a legally binding agreement between you and Nadha Labs. Continued use of the ${Branding.appName} application means acceptance of these terms and any subsequent modifications or updates.',
              ),
            ],
          ),
          LegalTextSection(
            title: '2. User Content and Responsibility',
            children: [
              LegalParagraph(
                'As a user of ${Branding.appName}, you are solely responsible for all content (including photos, videos, text, comments, drops, and location tags) that you upload, post, or display on the platform.',
              ),
              LegalParagraph(
                'You retain ownership of the content you create, but you grant Nadha Labs a non-exclusive, royalty-free, worldwide license to host, display, store, and distribute your content for the sole purpose of operating the ${Branding.appName} platform.',
              ),
            ],
          ),
          const LegalTextSection(
            title: '3. Prohibited Content and Conduct',
            children: [
              LegalParagraph(
                'To maintain a safe, welcoming, and athletic community, you must not upload, share, or transmit content that is:',
              ),
              LegalBulletPoint('Illegal, abusive, hateful, or harassing'),
              LegalBulletPoint('Sexually explicit, pornographic, or containing nudity'),
              LegalBulletPoint('Violent, graphic, or depicting self-harm'),
              LegalBulletPoint('Harmful to minors or inciting danger'),
              LegalBulletPoint('Spam, phishing material, or unauthorized advertising'),
              LegalBulletPoint('Impersonation of any person, athlete, or entity'),
              LegalBulletPoint('Copyrighted or proprietary material that you do not own or have the explicit license to use'),
            ],
          ),
          const LegalTextSection(
            title: '4. Enforcement and Termination',
            children: [
              LegalParagraph(
                'Nadha Labs reserves the right, but is not obligated, to monitor user-generated content. We reserve the absolute right to remove any content or suspend/terminate user accounts that we believe violate these Terms & Conditions or are otherwise detrimental to the community, without prior notice.',
              ),
            ],
          ),
          LegalTextSection(
            title: '5. Service Disclaimer (Provided "As-Is")',
            children: [
              LegalParagraph(
                '${Branding.appName} is provided to you on an "as-is" and "as-available" basis, especially during its early release and beta phases. We make no warranties, express or implied, regarding the reliability, uptime, accuracy, or availability of the service.',
              ),
              const LegalParagraph(
                'Nadha Labs is not responsible or liable for any user-generated content, interactions, or transactions between users of the platform.',
              ),
            ],
          ),
          LegalTextSection(
            title: '6. Restrictions on Use',
            children: [
              LegalParagraph(
                'You agree not to misuse the ${Branding.appName} application or services. You must not:',
              ),
              const LegalBulletPoint('Scrape, crawl, or extract data from the platform using automated tools'),
              const LegalBulletPoint('Hack, attempt unauthorized access, bypass security controls, or exploit vulnerabilities'),
              const LegalBulletPoint('Overload, DDOS, or disrupt our servers, infrastructure, or network stability'),
              const LegalBulletPoint('Attempt to reverse engineer the application or its proprietary code'),
            ],
          ),
          const LegalTextSection(
            title: '7. Contact Us',
            children: [
              LegalParagraph(
                'If you have any questions or require clarification on these Terms & Conditions, please contact us at:',
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/top_bar.dart';
import '../../routing/main_shell.dart';

/// Drip's privacy policy, in plain words: what the app and the service behind
/// it collect, why, who helps run it, what stays on the phone, and the
/// choices the user has. Kept in step with what the code actually does
/// (Backend_app and this app); update [PrivacyPolicy.updated] with any change.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      child: Column(
        children: [
          DripTopBar(
            title: 'PRIVACY POLICY',
            height: 56,
            leading: BackGlyph(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/settings'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'LAST UPDATED ${PrivacyPolicy.updated}',
                  style: AppText.mono(
                    9,
                    color: AppColors.muted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  PrivacyPolicy.intro,
                  style: AppText.manrope(14, lineHeight: 21),
                ),
                for (final (i, section) in PrivacyPolicy.sections.indexed)
                  _Section(number: i + 1, section: section),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.number, required this.section});
  final int number;
  final PolicySection section;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${number.toString().padLeft(2, '0')} · ${section.title.toUpperCase()}',
            style: AppText.mono(
              10,
              color: accent,
              weight: FontWeight.w500,
              letterSpacing: 1.4,
            ),
          ),
          if (section.body != null) ...[
            const SizedBox(height: 8),
            Text(
              section.body!,
              style: AppText.manrope(
                13,
                color: AppColors.muted,
                lineHeight: 20,
              ),
            ),
          ],
          for (final (label, text) in section.points)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label  ',
                      style: AppText.manrope(
                        13,
                        weight: FontWeight.w700,
                        lineHeight: 20,
                      ),
                    ),
                    TextSpan(
                      text: text,
                      style: AppText.manrope(
                        13,
                        color: AppColors.muted,
                        lineHeight: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One part of the policy: a title, an optional lead, and labelled points.
class PolicySection {
  const PolicySection(this.title, {this.body, this.points = const []});
  final String title;
  final String? body;
  final List<(String, String)> points;
}

/// The policy's words, apart from the screen so they're easy to review.
abstract final class PrivacyPolicy {
  static const updated = '9 OCTOBER 2026';

  static const intro =
      'This explains what Drip collects, why, who helps us run it, what '
      'stays on your phone and the choices you have. It covers the Drip app '
      'and the Drip service behind it. We don\'t sell your data and there '
      'are no ads in Drip.';

  static const sections = [
    PolicySection(
      'What you give us',
      points: [
        (
          'Your account.',
          'You sign in with Google. Google shares your email address, your '
              'name and your profile picture with us, through our sign-in '
              'provider.',
        ),
        (
          'Your profile.',
          'Drip shows you by the name on your Google account. In this beta '
              'nothing you add to Drip is public.',
        ),
        (
          'Your style.',
          'What you pick when you set up Drip or edit Your style: who you '
              'dress for, occasions, vibes, colours and colour season, '
              'brands, budget, fit, and skin tone if you set it, plus your '
              'answers to the style quiz if you take it (outfit budget, what '
              'you dress for, how and where you shop, your weather). We use '
              'them to choose the fits you see.',
        ),
        (
          'Your wardrobe.',
          'Photos of clothes you add, and pieces you save from the Drip '
              'catalogue. Wardrobe photos are private to you.',
        ),
        (
          'Your Studio fits.',
          'The pieces you put together, where you placed them and the name '
              'you give each fit. They\'re private to you.',
        ),
        (
          'Bug reports.',
          'When you report a bug: the kind of problem, what you write, the '
              'screen you were on, the app version and your phone\'s system '
              'version, and the fit\'s id if you keep it attached. Never your '
              'photos.',
        ),
      ],
    ),
    PolicySection(
      'What we collect as you use Drip',
      points: [
        (
          'What you like.',
          'The fits you like, save, open or swipe past, and how long you '
              'look at them. This is how your feed learns your taste.',
        ),
        (
          'Usage.',
          'The names of things you do in Drip (for example, that a page of '
              'the feed was shown) with a few coarse details, linked to your '
              'account id. Never your photos or what you type.',
        ),
        (
          'Errors.',
          'When something fails on our servers we record technical details '
              'of that request so we can fix it, but not its content or your '
              'account details.',
        ),
        (
          'Abuse protection.',
          'Short-lived counters of how often your account calls our servers, '
              'to stop spam and abuse.',
        ),
      ],
    ),
    PolicySection(
      'What stays on your phone',
      body:
          'Some things never leave your phone. Logging out removes the '
          'selfies; uninstalling Drip removes the rest.',
      points: [
        (
          'Selfies.',
          'Selfies you take in Drip, and the photos for photoshoots, are '
              'kept in the app\'s own storage on your phone. They\'re never '
              'uploaded.',
        ),
        (
          'App settings.',
          'Your theme, your progress through setup, Studio work in progress '
              'and bug reports waiting to be sent.',
        ),
      ],
    ),
    PolicySection(
      'How we use it',
      points: [
        ('To run Drip.', 'Your account, your wardrobe, your saved fits.'),
        (
          'To personalise.',
          'Your style picks and what you like decide the fits you see.',
        ),
        (
          'To process your wardrobe.',
          'We cut each clothing photo out of its background on our own '
              'servers, then an AI model tags it (category, colour, season).',
        ),
        (
          'For Taylor.',
          'Taylor, your stylist, gets the occasion and vibe you choose and '
              'the public details of the fit it suggests. Never your wardrobe '
              'or photos.',
        ),
        (
          'To fix and improve Drip.',
          'Usage, error details and your bug reports.',
        ),
      ],
    ),
    PolicySection(
      'Who helps us run Drip',
      body: 'These services handle data for us, only to do their job for Drip:',
      points: [
        ('Supabase.', 'Sign-in, our database and file storage, in Singapore.'),
        ('Railway.', 'Runs Drip\'s servers, in Singapore.'),
        (
          'Upstash and Inngest.',
          'A short-term cache (your feed\'s order, abuse counters) and the '
              'queue that runs background work such as processing wardrobe '
              'photos.',
        ),
        (
          'Google Gemini and Groq.',
          'The AI models that tag your wardrobe photos (they get the cut-out '
              'through a link that expires in 10 minutes) and write Taylor\'s '
              'notes.',
        ),
        ('PostHog.', 'Usage analytics, as described above.'),
        ('Sentry.', 'Error reports from our servers.'),
        ('GitHub.', 'Stores encrypted daily backups for 14 days.'),
        ('Google.', 'Sign-in with your Google account.'),
      ],
    ),
    PolicySection(
      'Stores',
      body:
          'When you tap BUY or VISIT, the store\'s own page opens and its '
          'privacy policy applies there. Links may tell the store you came '
          'from Drip. We don\'t see what you buy.',
    ),
    PolicySection(
      'Who can see what',
      points: [
        (
          'Public.',
          'Nothing you add, in this beta. Public profiles, following and '
              'posting come after the beta, and this policy will say so '
              'before they do.',
        ),
        (
          'Only you.',
          'Your wardrobe, Studio fits, saved and liked fits, and your style '
              'picks.',
        ),
      ],
    ),
    PolicySection(
      'Where it\'s kept, and for how long',
      body:
          'Your data is stored in Singapore. We keep it while you have a Drip '
          'account. Deleting your account removes it, with your wardrobe '
          'photos and other files, straight away. Copies in our encrypted '
          'backups are gone within 14 days. Usage and error records are kept '
          'for a limited time by the services above.',
    ),
    PolicySection(
      'Your choices',
      points: [
        ('Change your style.', 'Settings → Your style, at any time.'),
        (
          'Remove things.',
          'Delete wardrobe pieces, Studio fits, and saved or liked fits.',
        ),
        ('Notifications.', 'Turn them off in Settings.'),
        (
          'Delete your account.',
          'Settings → Delete account. It removes your account and everything '
              'in it.',
        ),
        (
          'Ask us.',
          'For any question or request about your data, tap Report a bug in '
              'the feed and choose "Something else".',
        ),
      ],
    ),
    PolicySection(
      'Changes',
      body:
          'When this policy changes, we update this page and the date at the '
          'top. If a change matters, we\'ll tell you in the app first.',
    ),
  ];
}

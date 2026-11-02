import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/services/stemly_api_service.dart';
import '../data/storage/offline_storage.dart';
import '../theme/theme_provider.dart';
import '../widgets/bottom_nav_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeletingData = false;

  // FEEDBACK
  Future<void> _sendFeedback() async {
    final Uri email = Uri(
      scheme: 'mailto',
      path: 'teamstemly@gmail.com',
      query: 'subject=STEMLY Feedback&body=Your feedback:',
    );
    await launchUrl(email, mode: LaunchMode.externalApplication);
  }

  // RATE APP
  Future<void> _rateApp() async {
    const url = "https://play.google.com/store/apps/details?id=com.stemly.app";
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // DELETE DATA CONFIRMATION
  Future<void> _confirmDeleteData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final apiService = context.read<StemlyApiService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete All My Data?"),
        content: const Text(
          "This will permanently erase your scan history, generated notes, quiz records, and personal profile from the STEMLY cloud server and this device.\n\nThis action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeletingData = true);
      try {
        await apiService.deleteMyData();
        await OfflineStorage.clearAll();

        messenger.showSnackBar(
          const SnackBar(
            content: Text("All your data was successfully deleted."),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("Failed to delete cloud data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isDeletingData = false);
        }
      }
    }
  }

  // GENERIC INFO SHEET
  void _openInfoSheet(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onPressed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                "About STEMLY",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "STEMLY empowers students to master physics and STEM topics through multimodal problem scanning, interactive visualizers, and AI-assisted inquiry.",
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                "Development Team",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildTeamMember(
                name: "Dakshin",
                role: "Fullstack & AI Engineering",
                imagePath: "assets/team/dakshin.jpg",
              ),
              _buildTeamMember(
                name: "Moji",
                role: "Mobile App & UI/UX",
                imagePath: "assets/team/dakshin.jpg",
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Version 1.0.0 (Production)",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMember({
    required String name,
    required String role,
    required String imagePath,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage(imagePath),
            onBackgroundImageError: (exception, stackTrace) {},
            child: Text(name[0]),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                role,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // SECURE BACKEND AI ENGINE STATUS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Engine Status",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "STEMLY Cloud AI Active",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Connected",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "All AI reasoning, diagram analysis, notes, and quiz generation are securely processed through the hardened STEMLY backend API.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.bolt, size: 16),
                              label: const Text("Llama 3.3 70B & Vision", style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              avatar: const Icon(Icons.shield_outlined, size: 16),
                              label: const Text("Zero-Key Client", style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              avatar: const Icon(Icons.speed, size: 16),
                              label: const Text("Semantic Cache Enabled", style: TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PREFERENCES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              "Preferences",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),

          // DARK MODE
          SwitchListTile(
            title: const Text("Dark Mode"),
            subtitle: const Text("Toggle dark and light themes"),
            value: themeProvider.isDarkMode,
            onChanged: themeProvider.toggleTheme,
          ),

          // NOTIFICATION TOGGLE
          SwitchListTile(
            title: const Text("Notifications"),
            subtitle: const Text("Receive updates and study reminders"),
            value: themeProvider.notifications,
            onChanged: themeProvider.toggleNotifications,
          ),

          // WIFI ONLY
          SwitchListTile(
            title: const Text("Wi-Fi Only Mode"),
            subtitle: const Text("Process scans only on Wi-Fi connection"),
            value: themeProvider.wifiOnly,
            onChanged: themeProvider.toggleWifiOnly,
          ),

          const Divider(height: 32),

          // DATA & PRIVACY
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              "Data & Privacy",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),

          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
            title: const Text("Privacy Policy"),
            onTap: () => Navigator.pushNamed(context, '/privacy'),
          ),

          ListTile(
            leading: Icon(Icons.article_outlined, color: cs.primary),
            title: const Text("Terms & Conditions"),
            onTap: () => Navigator.pushNamed(context, '/terms'),
          ),

          ListTile(
            leading: _isDeletingData
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  )
                : const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: const Text(
              "Delete My Data",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text("Erase all cloud and local history (GDPR/CCPA)"),
            onTap: _isDeletingData ? null : () => _confirmDeleteData(context),
          ),

          const Divider(height: 32),

          // ABOUT
          ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primary,
              child: Icon(Icons.info_outline, color: cs.onPrimary),
            ),
            title: const Text("About STEMLY"),
            subtitle: const Text("Meet the team & mission"),
            onTap: () => _showAboutSheet(context),
          ),

          ListTile(
            leading: Icon(Icons.feedback_outlined, color: cs.primary),
            title: const Text("Send Feedback"),
            onTap: () => _openInfoSheet(
              context,
              title: "Send Feedback",
              message: "We value your feedback. Help us improve STEMLY by sharing your thoughts.",
              buttonText: "Compose Email",
              onPressed: _sendFeedback,
            ),
          ),

          ListTile(
            leading: const Icon(Icons.star_rate_rounded, color: Colors.amber),
            title: const Text("Rate the App"),
            onTap: () => _openInfoSheet(
              context,
              title: "Rate STEMLY",
              message: "If you enjoy STEMLY, support us by leaving a rating on the Play Store.",
              buttonText: "Open Play Store",
              onPressed: _rateApp,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/settings_tile.dart';

class ProfileTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ProfileTab({super.key, this.onNavigateTab});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _liveLocationSharing = true;
  bool _pushNotifications = true;
  bool _offlineEmergencyMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: AppTheme.orangeTint,
              child: Icon(Icons.person, size: 50, color: AppTheme.orange),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tourist User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const Text('Registered Traveler', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 24),
            SettingsTile(
              icon: Icons.share_location,
              label: 'Live Location Sharing',
              trailing: Switch(
                value: _liveLocationSharing,
                onChanged: (val) {
                  setState(() => _liveLocationSharing = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val ? 'Live Location Sharing Enabled' : 'Live Location Sharing Disabled',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: AppTheme.orange,
              ),
            ),
            SettingsTile(
              icon: Icons.notifications,
              label: 'Push Notifications',
              trailing: Switch(
                value: _pushNotifications,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val ? 'Safety Push Notifications Enabled' : 'Safety Push Notifications Paused',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: AppTheme.orange,
              ),
            ),
            SettingsTile(
              icon: Icons.wifi_off,
              label: 'Offline Emergency Mode',
              trailing: Switch(
                value: _offlineEmergencyMode,
                onChanged: (val) {
                  setState(() => _offlineEmergencyMode = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Offline Emergency Mode On (SMS & Cached Maps active)'
                            : 'Offline Emergency Mode Off',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: AppTheme.orange,
              ),
            ),
            const Divider(height: 32),
            SettingsTile(
              icon: Icons.emergency,
              label: 'Emergency Contacts',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                widget.onNavigateTab?.call(2); // Jump to SOS tab
              },
            ),
            SettingsTile(
              icon: Icons.language,
              label: 'Language',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('English (Default)'),
                          trailing: const Icon(Icons.check, color: AppTheme.orange),
                          onTap: () => Navigator.pop(ctx),
                        ),
                        ListTile(
                          title: const Text('Hindi (हिन्दी)'),
                          onTap: () => Navigator.pop(ctx),
                        ),
                        ListTile(
                          title: const Text('Marathi (मराठी)'),
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SettingsTile(
              icon: Icons.info_outline,
              label: 'About AIKTC Project',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Tourist Safety Monitor',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Developed for Tourist Safety Monitoring System.\nAnjuman-I-Islam Kalsekar Technical Campus (AIKTC).',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

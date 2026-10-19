import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/firebase_user_service.dart';
import '../../core/services/safety_zone_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_screen.dart';
import '../dashboard/widgets/emergency_alert_modal.dart';
import 'widgets/settings_tile.dart';

class ProfileTab extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ProfileTab({super.key, this.onNavigateTab});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FirebaseUserService _userService = FirebaseUserService();
  final SafetyZoneService _safetyZoneService = SafetyZoneService();

  bool _liveLocationSharing = true;
  bool _weatherHazardAlerts = true;
  String _localPreferredLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _userService.addListener(_onServiceUpdated);
    _safetyZoneService.addListener(_onServiceUpdated);
    _loadNonSensitivePreferences();
  }

  @override
  void dispose() {
    _userService.removeListener(_onServiceUpdated);
    _safetyZoneService.removeListener(_onServiceUpdated);
    super.dispose();
  }

  void _onServiceUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNonSensitivePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _liveLocationSharing = prefs.getBool('pref_live_sharing') ?? true;
        _weatherHazardAlerts = prefs.getBool('pref_weather_alerts') ?? true;
        _localPreferredLanguage = prefs.getString('pref_language') ?? 'English';
      });
    } catch (_) {}
  }

  Future<void> _savePreferenceBool(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }

  Future<void> _openEditProfileDialog(TouristProfile profile) async {
    final nameCtrl = TextEditingController(text: profile.fullName);
    final phoneCtrl = TextEditingController(text: profile.phoneNumber);
    final ecNameCtrl = TextEditingController(text: profile.emergencyContactName);
    final ecPhoneCtrl = TextEditingController(text: profile.emergencyContactPhone);
    String lang = profile.preferredLanguage.isNotEmpty
        ? profile.preferredLanguage
        : 'English';
    String blood = profile.bloodGroup;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Update Tourist Profile',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ecNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ecPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: ['English', 'Hindi', 'Marathi'].contains(lang)
                    ? lang
                    : 'English',
                decoration: const InputDecoration(
                  labelText: 'Preferred Language',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'Marathi', child: Text('Marathi')),
                ],
                onChanged: (v) {
                  if (v != null) lang = v;
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: TextEditingController(text: blood),
                onChanged: (v) => blood = v,
                decoration: const InputDecoration(
                  labelText: 'Blood Group (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final updated = TouristProfile(
                    uid: profile.uid,
                    fullName: nameCtrl.text.trim(),
                    email: profile.email,
                    phoneNumber: phoneCtrl.text.trim(),
                    emergencyContactName: ecNameCtrl.text.trim(),
                    emergencyContactPhone: ecPhoneCtrl.text.trim(),
                    preferredLanguage: lang,
                    bloodGroup: blood.trim(),
                  );
                  final err = await _userService.updateProfile(updated);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        err ?? 'Profile updated successfully!',
                      ),
                    ),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _userService.isSignedIn;
    final profile = _userService.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourist Profile & Settings'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _userService.signOut();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out.')),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Account / Authentication Card
            _buildAccountCard(signedIn, profile),
            const SizedBox(height: 16),

            // 2. Saved Emergency Contact Details (when signed in)
            if (signedIn && profile != null) ...[
              _buildProfileDetailsCard(profile),
              const SizedBox(height: 16),
            ],

            // 3. Safety & Notification Preferences
            Card(
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.share_location,
                    label: 'Live GPS Safety Monitoring',
                    trailing: Switch(
                      value: _liveLocationSharing,
                      onChanged: (val) {
                        setState(() => _liveLocationSharing = val);
                        _savePreferenceBool('pref_live_sharing', val);
                      },
                      activeThumbColor: AppTheme.teal,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.thunderstorm_outlined,
                    label: 'Live Weather & Geofence Warnings',
                    trailing: Switch(
                      value: _weatherHazardAlerts,
                      onChanged: (val) {
                        setState(() => _weatherHazardAlerts = val);
                        _savePreferenceBool('pref_weather_alerts', val);
                      },
                      activeThumbColor: AppTheme.teal,
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.emergency_outlined,
                    label: 'Emergency Helplines & SOS',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                  SettingsTile(
                    icon: Icons.language,
                    label:
                        'Language (${profile?.preferredLanguage ?? _localPreferredLanguage})',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: ['English', 'Hindi', 'Marathi'].map((lang) {
                              final current =
                                  profile?.preferredLanguage ?? _localPreferredLanguage;
                              return ListTile(
                                title: Text(lang),
                                trailing: current == lang
                                    ? const Icon(Icons.check, color: AppTheme.teal)
                                    : null,
                                onTap: () async {
                                  setState(() => _localPreferredLanguage = lang);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('pref_language', lang);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Clearly Labeled Demonstration Controls for College Project Presentation
            // (Safeguard #7: Separated from real-world data and clearly labeled)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cautionAmber.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.science_outlined, color: Color(0xFF92400E), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'College Presentation Demo Mode (Simulation Only)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enable this toggle during your project presentation to simulate a HIGH RISK geofence around Panvel (8 km radius). '
                    'This is explicitly labeled as [DEMO / SIMULATION DATA] and never auto-triggers SOS without confirmation.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textDark, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Simulate Panvel High-Risk Geofence (RED ALERT)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.highRiskRed),
                      ),
                      subtitle: const Text('Simulates entering an active High-Risk Hazard Zone', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                      value: _safetyZoneService.panvelDemoEnabled,
                      activeThumbColor: AppTheme.highRiskRed,
                      onChanged: (val) {
                        _safetyZoneService.setPanvelDemoEnabled(val);
                        setState(() {});
                      },
                    ),
                  ),
                  const Divider(height: 12),
                  Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Simulate Nerul Medium-Risk Geofence (AMBER ALERT)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.cautionAmber),
                      ),
                      subtitle: const Text('Simulates a Moderate / Caution Advisory Zone in Nerul (8 km radius)', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                      value: _safetyZoneService.nerulDemoEnabled,
                      activeThumbColor: AppTheme.cautionAmber,
                      onChanged: (val) {
                        _safetyZoneService.setNerulDemoEnabled(val);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(bool signedIn, TouristProfile? profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.tealTint,
            child: Icon(
              signedIn ? Icons.verified_user : Icons.person_outline,
              size: 38,
              color: AppTheme.tealDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            signedIn
                ? (profile?.fullName.isNotEmpty == true
                    ? profile!.fullName
                    : 'Registered Tourist')
                : 'Not Signed In',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            signedIn
                ? (profile?.email ?? '')
                : 'Sign in with Firebase Authentication to store your tourist profile and emergency contact in Cloud Firestore.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 14),
          if (signedIn && profile != null)
            Wrap(
              spacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openEditProfileDialog(profile),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Profile'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _userService.signOut(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sign Out'),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Sign In / Create Tourist Account'),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsCard(TouristProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cloud Firestore Tourist Record',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _detailRow('Phone', profile.phoneNumber.isEmpty ? 'Not set' : profile.phoneNumber),
          _detailRow(
            'Emergency Contact',
            profile.emergencyContactName.isEmpty && profile.emergencyContactPhone.isEmpty
                ? 'Not set'
                : '${profile.emergencyContactName} (${profile.emergencyContactPhone})',
          ),
          _detailRow('Preferred Language', profile.preferredLanguage),
          if (profile.bloodGroup.isNotEmpty)
            _detailRow('Blood Group', profile.bloodGroup),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

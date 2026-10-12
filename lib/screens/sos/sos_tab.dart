import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/emergency_contact_tile.dart';

class SOSTab extends StatefulWidget {
  const SOSTab({super.key});

  @override
  State<SOSTab> createState() => _SOSTabState();
}

class _SOSTabState extends State<SOSTab> with SingleTickerProviderStateMixin {
  bool _triggered = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _triggerSOS() {
    setState(() => _triggered = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFFDC2626),
        content: Text('🚨 SOS Alert Dispatched! Local authorities notified.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _resetSOS() {
    setState(() => _triggered = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Alert cancelled.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        actions: [
          if (_triggered)
            IconButton(
              tooltip: 'Reset SOS',
              icon: const Icon(Icons.refresh),
              onPressed: _resetSOS,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Pulsing SOS button
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _triggered ? 1.0 + _pulse.value * 0.05 : 1.0,
                child: child,
              ),
              child: GestureDetector(
                onLongPress: _triggerSOS,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _triggered ? const Color(0xFFDC2626) : const Color(0xFFB91C1C),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                        blurRadius: _triggered ? 40 : 20,
                        spreadRadius: _triggered ? 12 : 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sos, color: Colors.white, size: 60),
                      const SizedBox(height: 8),
                      Text(
                        _triggered ? 'ALERT SENT!' : 'HOLD FOR SOS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            if (_triggered)
              Column(
                children: [
                  const Text(
                    '🚨 Emergency services notified.\nHelp is on the way.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _resetSOS,
                    icon: const Icon(Icons.cancel_outlined, color: AppTheme.muted),
                    label: const Text(
                      'Cancel Alert (False Alarm)',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Hold the button for 2 seconds\nto send an emergency alert',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Emergency Contacts',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
            ),
            const SizedBox(height: 12),
            const EmergencyContactTile(
              icon: Icons.local_police,
              label: 'Police',
              number: '100',
            ),
            const EmergencyContactTile(
              icon: Icons.local_hospital,
              label: 'Ambulance',
              number: '108',
            ),
            const EmergencyContactTile(
              icon: Icons.fire_truck,
              label: 'Fire',
              number: '101',
            ),
          ],
        ),
      ),
    );
  }
}

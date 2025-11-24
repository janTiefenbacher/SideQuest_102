import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class FriendProfilePage extends StatefulWidget {
  const FriendProfilePage({super.key, required this.userId, this.initialUserName});
  final String userId;
  final String? initialUserName;

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  String _username = '';
  String? _avatarUrl;
  String _bio = '';
  String? _role;
  int _friendsCount = 0;
  int _pointsToday = 0;
  int _flameStreak = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _username = widget.initialUserName ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      Map<String, dynamic> profile;
      try {
        profile = await client
            .from('profiles')
            .select('username, avatar_url, bio, role')
            .eq('id', widget.userId)
            .single();
      } catch (_) {
        // Fallback if role column doesn't exist yet
        profile = await client
            .from('profiles')
            .select('username, avatar_url, bio')
            .eq('id', widget.userId)
            .single();
      }
      _username = (profile['username'] as String?) ?? _username;
      _avatarUrl = profile['avatar_url'] as String?;
      _bio = (profile['bio'] as String?) ?? '';
      _role = profile['role'] as String?;

      // Friends count
      final friendsRes = await client
          .from('friendships')
          .select('requester, addressee')
          .or('requester.eq.${widget.userId},addressee.eq.${widget.userId}')
          .eq('status', 'accepted');
      final Set<String> friendIds = {};
      for (final row in friendsRes as List) {
        final requester = row['requester'] as String;
        final addressee = row['addressee'] as String;
        final other = requester == widget.userId ? addressee : requester;
        if (other != widget.userId) friendIds.add(other);
      }

      // Points today = sum quest_completions for today
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final comps = await client
          .from('quest_completions')
          .select('points_earned, completed_at')
          .eq('user_id', widget.userId)
          .gte('completed_at', startOfDay.toIso8601String());
      int points = 0;
      for (final c in (comps as List)) {
        points += (c['points_earned'] as int? ?? 0);
      }
      // Flame streak (from server stats if exists; fallback: 0)
      int flameStreak = 0;
      try {
        final stats = await client
            .from('user_quest_stats')
            .select('current_streak')
            .eq('user_id', widget.userId)
            .maybeSingle();
        if (stats != null) flameStreak = stats['current_streak'] as int? ?? 0;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _friendsCount = friendIds.length;
        _pointsToday = points;
        _flameStreak = flameStreak;
      });
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text(
          _username.isEmpty ? 'Profil' : _username,
          style: const TextStyle(
            color: kNavy,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kBrightBlue, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _avatarUrl != null
                        ? ClipOval(
                            child: _avatarUrl!.startsWith('data:')
                                ? Image.memory(
                                    base64Decode(_avatarUrl!.split(',')[1]),
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: _avatarUrl!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 120,
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 120,
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.person, size: 60, color: kBrightBlue),
                                    ),
                                  ),
                          )
                        : const CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, size: 60, color: kBrightBlue),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _username,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_role != null && _role!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _roleColor(_role!).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _role!.toUpperCase(),
                        style: TextStyle(
                          color: _roleColor(_role!),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_bio.isNotEmpty)
                    Text(
                      _bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Freunde', _friendsCount.toString()),
                        _buildStatItem('Punkte', _pointsToday.toString(), icon: Icons.emoji_events, iconColor: kBrightBlue),
                        _buildStatItem('Flammen', _flameStreak.toString(), icon: Icons.local_fire_department, iconColor: Colors.orange),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, {IconData? icon, Color? iconColor}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? kBrightBlue, size: 20),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kBrightBlue,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Color _roleColor(String role) {
    final r = role.toLowerCase();
    if (r == 'admin') return const Color(0xFFEF5350);
    if (r == 'vip') return const Color(0xFFFFC107);
    if (r == 'mod' || r == 'moderator') return const Color(0xFF42A5F5);
    return kBrightBlue;
  }
}



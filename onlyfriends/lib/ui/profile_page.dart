import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:convert';
import '../theme.dart';
import '../services/quest_service.dart';
import 'edit_state.dart';
import 'app_theme.dart';
import 'admin_test_page.dart';
import 'admin_settings_page.dart';
import 'notification_settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  static const String route = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditing = false;
  int _friendsCount = 0;
  int _pointsToday = 0;
  int _totalQuestPoints = 0;
  int _flameStreak = 0;
  bool _isAdmin = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Load user profile from database
        final response = await Supabase.instance.client
            .from('profiles')
            .select('username, avatar_url, bio, role')
            .eq('id', user.id)
            .single();

        setState(() {
          _nameController.text = response['username'] ?? user.email?.split('@').first ?? 'User';
          _avatarUrl = response['avatar_url'];
          _bioController.text = response['bio'] ?? '';
        });

        // Load profile stats (friends + points)
        await _loadProfileStats(user.id);
        
        // Load total quest points
        await _loadTotalQuestPoints(user.id);
        
        // Check if user is admin based on role from database
        _checkAdminStatus(response['role']);
      }
    } catch (e) {
      print('Error loading user profile: $e');
      // Fallback to email username
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _nameController.text = user.email?.split('@').first ?? 'User';
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfileStats(String userId) async {
    try {
      final client = Supabase.instance.client;

      // Friends count (accepted friendships where current user is requester or addressee)
      final friendsRes = await client
          .from('friendships')
          .select('requester, addressee')
          .or('requester.eq.$userId,addressee.eq.$userId')
          .eq('status', 'accepted');
      final Set<String> friendIds = {};
      for (final row in friendsRes as List) {
        final requester = row['requester'] as String;
        final addressee = row['addressee'] as String;
        final other = requester == userId ? addressee : requester;
        if (other != userId) friendIds.add(other);
      }

      // Points today = sum of awarded quest points heute (nicht Vote-basiert)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final comps = await client
          .from('quest_completions')
          .select('points_earned, completed_at')
          .eq('user_id', userId)
          .gte('completed_at', startOfDay.toIso8601String());
      int points = 0;
      for (final c in (comps as List)) {
        points += (c['points_earned'] as int? ?? 0);
      }

      // Flame-Streak auf Konsistenz prüfen und dann laden
      int flames = 0;
      try {
        await QuestService.reconcileFlameStreakOnAppStart(userId);
        flames = await QuestService.getFlameStreak(userId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _friendsCount = friendIds.length;
          _pointsToday = points;
          _flameStreak = flames;
        });
      }
    } catch (e) {
      print('Error loading profile stats: $e');
    }
  }

  Future<void> _loadTotalQuestPoints(String userId) async {
    try {
      final totalPoints = await QuestService.getUserTotalPoints(userId);
      if (mounted) {
        setState(() {
          _totalQuestPoints = totalPoints;
        });
      }
    } catch (e) {
      print('Error loading total quest points: $e');
    }
  }

  void _checkAdminStatus(String? role) {
    // Check if user role is 'admin' (case-insensitive)
    final wasAdmin = _isAdmin;
    final isAdmin = role?.toLowerCase() == 'admin';
    
    print('Admin check - Role: $role, Is Admin: $isAdmin');
    
    setState(() {
      _isAdmin = isAdmin;
    });
    
    // Update TabController length based on admin status
    if (wasAdmin != isAdmin) {
      print('Updating TabController - Admin status changed: $wasAdmin -> $isAdmin');
      _tabController.dispose();
      _tabController = TabController(length: isAdmin ? 2 : 1, vsync: this);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        // Upload image to Supabase Storage
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          try {
            final fileName = '${user.id}_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File(image.path);
            
            // Convert image to base64 and store in database (no RLS issues)
            final bytes = await file.readAsBytes();
            final base64String = base64Encode(bytes);
            final dataUrl = 'data:image/jpeg;base64,$base64String';

            setState(() {
              _avatarUrl = dataUrl;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profilbild erfolgreich hochgeladen!'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            print('Error uploading avatar: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fehler beim Hochladen: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Auswählen des Bildes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Save profile to database
        await Supabase.instance.client
            .from('profiles')
            .upsert({
              'id': user.id,
              'username': _nameController.text.trim(),
              'avatar_url': _avatarUrl,
              'bio': _bioController.text.trim(),
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil erfolgreich gespeichert!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          physics: _isEditing ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Scrollable header instead of fixed AppBar
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profil',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              setState(() {
                                _isEditing = !_isEditing;
                                EditState.isEditingProfile.value = _isEditing;
                              });
                            },
                      icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Theme.of(context).colorScheme.onSurface),
                      tooltip: _isEditing ? 'Abbrechen' : 'Bearbeiten',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Profile Picture Section
                GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kBrightBlue,
                            width: 4,
                          ),
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
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          width: 120,
                                          height: 120,
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: kBrightBlue,
                                          ),
                                        ),
                                      ),
                              )
                            : CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                child: const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: kBrightBlue,
                                ),
                              ),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: kBrightBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Profilbild ändern',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Flame-Streak direkt unter dem Profilbild anzeigen
                if (!_isEditing)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.whatshot,
                            color: Colors.orangeAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _flameStreak > 0
                                ? '$_flameStreak Tage Streak'
                                : 'Noch kein Streak – heute starten?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_flameStreak > 0)
                        Text(
                          // Maximal 10 Flammen-Emojis anzeigen, damit es nicht ausartet
                          '🔥' * (_flameStreak.clamp(1, 10)),
                          style: const TextStyle(fontSize: 18),
                        ),
                    ],
                  ),

                const SizedBox(height: 24),
                
                
                // Name Field
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    readOnly: !_isEditing,
                    enabled: _isEditing,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    cursorColor: kBrightBlue,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Dein Username',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                      ),
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.person, color: kBrightBlue),
                      contentPadding: const EdgeInsets.all(16),
                      counterStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte gib deinen Username ein';
                      }
                      if (value.length < 3) {
                        return 'Username muss mindestens 3 Zeichen lang sein';
                      }
                      return null;
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Bio Field
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _bioController,
                    readOnly: !_isEditing,
                    enabled: _isEditing,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    cursorColor: kBrightBlue,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Erzähl etwas über dich...',
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                      ),
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.info, color: kBrightBlue),
                      contentPadding: const EdgeInsets.all(16),
                      counterStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    maxLines: 3,
                    maxLength: 150,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Save Button (only in Edit mode)
                if (_isEditing)
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kBrightBlue, kSky],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: kBrightBlue.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        await _saveProfile();
                        if (mounted) {
                          setState(() {
                            _isEditing = false;
                            EditState.isEditingProfile.value = false;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Profil speichern',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                
                const SizedBox(height: 30),
                
                if (!_isEditing)
                // Stats Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Statistiken',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            label: 'Freunde',
                            value: _friendsCount.toString(),
                            icon: Icons.group,
                            color: Colors.blueAccent,
                          ),
                          _buildStatItem(
                            label: 'Punkte heute',
                            value: _pointsToday.toString(),
                            icon: Icons.bolt,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            label: 'Quest Punkte',
                            value: _totalQuestPoints.toString(),
                            icon: Icons.emoji_events,
                            color: Colors.deepPurpleAccent,
                          ),
                          _buildStatItem(
                            label: 'Flammen',
                            value: _flameStreak.toString(),
                            icon: Icons.whatshot,
                            color: Colors.orangeAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                if (!_isEditing)
                // Settings Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Debug info (temporary)
                      if (_isAdmin)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text(
                            'Admin Status: Aktiv (Role: admin)',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (_isAdmin)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Modus wählen',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? const Color(0xFF2D2D2D) 
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white24 
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white24 
                                      : Colors.grey.shade400,
                                ),
                                labelColor: Colors.white,
                                unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white70 
                                    : Colors.black54,
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                dividerColor: Colors.transparent,
                                overlayColor: MaterialStateProperty.all(Colors.transparent),
                                splashFactory: NoSplash.splashFactory,
                                tabs: const [
                                  Tab(
                                    iconMargin: EdgeInsets.zero,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_outline, size: 18),
                                        SizedBox(width: 6),
                                        Text('Nutzer'),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    iconMargin: EdgeInsets.zero,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.admin_panel_settings_outlined, size: 18),
                                        SizedBox(width: 6),
                                        Text('Admin'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      SizedBox(
                        height: 400, // Fixed height to prevent infinite scrolling
                        child: _isAdmin 
                          ? TabBarView(
                              controller: _tabController,
                              children: [
                                _buildSettingsTab(),
                                _buildAdminTab(),
                              ],
                            )
                          : _buildSettingsTab(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon, 
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.orange.shade400 
            : kBrightBlue,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios, 
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingsTab() {
    return ListTileTheme(
      iconColor: Theme.of(context).colorScheme.onSurface,
      textColor: Theme.of(context).colorScheme.onSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Einstellungen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.notifications,
            title: 'Benachrichtigungen',
            subtitle: 'Benachrichtigungseinstellungen verwalten',
            onTap: () => Navigator.pushNamed(context, NotificationSettingsPage.route),
          ),
          SwitchListTile(
            secondary: Icon(
              Icons.dark_mode, 
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.orange.shade400 
                  : kBrightBlue,
            ),
            title: Text(
              'Dark Mode',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Dunkles Design in der ganzen App',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (value) async {
              await AppTheme.setDarkMode(value);
              if (mounted) setState(() {});
            },
          ),
          _buildSettingItem(
            icon: Icons.privacy_tip,
            title: 'Datenschutz',
            subtitle: 'Privatsphäre-Einstellungen',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Datenschutz-Einstellungen kommen bald!'),
                ),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.logout,
            title: 'Abmelden',
            subtitle: 'Von SideQuest abmelden',
            onTap: () => _showLogoutConfirmation(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTab() {
    return ListTileTheme(
      iconColor: Theme.of(context).colorScheme.onSurface,
      textColor: Theme.of(context).colorScheme.onSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Admin Funktionen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.admin_panel_settings,
            title: 'Admin Einstellungen',
            subtitle: 'Erweiterte Admin-Funktionen',
            onTap: () => Navigator.pushNamed(context, AdminSettingsPage.route),
          ),
          _buildSettingItem(
            icon: Icons.bug_report,
            title: 'Test Menu',
            subtitle: 'Test notifications and app features',
            onTap: () => Navigator.pushNamed(context, AdminTestPage.route),
          ),
          _buildSettingItem(
            icon: Icons.info,
            title: 'Rolle Info',
            subtitle: 'Aktuelle Benutzerrolle anzeigen',
            onTap: () => _showRoleInfo(),
          ),
        ],
      ),
    );
  }

  void _showRoleInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Benutzerrolle'),
        content: Text(
          'Benutzer: ${user?.email ?? "Unbekannt"}\n'
          'Rolle: ${_isAdmin ? "Admin" : "Member"}\n'
          'Status: ${_isAdmin ? "Administrator" : "Standard-Benutzer"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Abmelden bestätigen',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Bist du sicher, dass du dich abmelden möchtest?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
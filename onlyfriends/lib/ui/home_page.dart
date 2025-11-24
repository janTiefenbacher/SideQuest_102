import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'login_page.dart';
import 'quest_selection_page.dart';
import 'profile_page.dart';
import 'friend_profile_page.dart';
import 'edit_state.dart';
import 'widgets/post_card.dart';
import '../theme.dart';
import '../models/quest.dart';
import '../models/post.dart';
import '../services/quest_service.dart';
import '../services/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  static const String route = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tabIndex = 0; // 0=Feed,1=Freunde,2=Profil
  bool _hasPostedToday = false; // Track if user has posted today
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex);
    WidgetsBinding.instance.addObserver(this);
    _checkIfPostedToday();
    _clearAppBadgeOnStart();
    // Beim Start direkt Flame-Streak prüfen/zurücksetzen
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // ignore: unawaited_futures
      QuestService.reconcileFlameStreakOnAppStart(user.id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - clear badge
      _clearAppBadgeOnStart();
      // Reconcile flame streak if user missed a day
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // ignore: unawaited_futures
        QuestService.reconcileFlameStreakOnAppStart(user.id);
      }
    }
  }

  Future<void> _clearAppBadgeOnStart() async {
    try {
      print('Starting aggressive badge clear on app start...');
      
      // Method 1: Standard clear
      await NotificationService().clearAppBadge();
      
      // Method 2: Force clear as backup
      await NotificationService().forceClearIOSBadge();
      
      // Method 3: Additional nuclear option
      await _nuclearBadgeClear();
      
      print('Aggressive badge clear completed on startup');
    } catch (e) {
      print('Error clearing app badge on startup: $e');
    }
  }

  Future<void> _nuclearBadgeClear() async {
    try {
      print('Starting NUCLEAR badge clear...');
      
      // Cancel everything
      await NotificationService().clearAllNotifications();
      
      // Show 20 notifications with badge 0 and immediately cancel them
      for (int i = 0; i < 20; i++) {
        await NotificationService().showNotification(
          id: 6000 + i,
          title: '',
          body: '',
        );
        
        await Future.delayed(const Duration(milliseconds: 10));
        
        await NotificationService().clearAllNotifications();
      }
      
      print('NUCLEAR badge clear completed');
    } catch (e) {
      print('Error in nuclear badge clear: $e');
    }
  }

  Future<void> _checkIfPostedToday() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('posts')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .limit(1);

      if (mounted) {
        setState(() {
          _hasPostedToday = response.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking if posted today: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kSky, kBrightBlue],
              ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                width: double.infinity,
                alignment: Alignment.center,
                child: Image.asset('onlyfriends.png', height: 40),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _tabIndex = index;
                      });
                    },
                    children: [
                      _FeedTab(userId: user!.id),
                      _FriendsRequestsTab(currentUserId: user.id),
                      const ProfilePage(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 56,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        indicatorColor: kBrightBlue,
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          if (EditState.isEditingProfile.value) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil wird bearbeitet – erst speichern oder abbrechen.')),
            );
            return;
          }
          // Wechsel des Tabs per Klick UND Wischen synchron über PageView
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        },
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined, 
              size: 34,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : null,
            ),
            selectedIcon: Icon(
              Icons.home, 
              size: 34,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : null,
            ),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.group_outlined, 
              size: 34,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : null,
            ),
            selectedIcon: Icon(
              Icons.group, 
              size: 34,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : null,
            ),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outlined, 
              size: 34,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : null,
            ),
            selectedIcon: Icon(
              Icons.person, 
              size: 34,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : null,
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  const _ChallengeCard({super.key, required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  Quest? selectedQuest;
  bool hasQuestForToday = false;
  bool isQuestConfirmed = false;
  bool hasUploadedPhoto = false;
  String? uploadedImagePath;
  String? location;
  DateTime? uploadTime;
  int upvotes = 0;
  int downvotes = 0;
  Timer? _timer;
  Duration _timeUntilNextQuest = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadTodayQuest();
    _startTimer();
  }

  // Public method to refresh quest info (can be called from outside)
  void refreshQuestInfo() {
    _loadTodayQuest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateTimeUntilNextQuest();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeUntilNextQuest();
    });
  }

  void _updateTimeUntilNextQuest() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);
    
    if (mounted) {
      setState(() {
        _timeUntilNextQuest = timeUntilMidnight;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _loadTodayQuest() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    // First evaluate yesterday's quest and award points if successful
    await QuestService.evaluateAndAwardQuestPoints(user.id);
    
    final quest = await QuestService.getSelectedQuest(user.id);
    final isConfirmed = await QuestService.isQuestConfirmed(user.id);
    
    setState(() {
      if (quest != null) {
        selectedQuest = quest;
        hasQuestForToday = true;
        isQuestConfirmed = isConfirmed;
      } else {
        hasQuestForToday = false;
        isQuestConfirmed = false;
      }
    });
  }

  // Method to refresh quest information (called after censoring)
  void _refreshQuestInfo() async {
    await _loadTodayQuest();
  }

  Future<void> _notifyFriendsAboutPhoto(String userName) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get all friends
      final friendsResponse = await Supabase.instance.client
          .from('friendships')
          .select('requester, addressee')
          .or('requester.eq.${user.id},addressee.eq.${user.id}')
          .eq('status', 'accepted');

      final friends = friendsResponse as List;
      final friendIds = <String>[];

      for (final friend in friends) {
        final requester = friend['requester'] as String;
        final addressee = friend['addressee'] as String;
        final friendId = requester == user.id ? addressee : requester;
        friendIds.add(friendId);
      }

      // Send notification to each friend
      for (final friendId in friendIds) {
        await NotificationService().sendNotificationToUser(
          userId: friendId,
          title: '📸 $userName hat ein Foto geteilt!',
          body: 'Schau dir das neue Foto von $userName an!',
          data: {'type': 'photo_upload', 'user_id': user.id},
        );
      }
    } catch (e) {
      print('Error notifying friends about photo: $e');
    }
  }


  Future<void> _selectQuest() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    // Check if user has already selected a quest for today
    final hasSelectedQuest = await QuestService.hasSelectedQuestForToday(user.id);
    
    if (hasSelectedQuest) {
      // Show message that quest is already selected for today
      final selectedQuest = await QuestService.getSelectedQuestForToday(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Du hast bereits eine Quest für heute ausgewählt: ${selectedQuest?.title ?? "Unbekannt"}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const QuestSelectionPage(),
      ),
    );

    if (result != null) {
      if (result is Map && result['forceReload'] == true) {
        // Full reload of the quest info
        await _loadTodayQuest();
      } else if (result is Quest) {
        // Backward compatibility: update UI and soft refresh
        await NotificationService().notifyNewQuest(result.title);
        setState(() {
          selectedQuest = result;
          hasQuestForToday = true;
          isQuestConfirmed = true;
        });
        // ignore: unawaited_futures
        _loadTodayQuest();
        widget.onConfirm();
      }
    }
  }

  Future<String> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return 'Standort nicht verfügbar';
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return 'Standort-Berechtigung verweigert';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return 'Standort-Berechtigung dauerhaft verweigert';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('Current position: ${position.latitude}, ${position.longitude}');

      // Try to get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String location = '';
          
          // Only use the city/locality name, not the administrative area or country
          if (place.locality != null && place.locality!.isNotEmpty) {
            location = place.locality!;
          } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            location = place.subLocality!;
          } else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            location = place.administrativeArea!;
          }

          if (location.isNotEmpty) {
            print('Location found: $location');
            return location;
          }
        }
      } catch (e) {
        print('Error getting address: $e');
      }

      // Fallback to coordinates if address lookup fails
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (e) {
      print('Error getting location: $e');
      return 'Standort-Fehler: ${e.toString()}';
    }
  }


  Future<String?> _showCaptionDialog() async {
    final TextEditingController captionController = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 12,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kBrightBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note,
                  color: kBrightBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Caption hinzufügen',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Füge eine Beschreibung zu deinem Post hinzu:',
                  style: TextStyle(
                    fontSize: 14, 
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: captionController,
                  maxLines: 4,
                  maxLength: 200,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  cursorColor: kBrightBlue,
                  decoration: InputDecoration(
                    hintText: 'Was denkst du über diese Quest?',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBrightBlue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final caption = captionController.text.trim();
                Navigator.of(context).pop(caption.isEmpty ? 'Kein Text hinzugefügt' : caption);
              },
              style: FilledButton.styleFrom(
                backgroundColor: kBrightBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Posten'),
            ),
          ],
        );
      },
    );
  }

  Future<String> _flipImageHorizontally(String imagePath) async {
    try {
      // Read the image file
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decode the image
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        print('Failed to decode image');
        return imagePath; // Return original path if decoding fails
      }
      
      // Flip the image horizontally to correct front camera mirroring
      final img.Image flippedImage = img.flipHorizontal(originalImage);
      
      // Encode the flipped image as JPEG
      final List<int> flippedBytes = img.encodeJpg(flippedImage, quality: 85);
      
      // Create a new file path for the flipped image
      final String flippedPath = '${imagePath}_flipped.jpg';
      final File flippedFile = File(flippedPath);
      await flippedFile.writeAsBytes(flippedBytes);
      
      print('Image flipped successfully: $flippedPath');
      return flippedPath;
    } catch (e) {
      print('Error flipping image: $e');
      return imagePath; // Return original path if flipping fails
    }
  }

  Future<bool> _isFrontCameraImage(String imagePath) async {
    try {
      final fileBytes = await File(imagePath).readAsBytes();
      final tags = await readExifFromBytes(fileBytes);
      // Common EXIF keys: LensModel, Model, Make, Orientation, ImageDescription
      // Some devices provide 'CameraOwnerName' or 'LensSpecification'
      final imageDescription = tags["Image ImageDescription"]?.printable?.toLowerCase() ?? '';
      final lensModel = tags["EXIF LensModel"]?.printable?.toLowerCase() ?? '';
      final model = tags["Image Model"]?.printable?.toLowerCase() ?? '';

      // Heuristics for front camera
      if (imageDescription.contains('front') || lensModel.contains('front')) return true;
      if (model.contains('iphone') && (imageDescription.contains('front') || lensModel.contains('front'))) return true;

      // If no tag indicates front, assume back
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _takePhoto() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Check if user has selected a quest for today
      final hasSelectedQuest = await QuestService.hasSelectedQuestForToday(user.id);
      if (!hasSelectedQuest) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wähle zuerst deine Quest für heute aus!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if user has already posted today
      final hasPostedToday = await PostService.hasPostedToday(user.id);
      if (hasPostedToday) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Du hast heute bereits einen Post erstellt! Morgen kannst du wieder posten.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if camera is available
      final ImagePicker picker = ImagePicker();
      
      // Try to pick image from camera
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        // Let user choose camera (front or back)
      );

      if (image != null) {
        // Only flip if it was taken with front camera (EXIF-based)
        String finalImagePath = image.path;
        try {
          final isFront = await _isFrontCameraImage(image.path);
          if (isFront) {
            final flippedImagePath = await _flipImageHorizontally(image.path);
            finalImagePath = flippedImagePath;
          }
        } catch (e) {
          print('Front camera detection error: $e');
          finalImagePath = image.path;
        }
        
        // Check file size (max 1MB)
        final file = File(finalImagePath);
        final fileSize = await file.length();
        if (fileSize > 1024 * 1024) { // 1MB
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bild ist zu groß! Maximal 1MB erlaubt.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Get real location
        String locationName = await _getCurrentLocation();
        print('Location for post: $locationName');

        // Show caption input dialog
        final customCaption = await _showCaptionDialog();
        if (customCaption == null) {
          // User cancelled caption input
          return;
        }

        try {
          // Get user profile info
          final profileResponse = await Supabase.instance.client
              .from('profiles')
              .select('username, avatar_url')
              .eq('id', user.id)
              .single();
          
          final userName = profileResponse['username'] ?? user.email?.split('@').first ?? 'User';
          final userAvatar = profileResponse['avatar_url'];
          
          // Try to upload image first
          final imageUrl = await PostService.uploadImage(finalImagePath, user.id);
          
          Post? post;
          // Build caption including quest details and custom caption
          final questTitle = selectedQuest?.title ?? 'Unbekannte Quest';
          final questDifficulty = selectedQuest?.difficulty.label ?? 'Unbekannt';
          final questDescription = selectedQuest?.description ?? '';
          final caption = 'Quest: $questTitle\nSchwierigkeit: $questDifficulty\n$questDescription\n\n$customCaption';

          if (imageUrl != null) {
            // Create post with image
            post = await PostService.createPost(
              userId: user.id,
              userName: userName,
              userAvatar: userAvatar,
              imageUrl: imageUrl,
              caption: caption,
              location: locationName,
            );
          } else {
            // Fallback: Create post without image
            print('Image upload failed, creating post without image');
            post = await PostService.createPostWithoutImage(
              userId: user.id,
              userName: userName,
              userAvatar: userAvatar,
              caption: '$caption\n(Bild konnte nicht hochgeladen werden)',
              location: locationName,
            );
          }

          if (post != null) {
            // Update flame streak and notify all friends about the new photo
            await QuestService.incrementFlameStreakOnPost(user.id);
            await _notifyFriendsAboutPhoto(userName);
            
            if (mounted) {
              setState(() {
                uploadedImagePath = finalImagePath;
                hasUploadedPhoto = true;
                location = locationName;
                uploadTime = DateTime.now();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(imageUrl != null 
                    ? 'Foto erfolgreich hochgeladen und geteilt!'
                    : 'Post erstellt (Bild konnte nicht hochgeladen werden)'),
                  backgroundColor: imageUrl != null ? Colors.green : Colors.orange,
                ),
              );
              
              // Call the onConfirm callback to refresh the feed
              widget.onConfirm();
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fehler beim Speichern des Posts'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          print('Upload error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload-Fehler: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // User cancelled or no image selected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto-Aufnahme abgebrochen'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Aufnehmen des Fotos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: _selectQuest,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: hasQuestForToday && selectedQuest != null
                        ? _buildQuestDisplay()
                        : _buildQuestSelection(),
                  ),
                  const SizedBox(height: 12),
                  if (hasQuestForToday && selectedQuest != null)
                    isQuestConfirmed ? _buildQuestInfo() : _buildQuestButtons()
                  else
                    _buildQuestButtons(),
                ],
              ),
            ),
            // Timer in bottom right corner of the entire card
            if (hasQuestForToday && selectedQuest != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_timeUntilNextQuest),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestDisplay() {
    final difficulty = selectedQuest!.difficulty;
    final accent = difficulty.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: hasUploadedPhoto && uploadedImagePath != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(uploadedImagePath!),
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location ?? 'Unbekannter Ort',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 16, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      uploadTime != null
                          ? '${uploadTime!.hour.toString().padLeft(2, '0')}:${uploadTime!.minute.toString().padLeft(2, '0')}'
                          : '--:--',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildReactionChip(
                        icon: Icons.thumb_up,
                        label: upvotes.toString(),
                        color: Colors.greenAccent,
                        onTap: () => setState(() => upvotes++),
                      ),
                      const SizedBox(width: 16),
                      _buildReactionChip(
                        icon: Icons.thumb_down,
                        label: downvotes.toString(),
                        color: Colors.redAccent,
                        onTap: () => setState(() => downvotes++),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        difficulty.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedQuest!.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildMetaChip(
                                icon: Icons.local_fire_department,
                                text: difficulty.label,
                                color: accent,
                                lightText: true,
                              ),
                              const SizedBox(width: 6),
                              _buildMetaChip(
                                icon: Icons.emoji_events,
                                text: '${selectedQuest!.points} Punkte',
                                color: Colors.white,
                                lightText: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  selectedQuest!.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bleib im Flow! Bestätige deine Quest und halte deinen Streak am Leben.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuestSelection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'Wähle deine Quest für heute',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestInfo() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: selectedQuest!.difficulty.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                selectedQuest!.difficulty.label,
                style: TextStyle(
                  color: selectedQuest!.difficulty.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kSky,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${selectedQuest!.points} Punkte',
                style: const TextStyle(
                  color: kNavy,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            // Quest is confirmed - no change button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Bestätigt',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isQuestConfirmed && !hasUploadedPhoto) ...[
          const SizedBox(height: 8),
          // Photo upload button
          FilledButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Foto machen'),
            style: FilledButton.styleFrom(
              backgroundColor: kBrightBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestButtons() {
    return FilledButton(
      onPressed: _selectQuest,
      child: const Text('Quest wählen'),
    );
  }
}

Widget _buildReactionChip({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildMetaChip({
  required IconData icon,
  required String text,
  required Color color,
  required bool lightText,
}) {
  final background = lightText ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.15);
  final textColor = lightText ? Colors.white : Colors.black87;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.userEmail});
  final String userEmail;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundImage: AssetImage('assets/no_such.png'),
                  radius: 16,
                  backgroundColor: kSky,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userEmail.split('@').first,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kBrightBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Leicht',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Krems an der Donau, 14:26',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black12,
                height: 260,
                child: Center(
                  child: Icon(Icons.image, size: 80, color: Colors.black26),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                const Spacer(),
                const Icon(Icons.arrow_upward_outlined, size: 20),
                const SizedBox(width: 4),
                const Text('67'),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_downward_outlined, size: 20),
                const SizedBox(width: 4),
                const Text('69'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Tabs
class _FeedTab extends StatefulWidget {
  const _FeedTab({required this.userId});
  final String userId;

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  late final SupabaseClient _client;
  List<Post> _posts = [];
  bool _loading = true;
  bool _hasPostedToday = false; // Track if user has posted today
  bool _hasSelectedQuest = false; // Track if user has selected a quest today

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _load();
  }

  Future<void> _checkIfPostedToday() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('posts')
          .select('id')
          .eq('user_id', widget.userId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .limit(1);

      if (mounted) {
        setState(() {
          _hasPostedToday = response.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking if posted today: $e');
    }
  }

  Future<void> _checkIfSelectedQuest() async {
    try {
      final hasSelected = await QuestService.hasSelectedQuestForToday(widget.userId);
      if (mounted) {
        setState(() {
          _hasSelectedQuest = hasSelected;
        });
      }
    } catch (e) {
      print('Error checking if selected quest: $e');
      if (mounted) {
        setState(() {
          _hasSelectedQuest = false;
        });
      }
    }
  }

  Future<void> _load() async {
    try {
      print('Loading posts for user: ${widget.userId}');
      
      // Ensure old posts from previous days are cleaned up (all users)
      await PostService.cleanupOldPosts();

      // Load all posts using PostService
      final posts = await PostService.getFriendsPosts();
      
      print('Loaded ${posts.length} posts');
      
      // Check if user has posted today
      await _checkIfPostedToday();
      
      // Check if user has selected a quest today
      await _checkIfSelectedQuest();
      
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _posts = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
            itemCount: 1 + _posts.length + (_posts.isEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == 0) {
                // Only show challenge card if user hasn't posted today
                if (!_hasPostedToday) {
                  return Column(
                    children: [
                      // Always show challenge card normally in the feed
                      _ChallengeCard(onConfirm: () {
                        // Refresh the feed after posting
                        _load();
                      }),
                      const SizedBox(height: 16),
                    ],
                  );
                } else {
                  return const SizedBox.shrink(); // Hide challenge card
                }
              }
          
          // Show empty state if no posts
          if (_posts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Noch keine Posts vorhanden',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Teile deine erste Quest mit deinen Freunden!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          // Use the Post object directly from PostService
          final post = _posts[index - 1];
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PostCard(
                post: post,
                onDelete: () {
                  _load();
                },
              ),
              Divider(
                height: 1,
                thickness: 0.8,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white24
                    : Colors.black12,
              ),
            ],
          );
        },
      ),
    ),
        // Quest container is now always in the normal flow, never fixed
        // Test buttons removed - now available in Admin Test Menu
      ],
    );
  }
}

class _FriendsTab extends StatefulWidget {
  const _FriendsTab({required this.currentUserId});
  final String currentUserId;

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  final TextEditingController _emailController = TextEditingController();
  bool _sending = false;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;
  final Set<String> _relatedIds = {};
  final Set<String> _onlineIds = {};
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _friendshipChannel;
  final Map<String, DateTime> _lastSeen = {};
  Timer? _heartbeatTimer;
  // Cache of friend profiles to avoid per-item network reloads
  Map<String, Map<String, dynamic>> _profileById = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _setupPresence();
    _subscribeFriendshipChanges();
  }

  Future<void> _loadFriends() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('friendships')
        .select('requester, addressee, status')
        .or(
          'requester.eq.${widget.currentUserId},addressee.eq.${widget.currentUserId}',
        )
        .eq('status', 'accepted');
    final friends = List<Map<String, dynamic>>.from(rows as List);
    // Build unique friend id set
    final Set<String> friendIds = {};
    for (final r in friends) {
      final requester = r['requester'] as String;
      final addressee = r['addressee'] as String;
      final other = requester == widget.currentUserId ? addressee : requester;
      if (other != widget.currentUserId) friendIds.add(other);
    }
    // Batch load friend profiles once
    if (friendIds.isNotEmpty) {
      final profiles = await client
          .from('profiles')
          .select('id, username, avatar_url')
          .inFilter('id', friendIds.toList());
      final map = <String, Map<String, dynamic>>{};
      for (final p in (profiles as List)) {
        map[p['id'] as String] = Map<String, dynamic>.from(p as Map);
      }
      _profileById = map;
    } else {
      _profileById = {};
    }
    setState(() => _friends = friends);
    // collect ids with any relationship to filter from search
    final related = await client
        .from('friendships')
        .select('requester, addressee')
        .or(
          'requester.eq.${widget.currentUserId},addressee.eq.${widget.currentUserId}',
        );
    _relatedIds
      ..clear()
      ..addAll(
        (related as List).map<String>((r) {
          final requester = r['requester'] as String;
          final addressee = r['addressee'] as String;
          return requester == widget.currentUserId ? addressee : requester;
        }),
      );
  }

  Future<void> _sendRequestTo(String targetId) async {
    setState(() => _sending = true);
    final client = Supabase.instance.client;
    try {
      await client.from('friendships').insert({
        'requester': widget.currentUserId,
        'addressee': targetId,
        'status': 'pending',
      });
      
      // Send notification to the target user
      await _notifyFriendRequest(targetId);
      
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Anfrage gesendet')));
      _relatedIds.add(targetId);
      _searchResults.removeWhere((e) => e['id'] == targetId);
      setState(() {});
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _notifyFriendRequest(String targetUserId) async {
    try {
      // Get current user's name
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();

      final userName = profileResponse['username'] ?? user.email?.split('@').first ?? 'Jemand';

      // Send notification to target user
      await NotificationService().sendNotificationToUser(
        userId: targetUserId,
        title: '👋 Neue Freundschaftsanfrage!',
        body: '$userName möchte dein Freund werden',
        data: {'type': 'friend_request', 'requester_id': user.id},
      );
    } catch (e) {
      print('Error notifying friend request: $e');
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(value);
    });
  }

  Future<void> _searchUsers(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final client = Supabase.instance.client;
    final query = client
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%${q.trim()}%')
        .neq('id', widget.currentUserId)
        .limit(10);
    final res = await query;
    final list = List<Map<String, dynamic>>.from(res as List);
    final filtered =
        list.where((e) => !_relatedIds.contains(e['id'] as String)).toList();
    setState(() {
      _searchResults = filtered;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _emailController.dispose();
    _presenceChannel?.unsubscribe();
    _friendshipChannel?.unsubscribe();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _removeFriend(String friendUserId) async {
    final client = Supabase.instance.client;
    await client
        .from('friendships')
        .delete()
        .or(
          'and(requester.eq.${widget.currentUserId},addressee.eq.$friendUserId),and(addressee.eq.${widget.currentUserId},requester.eq.$friendUserId)',
        );
    _relatedIds.remove(friendUserId);
    _loadFriends();
  }

  Future<void> _confirmRemove(String friendUserId, String friendName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_remove_alt_1_outlined,
                color: Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Freund entfernen?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Möchtest du $friendName wirklich entfernen?',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _removeFriend(friendUserId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Freund entfernt')));
      }
    }
  }

  void _setupPresence() {
    final client = Supabase.instance.client;
    final me = widget.currentUserId;
    final channel = client.channel('presence_online');
    _presenceChannel =
        channel
          ..onBroadcast(
            event: 'presence',
            callback: (payload) {
              final map = payload['payload'] as Map? ?? {};
              final uid = map['user_id'] as String?;
              final ts = DateTime.tryParse(map['ts'] as String? ?? '');
              if (uid != null && ts != null) {
                _lastSeen[uid] = ts;
                _recomputeOnline();
              }
            },
          )
          ..subscribe();

    void sendBeat() {
      channel.sendBroadcastMessage(
        event: 'presence',
        payload: {
          'user_id': me,
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      );
      _lastSeen[me] = DateTime.now().toUtc();
      _recomputeOnline();
    }

    // initial and periodic heartbeat
    sendBeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => sendBeat(),
    );
    // cleanup timer
    Timer.periodic(const Duration(seconds: 5), (_) => _recomputeOnline());
  }

  void _subscribeFriendshipChanges() {
    final client = Supabase.instance.client;
    _friendshipChannel = client
      .channel('public:friendships')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friendships',
        callback: (payload) {
          _loadFriends();
        },
      )..subscribe();
  }

  void _recomputeOnline() {
    final now = DateTime.now().toUtc();
    final ids = <String>{};
    _lastSeen.removeWhere(
      (key, value) => now.difference(value) > const Duration(seconds: 30),
    );
    ids.addAll(_lastSeen.keys);
    if (mounted)
      setState(() {
        _onlineIds
          ..clear()
          ..addAll(ids);
      });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Freund per Username hinzufügen',
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
            ),
            hintText: 'Namen eingeben…',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              onPressed:
                  _sending || _searchResults.isEmpty
                      ? null
                      : () => _sendRequestTo(_searchResults.first['id'] as String),
              icon: const Icon(Icons.send),
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          cursorColor: kBrightBlue,
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: 12),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Vorschläge'),
          const SizedBox(height: 4),
          for (final u in _searchResults)
            Card(
              child: ListTile(
                leading: u['avatar_url'] != null && u['avatar_url'].isNotEmpty
                    ? ClipOval(
                        child: u['avatar_url'].startsWith('data:')
                            ? Image.memory(
                                base64Decode(u['avatar_url'].split(',')[1]),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: u['avatar_url'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 40,
                                  height: 40,
                                  color: kBrightBlue.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person_outline, color: kBrightBlue),
                                ),
                              ),
                      )
                    : CircleAvatar(
                        child: const Icon(Icons.person_outline),
                      ),
                title: Text(u['username'] ?? 'User'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FriendProfilePage(
                        userId: u['id'] as String,
                        initialUserName: u['username'] as String?,
                      ),
                    ),
                  );
                },
                trailing: FilledButton.icon(
                  onPressed:
                      _sending ? null : () => _sendRequestTo(u['id'] as String),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Hinzufügen'),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        for (int i = 0; i < _friends.length; i++)
          Column(
            children: [
              Builder(builder: (context) {
                final fid = _friendId(_friends[i], widget.currentUserId);
                final data = _profileById[fid];
                final uname = (data?['username'] as String?) ?? 'User';
                final avatarUrl = data?['avatar_url'] as String?;
                return ListTile(
                  leading: Stack(
                    children: [
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? ClipOval(
                              child: avatarUrl.startsWith('data:')
                                  ? Image.memory(
                                      base64Decode(avatarUrl.split(',')[1]),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 40,
                                        height: 40,
                                        color: kBrightBlue.withValues(alpha: 0.1),
                                        child: const Icon(Icons.person, color: kBrightBlue),
                                      ),
                                    ),
                            )
                          : const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color:
                                _onlineIds.contains(fid)
                                    ? Colors.green
                                    : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(uname),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FriendProfilePage(
                          userId: fid,
                          initialUserName: uname,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove_alt_1_outlined),
                    onPressed: () => _confirmRemove(fid, uname),
                    tooltip: 'Freund entfernen',
                  ),
                );
              }),
              // Add divider between friends (except for the last one)
              if (i < _friends.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black12,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _friendId(Map<String, dynamic> row, String me) {
    final requester = row['requester'] as String;
    final addressee = row['addressee'] as String;
    return requester == me ? addressee : requester;
  }
}

class _FriendsRequestsTab extends StatelessWidget {
  const _FriendsRequestsTab({required this.currentUserId});
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.onSurface,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: kBrightBlue,
              tabs: const [
                Tab(text: 'Freunde'),
                Tab(text: 'Anfragen'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _FriendsTab(currentUserId: currentUserId),
                _RequestsTab(currentUserId: currentUserId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestsTab extends StatefulWidget {
  const _RequestsTab({required this.currentUserId});
  final String currentUserId;

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  List<Map<String, dynamic>> _incoming = [];
  RealtimeChannel? _requestsChannel;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRequestChanges();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from('friendships')
        .select('id, requester, addressee, status')
        .eq('addressee', widget.currentUserId)
        .eq('status', 'pending');
    setState(() => _incoming = List<Map<String, dynamic>>.from(rows as List));
  }

  void _subscribeRequestChanges() {
    final client = Supabase.instance.client;
    _requestsChannel = client
        .channel('public:friendships_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) {
            try {
              final currentUserId = widget.currentUserId;
              // Payload can have 'new' or 'old'. We check both for transitions.
              final Map<String, dynamic>? newRow =
                  (payload.newRecord as Map?)?.cast<String, dynamic>();
              final Map<String, dynamic>? oldRow =
                  (payload.oldRecord as Map?)?.cast<String, dynamic>();

              bool affectsMePending = false;
              if (newRow != null) {
                final addressee = newRow['addressee'] as String?;
                final status = newRow['status'] as String?;
                if (addressee == currentUserId && status == 'pending') {
                  affectsMePending = true;
                }
              }
              if (!affectsMePending && oldRow != null) {
                final addressee = oldRow['addressee'] as String?;
                final status = oldRow['status'] as String?;
                if (addressee == currentUserId && status == 'pending') {
                  // pending was changed (accepted/declined/deleted) → list should update
                  affectsMePending = true;
                }
              }

              if (affectsMePending) {
                // Reload list quietly
                _load();
              }
            } catch (_) {}
          },
        )
        ..subscribe();
  }

  Future<void> _respond(String id, String status) async {
    await Supabase.instance.client
        .from('friendships')
        .update({'status': status})
        .eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _incoming.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_disabled,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Zurzeit keine Anfragen',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Du hast momentan keine Freundschaftsanfragen',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _incoming.length,
              itemBuilder: (context, i) {
          final row = _incoming[i];
          return Column(
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Supabase.instance.client
                    .from('profiles')
                    .select('username, avatar_url')
                    .eq('id', row['requester'] as String)
                    .limit(1),
                builder: (context, snap) {
                  final data = snap.data != null && snap.data!.isNotEmpty
                      ? snap.data!.first
                      : null;
                  final uname = data?['username'] as String? ?? 'User';
                  final avatarUrl = data?['avatar_url'] as String?;
                  return Card(
                    child: ListTile(
                      leading: avatarUrl != null && avatarUrl.isNotEmpty
                          ? ClipOval(
                              child: avatarUrl.startsWith('data:')
                                  ? Image.memory(
                                      base64Decode(avatarUrl.split(',')[1]),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 40,
                                        height: 40,
                                        color: kBrightBlue.withValues(alpha: 0.1),
                                        child: const Icon(Icons.person, color: kBrightBlue),
                                      ),
                                    ),
                            )
                          : CircleAvatar(
                              child: const Icon(Icons.person),
                            ),
                      title: Text(uname),
                      subtitle: const Text('möchte befreundet sein'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed:
                                () => _respond(row['id'] as String, 'declined'),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            onPressed:
                                () => _respond(row['id'] as String, 'accepted'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Add divider between requests (except for the last one)
              if (i < _incoming.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black12,
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _requestsChannel?.unsubscribe();
    super.dispose();
  }
}

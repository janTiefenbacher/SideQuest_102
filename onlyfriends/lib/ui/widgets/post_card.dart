import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../../models/post.dart';
import '../../models/comment.dart';
import '../../services/quest_service.dart';
import '../../theme.dart';
import '../comments_page.dart';
import '../friend_profile_page.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onDelete;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onDislike,
    this.onDelete,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  bool _isDisliked = false;
  int _upvotes = 0;
  int _downvotes = 0;
  int _commentCount = 0;
  bool _hasSelectedQuest = false;
  bool _isOwnPost = false;
  late final TransformationController _imageTransformController;

  @override
  void initState() {
    super.initState();
    _imageTransformController = TransformationController();
    _isLiked = widget.post.isLiked;
    _isDisliked = widget.post.isDisliked;
    _upvotes = widget.post.upvotes;
    _downvotes = widget.post.downvotes;
    _isOwnPost = widget.post.userId == Supabase.instance.client.auth.currentUser?.id;
    _loadCommentCount();
    _checkQuestSelection();
  }

  @override
  void dispose() {
    _imageTransformController.dispose();
    super.dispose();
  }

  Future<void> _loadCommentCount() async {
    try {
      final comments = await CommentService.getCommentsForPost(widget.post.id);
      if (mounted) {
        setState(() {
          _commentCount = comments.length;
        });
      }
    } catch (e) {
      print('Error loading comment count: $e');
    }
  }

  Future<void> _checkQuestSelection() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final hasQuest = await QuestService.hasSelectedQuestForToday(userId);
        if (mounted) {
          setState(() {
            _hasSelectedQuest = hasQuest;
          });
        }
      }
    } catch (e) {
      print('Error checking quest selection: $e');
    }
  }

  void _handleLike() async {
    // Prevent self-voting
    if (_isOwnPost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Du kannst deinen eigenen Post nicht bewerten.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    // Check if user has selected a quest
    if (!_hasSelectedQuest && !_isOwnPost) {
      _navigateToQuestSelection();
      return;
    }
    
    // Update in database first
    bool success = false;
    if (_isLiked) {
      success = await PostService.unlikePost(widget.post.id);
    } else {
      success = await PostService.likePost(widget.post.id);
    }
    
    // Only update UI if database operation was successful
    if (success) {
      setState(() {
        if (_isLiked) {
          _isLiked = false;
          _upvotes--;
        } else {
          if (_isDisliked) {
            _isDisliked = false;
            _downvotes--;
          }
          _isLiked = true;
          _upvotes++;
        }
      });
      
      widget.onLike?.call();
    }
  }

  void _handleDislike() async {
    // Prevent self-voting
    if (_isOwnPost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Du kannst deinen eigenen Post nicht bewerten.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    // Check if user has selected a quest
    if (!_hasSelectedQuest && !_isOwnPost) {
      _navigateToQuestSelection();
      return;
    }
    
    // Update in database first
    bool success = false;
    if (_isDisliked) {
      success = await PostService.undislikePost(widget.post.id);
    } else {
      success = await PostService.dislikePost(widget.post.id);
    }
    
    // Only update UI if database operation was successful
    if (success) {
      setState(() {
        if (_isDisliked) {
          _isDisliked = false;
          _downvotes--;
        } else {
          if (_isLiked) {
            _isLiked = false;
            _upvotes--;
          }
          _isDisliked = true;
          _downvotes++;
        }
      });
      
      widget.onDislike?.call();
    }
  }

  void _openComments() {
    // Check if user has selected a quest
    if (!_hasSelectedQuest && !_isOwnPost) {
      _navigateToQuestSelection();
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommentsPage(
          postId: widget.post.id,
          postUserName: widget.post.userName,
          postUserAvatar: widget.post.userAvatar,
          postImageUrl: widget.post.imageUrl,
          postCaption: widget.post.caption,
        ),
      ),
    ).then((_) {
      // Reload comment count when returning from comments page
      _loadCommentCount();
    });
  }

  void _navigateToQuestSelection() {
    Navigator.of(context).pushNamed('/quest-selection').then((_) {
      // Check quest selection again when returning
      _checkQuestSelection();
    });
  }

  void _showReportMenu() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorOnSurface = Theme.of(context).colorScheme.onSurface;
    final bgColor = Theme.of(context).colorScheme.surface;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.flag_outlined, color: colorOnSurface.withOpacity(0.8)),
                title: Text('Melden', style: TextStyle(color: colorOnSurface)),
                subtitle: Text('Problem mit diesem Post melden', style: TextStyle(color: colorOnSurface.withOpacity(0.7))),
              ),
              const Divider(height: 1),
              _buildReportOption('Anstößige Inhalte', 'nudity, sexuell explizit, etc.'),
              _buildReportOption('Hassrede oder Mobbing', 'Beleidigungen, Drohungen'),
              _buildReportOption('Gewalt oder gefährliche Handlungen', 'Selbst-/Fremdgefährdung'),
              _buildReportOption('Spam oder Betrug', 'Scams, Fake-Gewinnspiele'),
              _buildReportOption('Urheberrechtsverletzung', 'Fremde Inhalte ohne Rechte'),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: isDark ? Colors.white70 : Colors.black54),
                title: Text('Abbrechen', style: TextStyle(color: colorOnSurface, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, null),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (result != null) {
      // For now just acknowledge; future: send to Supabase moderation table
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            content: Row(
              children: [
                const Icon(Icons.flag, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Danke für deine Meldung: $result',
                    style: TextStyle(color: colorOnSurface),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Widget _buildReportOption(String title, String subtitle) {
    final colorOnSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: const Icon(Icons.report_gmailerrorred_outlined, color: Colors.redAccent),
      title: Text(title, style: TextStyle(color: colorOnSurface)),
      subtitle: Text(subtitle, style: TextStyle(color: colorOnSurface.withOpacity(0.7))),
      onTap: () => Navigator.pop(context, title),
    );
  }

  void _handleDelete() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Post löschen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Möchtest du diesen Post wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
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
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await PostService.deletePost(widget.post.id);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post erfolgreich gelöscht'),
                backgroundColor: Colors.green,
              ),
            );
            widget.onDelete?.call();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fehler beim Löschen des Posts'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'gerade eben';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }

  Color _roleColor(String role) {
    final r = role.toLowerCase();
    if (r == 'admin') return const Color(0xFFEF5350);
    if (r == 'vip') return const Color(0xFFFFC107);
    if (r == 'mod' || r == 'moderator') return const Color(0xFF42A5F5);
    return kBrightBlue;
  }

  String _extractDifficulty(String caption) {
    try {
      final idx = caption.indexOf('Schwierigkeit:');
      if (idx == -1) return '';
      final after = caption.substring(idx + 'Schwierigkeit:'.length).trim();
      final firstLine = after.split('\n').first.trim();
      return firstLine.isEmpty ? '' : firstLine;
    } catch (_) {
      return '';
    }
  }

  Color _getDifficultyColor(String difficulty) {
    final d = difficulty.toLowerCase();
    if (d.contains('leicht') || d.contains('easy')) return Colors.green;
    if (d.contains('mittel') || d.contains('medium')) return Colors.orange;
    if (d.contains('schwer') || d.contains('hard')) return Colors.red;
    return Colors.grey;
  }

  int _getDifficultyStars(String difficulty) {
    final d = difficulty.toLowerCase();
    if (d.contains('leicht') || d.contains('easy')) return 1;
    if (d.contains('mittel') || d.contains('medium')) return 2;
    if (d.contains('schwer') || d.contains('hard')) return 3;
    return 1;
  }

  Widget _buildDifficultyBanner(String difficulty) {
    final color = _getDifficultyColor(difficulty);
    final stars = _getDifficultyStars(difficulty);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stars
          ...List.generate(stars, (index) => Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              Icons.star,
              size: 14,
              color: color,
            ),
          )),
          const SizedBox(width: 6),
          Text(
            difficulty,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyPill(String difficulty, {bool isDisabled = false}) {
    final color = _getDifficultyColor(difficulty);
    final stars = _getDifficultyStars(difficulty);
    final effectiveColor = isDisabled ? Colors.grey : color;
    final alpha = isDisabled ? 0.3 : 1.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: isDisabled ? 0.05 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: isDisabled ? 0.1 : 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(stars, (i) => Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(Icons.star, size: 12, color: effectiveColor.withValues(alpha: alpha)),
          )),
          const SizedBox(width: 4),
          Text(
            difficulty,
            style: TextStyle(
              color: effectiveColor.withValues(alpha: alpha),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuestInfo(String caption) {
    // Parse quest title and description from caption
    String title = 'Quest';
    String description = caption;
    final questIdx = caption.indexOf('Quest:');
    if (questIdx != -1) {
      final after = caption.substring(questIdx + 'Quest:'.length).trim();
      final lines = after.split('\n');
      if (lines.isNotEmpty) {
        title = lines.first.trim();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBrightBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.emoji_events,
                color: kBrightBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kNavy,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
          child: SingleChildScrollView(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDifficultyInfo =
        widget.post.caption != null && widget.post.caption!.contains('Schwierigkeit:');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Header with user info
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // User avatar - tap to open friend profile
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FriendProfilePage(
                          userId: widget.post.userId,
                          initialUserName: widget.post.userName,
                        ),
                      ),
                    );
                  },
                  child: widget.post.userAvatar != null
                    ? ClipOval(
                        child: widget.post.userAvatar!.startsWith('data:')
                            ? Image.memory(
                                base64Decode(widget.post.userAvatar!.split(',')[1]),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: widget.post.userAvatar!,
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
                                  child: Text(
                                    widget.post.userName.isNotEmpty
                                        ? widget.post.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: kBrightBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                      )
                    : CircleAvatar(
                        radius: 20,
                        backgroundColor: kBrightBlue.withValues(alpha: 0.1),
                        child: Text(
                          widget.post.userName.isNotEmpty
                              ? widget.post.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: kBrightBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                ),
                const SizedBox(width: 12),
                // User name, role, difficulty and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FriendProfilePage(
                                      userId: widget.post.userId,
                                      initialUserName: widget.post.userName,
                                    ),
                                  ),
                                );
                              },
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    widget.post.userName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (widget.post.userRole != null &&
                                      widget.post.userRole!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _roleColor(widget.post.userRole!).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        widget.post.userRole!.toUpperCase(),
                                        style: TextStyle(
                                          color: _roleColor(widget.post.userRole!),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (hasDifficultyInfo) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (_hasSelectedQuest || _isOwnPost) {
                                  _showQuestInfo(widget.post.caption!);
                                } else {
                                  _navigateToQuestSelection();
                                }
                              },
                              child: _buildDifficultyPill(
                                _extractDifficulty(widget.post.caption!),
                                isDisabled: !_hasSelectedQuest && !_isOwnPost,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimeAgo(widget.post.createdAt),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button for own posts
                if (widget.post.userId == Supabase.instance.client.auth.currentUser?.id) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleDelete,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                // Overflow menu (three dots) for reporting
                GestureDetector(
                  onTap: _showReportMenu,
                  child: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // Image (edge-to-edge) - blurred if no quest selected and not own post
          if (widget.post.imageUrl != null)
            AspectRatio(
              aspectRatio: 1, // square like Instagram
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                children: [
                  // Main image with pinch-to-zoom functionality
                  InteractiveViewer(
                    transformationController: _imageTransformController,
                    minScale: 1.0,
                    maxScale: 3.0,
                    onInteractionEnd: (details) {
                      // Reset back to original scale/position when user releases
                      _imageTransformController.value = Matrix4.identity();
                    },
                    child: widget.post.imageUrl!.startsWith('data:')
                        ? Image.memory(
                            base64Decode(widget.post.imageUrl!.split(',')[1]),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: widget.post.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white12
                                  : Colors.grey.withValues(alpha: 0.1),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white12
                                  : Colors.grey.withValues(alpha: 0.1),
                              child: const Center(
                                child: Icon(
                                  Icons.error,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Blur overlay if no quest selected and not own post
                  if (!_hasSelectedQuest && !_isOwnPost)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  // Quest selection prompt - positioned above the blur
                  if (!_hasSelectedQuest && !_isOwnPost)
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Wähle deine Quest',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'um Posts zu sehen',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _navigateToQuestSelection,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kBrightBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Quest wählen',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ),
            ),
          // Location display (now under the image)
          if (widget.post.location != null && widget.post.location!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: kBrightBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.post.location!,
                    style: TextStyle(
                      fontSize: 14,
                      color: kBrightBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          // Caption - positioned between location and actions
          if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
            Builder(
              builder: (context) {
                String userCaption = widget.post.caption!;
                final questEndIdx = userCaption.indexOf('\n\n');
                if (questEndIdx != -1) {
                  userCaption = userCaption.substring(questEndIdx + 2).trim();
                }

                if (userCaption.isNotEmpty && userCaption != 'Kein Text hinzugefügt') {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: Text(
                      userCaption,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          // Action buttons (also under the image)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                // Like button (arrow up)
                GestureDetector(
                  onTap: _handleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_up_outlined,
                        color: (!_hasSelectedQuest && !_isOwnPost) 
                            ? Colors.grey.withOpacity(0.5)
                            : (_isLiked ? kBrightBlue : Colors.grey),
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _upvotes.toString(),
                        style: TextStyle(
                          color: (!_hasSelectedQuest && !_isOwnPost)
                              ? Colors.grey.withOpacity(0.5)
                              : (_isLiked ? kBrightBlue : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Dislike button (arrow down)
                GestureDetector(
                  onTap: _handleDislike,
                  child: Row(
                    children: [
                      Icon(
                        _isDisliked ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_down_outlined,
                        color: (!_hasSelectedQuest && !_isOwnPost)
                            ? Colors.grey.withOpacity(0.5)
                            : (_isDisliked ? Colors.red : Colors.grey),
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _downvotes.toString(),
                        style: TextStyle(
                          color: (!_hasSelectedQuest && !_isOwnPost)
                              ? Colors.grey.withOpacity(0.5)
                              : (_isDisliked ? Colors.red : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Comment button
                GestureDetector(
                  onTap: _openComments,
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: (!_hasSelectedQuest && !_isOwnPost)
                            ? Colors.grey.withOpacity(0.5)
                            : Colors.grey,
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _commentCount.toString(),
                        style: TextStyle(
                          color: (!_hasSelectedQuest && !_isOwnPost)
                              ? Colors.grey.withOpacity(0.5)
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Share button
                GestureDetector(
                  onTap: () {
                    // TODO: Implement share functionality
                  },
                  child: const Icon(
                    Icons.share,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
    );
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? userRole;
  final String? imageUrl;
  final String? caption;
  final String? location;
  final DateTime createdAt;
  final int upvotes;
  final int downvotes;
  final bool isLiked;
  final bool isDisliked;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userRole,
    this.imageUrl,
    this.caption,
    this.location,
    required this.createdAt,
    this.upvotes = 0,
    this.downvotes = 0,
    this.isLiked = false,
    this.isDisliked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String?,
      userRole: json['user_role'] as String?,
      imageUrl: json['image_url'] as String?,
      caption: json['content'] as String?, // Use 'content' instead of 'caption'
      location: json['location'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      upvotes: json['upvotes'] as int? ?? 0, // Default to 0 if column doesn't exist
      downvotes: json['downvotes'] as int? ?? 0, // Default to 0 if column doesn't exist
      isLiked: json['is_liked'] as bool? ?? false, // Default to false if column doesn't exist
      isDisliked: json['is_disliked'] as bool? ?? false, // Default to false if column doesn't exist
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'user_role': userRole,
      'image_url': imageUrl,
      'content': caption, // Use 'content' instead of 'caption'
      'location': location,
      'created_at': createdAt.toIso8601String(),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'is_liked': isLiked,
      'is_disliked': isDisliked,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userRole,
    String? imageUrl,
    String? caption,
    String? location,
    DateTime? createdAt,
    int? upvotes,
    int? downvotes,
    bool? isLiked,
    bool? isDisliked,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userRole: userRole ?? this.userRole,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
    );
  }
}

class PostService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Check if user has already posted today
  static Future<bool> hasPostedToday(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _supabase
          .from('posts')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .limit(1);

      final hasPosted = (response as List).isNotEmpty;
      print('User $userId has posted today: $hasPosted');
      return hasPosted;
    } catch (e) {
      print('Error checking if user posted today: $e');
      return false;
    }
  }

  // Get all posts from friends
  static Future<List<Post>> getFriendsPosts() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        print('No authenticated user found');
        return [];
      }

      // Only show today's posts (from midnight)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Get friends list
      final friendsRes = await _supabase
          .from('friendships')
          .select('requester, addressee')
          .or('requester.eq.$currentUserId,addressee.eq.$currentUserId')
          .eq('status', 'accepted');

      final Set<String> friendIds = {};
      for (final row in friendsRes as List) {
        final requester = row['requester'] as String;
        final addressee = row['addressee'] as String;
        final other = requester == currentUserId ? addressee : requester;
        friendIds.add(other);
      }
      // Include self
      friendIds.add(currentUserId);

      if (friendIds.isEmpty) {
        print('No friends found, returning empty list');
        return [];
      }

      final response = await _supabase
          .from('posts')
          .select('*, post_likes(user_id), post_dislikes(user_id)')
          .inFilter('user_id', friendIds.toList())
          .gte('created_at', startOfDay.toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      print('Fetched posts: ${response.length}');
      print('Posts data: $response');

      final posts = (response as List)
          .map((json) {

            // Handle votes
            final List<dynamic> likes = json['post_likes'] as List<dynamic>? ?? [];
            final List<dynamic> dislikes = json['post_dislikes'] as List<dynamic>? ?? [];
            
            final isLiked = likes.any((like) => like['user_id'] == currentUserId);
            final isDisliked = dislikes.any((dislike) => dislike['user_id'] == currentUserId);
            
            // Calculate actual vote counts from the likes/dislikes arrays
            final actualUpvotes = likes.length;
            final actualDownvotes = dislikes.length;

            return Post.fromJson({
              ...json,
              'is_liked': isLiked,
              'is_disliked': isDisliked,
              'upvotes': actualUpvotes,  // Use actual count from likes array
              'downvotes': actualDownvotes,  // Use actual count from dislikes array
            });
          })
          .toList();

      // Load avatars and usernames for all posts
      final userIds = posts.map((post) => post.userId).toSet().toList();
      
      List<dynamic> profileResponse;
      try {
        profileResponse = await _supabase
            .from('profiles')
            .select('id, username, avatar_url, role')
            .inFilter('id', userIds);
      } on PostgrestException catch (e) {
        // Fallback for databases without 'role' column yet
        if (e.message.contains('column') && e.message.contains('role')) {
          profileResponse = await _supabase
              .from('profiles')
              .select('id, username, avatar_url')
              .inFilter('id', userIds);
        } else {
          rethrow;
        }
      }
      
      final profileMap = <String, Map<String, dynamic>>{};
      for (final profile in profileResponse as List) {
        profileMap[profile['id'] as String] = {
          'username': profile['username'] as String?,
          'avatar_url': profile['avatar_url'] as String?,
          'role': profile.containsKey('role') ? profile['role'] as String? : null,
        };
      }
      
      // Update posts with usernames and avatars
      for (int i = 0; i < posts.length; i++) {
        final post = posts[i];
        final profileData = profileMap[post.userId];
        if (profileData != null) {
          final username = profileData['username'] as String?;
          final avatarUrl = profileData['avatar_url'] as String?;
          
          // Update the post with username and avatar URL
          // Always use the username from profiles table if available, otherwise fallback to original
          final updatedPost = post.copyWith(
            userName: username?.isNotEmpty == true ? username! : post.userName,
            userAvatar: avatarUrl,
            userRole: profileData['role'] as String?,
          );
          posts[i] = updatedPost;
        }
      }

      // Sort posts: own posts first, then friends' posts
      posts.sort((a, b) {
        if (a.userId == currentUserId && b.userId != currentUserId) {
          return -1; // a comes first
        } else if (a.userId != currentUserId && b.userId == currentUserId) {
          return 1; // b comes first
        } else {
          return b.createdAt.compareTo(a.createdAt); // Sort by date
        }
      });

      return posts;
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  // Delete ALL posts older than today (BeReal-style: posts only last one day)
  static Future<void> cleanupOldPosts() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Fetch ALL old posts (created before today) - not just current user
      final oldPosts = await _supabase
          .from('posts')
          .select('id')
          .lt('created_at', startOfDay.toIso8601String());

      print('Found ${oldPosts.length} old posts to delete');

      for (final row in (oldPosts as List)) {
        final postId = row['id'] as String;
        
        // Delete the post row (images are base64 data URLs, no storage cleanup needed)
        await _supabase.from('posts').delete().eq('id', postId);
      }
      
      print('Successfully deleted ${oldPosts.length} old posts');
    } catch (e) {
      print('cleanupOldPosts error: $e');
    }
  }

  // Create a new post
  static Future<Post?> createPost({
    required String userId,
    required String userName,
    String? userAvatar,
    String? imageUrl,
    String? caption,
    String? location,
  }) async {
    try {
      print('Creating post for user: $userId');
      print('User name: $userName');
      print('User avatar: $userAvatar');
      print('Image URL: $imageUrl');
      print('Caption: $caption');
      print('Location: $location');
      
      // Load user avatar from profiles table if not provided
      String? finalUserAvatar = userAvatar;
      if (finalUserAvatar == null) {
        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select('avatar_url')
              .eq('id', userId)
              .single();
          finalUserAvatar = profileResponse['avatar_url'] as String?;
          print('Loaded avatar from profiles: $finalUserAvatar');
        } catch (e) {
          print('Error loading avatar from profiles: $e');
        }
      }
      
      final postData = {
        'user_id': userId,
        'user_name': userName,
        'user_avatar': finalUserAvatar,
        'image_url': imageUrl,
        'content': caption,
        'location': location,
      };
      
      print('Post data to insert: $postData');
      
      final response = await _supabase
          .from('posts')
          .insert(postData)
          .select()
          .single();

      print('Post created successfully: $response');
      return Post.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error creating post: $e');
      print('Error details: ${e.toString()}');
      return null;
    }
  }

  // Create a post without image (fallback)
  static Future<Post?> createPostWithoutImage({
    required String userId,
    required String userName,
    String? userAvatar,
    String? caption,
    String? location,
  }) async {
    try {
      print('Creating post without image for user: $userId');
      print('User name: $userName');
      print('User avatar: $userAvatar');
      print('Caption: $caption');
      print('Location: $location');
      
      // Load user avatar from profiles table if not provided
      String? finalUserAvatar = userAvatar;
      if (finalUserAvatar == null) {
        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select('avatar_url')
              .eq('id', userId)
              .single();
          finalUserAvatar = profileResponse['avatar_url'] as String?;
          print('Loaded avatar from profiles: $finalUserAvatar');
        } catch (e) {
          print('Error loading avatar from profiles: $e');
        }
      }
      
      final postData = {
        'user_id': userId,
        'user_name': userName,
        'user_avatar': finalUserAvatar,
        'image_url': null,
        'content': caption,
        'location': location,
      };
      
      print('Post data to insert (no image): $postData');
      
      final response = await _supabase
          .from('posts')
          .insert(postData)
          .select()
          .single();

      print('Post created successfully (no image): $response');
      return Post.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error creating post without image: $e');
      print('Error details: ${e.toString()}');
      return null;
    }
  }

  // Upload image as base64 data URL (same as profile pictures)
  static Future<String?> uploadImage(String imagePath, String userId) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      print('Image converted to base64 successfully');
      return dataUrl;
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  // Like a post
  static Future<bool> likePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      // Prevent self-like: fetch post owner
      final postOwner = await _supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .single();
      if (postOwner != null && postOwner['user_id'] == userId) {
        return false;
      }
      
      // First remove any existing dislike
      await _supabase
          .from('post_dislikes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      
      // Then add like
      await _supabase
          .from('post_likes')
          .insert({
            'post_id': postId,
            'user_id': userId,
          });
      return true;
    } catch (e) {
      print('Error liking post: $e');
      return false;
    }
  }

  // Unlike a post
  static Future<bool> unlikePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error unliking post: $e');
      return false;
    }
  }

  // Dislike a post
  static Future<bool> dislikePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      // Prevent self-dislike: fetch post owner
      final postOwner = await _supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .single();
      if (postOwner != null && postOwner['user_id'] == userId) {
        return false;
      }
      
      // First remove any existing like
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      
      // Then add dislike
      await _supabase
          .from('post_dislikes')
          .insert({
            'post_id': postId,
            'user_id': userId,
          });
      return true;
    } catch (e) {
      print('Error disliking post: $e');
      return false;
    }
  }

  // Remove dislike from a post
  static Future<bool> undislikePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      await _supabase
          .from('post_dislikes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error removing dislike from post: $e');
      return false;
    }
  }

  // Delete a post (images are stored as base64 data URLs, no storage cleanup needed)
  static Future<bool> deletePost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      // First get the post to check ownership
      final postResponse = await _supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .single();
      
      // Check if user owns the post
      if (postResponse['user_id'] != userId) {
        print('User does not own this post');
        return false;
      }
      
      // Delete the post from database (images are base64 data URLs, no storage cleanup needed)
      await _supabase
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', userId);
      
      print('Post deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }
}

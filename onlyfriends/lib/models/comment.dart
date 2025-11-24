import 'package:supabase_flutter/supabase_flutter.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;
  final bool isLiked;
  final int likes;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    this.isLiked = false,
    this.likes = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isLiked: json['is_liked'] as bool? ?? false,
      likes: json['likes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_liked': isLiked,
      'likes': likes,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? content,
    DateTime? createdAt,
    bool? isLiked,
    int? likes,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isLiked: isLiked ?? this.isLiked,
      likes: likes ?? this.likes,
    );
  }
}

class CommentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all comments for a post
  static Future<List<Comment>> getCommentsForPost(String postId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        print('No authenticated user found');
        return [];
      }

      // Get comments with likes
      final response = await _supabase
          .from('comments')
          .select('*, comment_likes(user_id)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      print('Fetched comments: ${response.length}');

      final comments = (response as List)
          .map((json) {
            // Handle likes
            final List<dynamic> likes = json['comment_likes'] as List<dynamic>? ?? [];
            final isLiked = likes.any((like) => like['user_id'] == currentUserId);

            return Comment.fromJson({
              ...json,
              'is_liked': isLiked,
              'likes': likes.length,
            });
          })
          .toList();

      // Load avatars and usernames for all comments
      final userIds = comments.map((comment) => comment.userId).toSet().toList();
      
      final profileResponse = await _supabase
          .from('profiles')
          .select('id, username, avatar_url')
          .inFilter('id', userIds);
      
      final profileMap = <String, Map<String, dynamic>>{};
      for (final profile in profileResponse as List) {
        profileMap[profile['id'] as String] = {
          'username': profile['username'] as String?,
          'avatar_url': profile['avatar_url'] as String?,
        };
      }
      
      // Update comments with usernames and avatars
      for (int i = 0; i < comments.length; i++) {
        final comment = comments[i];
        final profileData = profileMap[comment.userId];
        if (profileData != null) {
          final username = profileData['username'] as String?;
          final avatarUrl = profileData['avatar_url'] as String?;
          
          // Update the comment with username and avatar URL
          final updatedComment = comment.copyWith(
            userName: username?.isNotEmpty == true ? username! : comment.userName,
            userAvatar: avatarUrl,
          );
          comments[i] = updatedComment;
        }
      }

      return comments;
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  // Create a new comment
  static Future<Comment?> createComment({
    required String postId,
    required String content,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        print('No authenticated user found');
        return null;
      }

      // Get user profile info
      final profileResponse = await _supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', currentUserId)
          .single();
      
      final userName = profileResponse['username'] as String? ?? 'User';
      final userAvatar = profileResponse['avatar_url'] as String?;
      
      final commentData = {
        'post_id': postId,
        'user_id': currentUserId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'content': content,
      };
      
      print('Comment data to insert: $commentData');
      
      final response = await _supabase
          .from('comments')
          .insert(commentData)
          .select()
          .single();

      print('Comment created successfully: $response');
      return Comment.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error creating comment: $e');
      return null;
    }
  }

  // Like a comment
  static Future<bool> likeComment(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      // First remove any existing like
      await _supabase
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      
      // Then add like
      await _supabase
          .from('comment_likes')
          .insert({
            'comment_id': commentId,
            'user_id': userId,
          });
      return true;
    } catch (e) {
      print('Error liking comment: $e');
      return false;
    }
  }

  // Unlike a comment
  static Future<bool> unlikeComment(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      await _supabase
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error unliking comment: $e');
      return false;
    }
  }

  // Delete a comment
  static Future<bool> deleteComment(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;
      
      // First get the comment to check ownership
      final commentResponse = await _supabase
          .from('comments')
          .select('user_id')
          .eq('id', commentId)
          .single();
      
      // Check if user owns the comment
      if (commentResponse['user_id'] != userId) {
        print('User does not own this comment');
        return false;
      }
      
      // Delete the comment
      await _supabase
          .from('comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);
      
      print('Comment deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }
}

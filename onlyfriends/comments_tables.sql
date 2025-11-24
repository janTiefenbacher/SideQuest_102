-- Comments table
CREATE TABLE IF NOT EXISTS comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Comment likes table
CREATE TABLE IF NOT EXISTS comment_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  comment_id UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(comment_id, user_id)
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments(created_at);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment_id ON comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_user_id ON comment_likes(user_id);

-- Row Level Security (RLS) policies
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all comments for posts they can see
CREATE POLICY "Users can read comments for visible posts" ON comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM posts p
      WHERE p.id = comments.post_id
      AND (
        p.user_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM friendships f
          WHERE f.status = 'accepted'
          AND (
            (f.requester = auth.uid() AND f.addressee = p.user_id)
            OR (f.addressee = auth.uid() AND f.requester = p.user_id)
          )
        )
      )
    )
  );

-- Policy: Users can create comments for posts they can see
CREATE POLICY "Users can create comments for visible posts" ON comments
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM posts p
      WHERE p.id = comments.post_id
      AND (
        p.user_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM friendships f
          WHERE f.status = 'accepted'
          AND (
            (f.requester = auth.uid() AND f.addressee = p.user_id)
            OR (f.addressee = auth.uid() AND f.requester = p.user_id)
          )
        )
      )
    )
  );

-- Policy: Users can update their own comments
CREATE POLICY "Users can update their own comments" ON comments
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy: Users can delete their own comments
CREATE POLICY "Users can delete their own comments" ON comments
  FOR DELETE USING (user_id = auth.uid());

-- Policy: Users can read comment likes for comments they can see
CREATE POLICY "Users can read comment likes for visible comments" ON comment_likes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM comments c
      JOIN posts p ON p.id = c.post_id
      WHERE c.id = comment_likes.comment_id
      AND (
        p.user_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM friendships f
          WHERE f.status = 'accepted'
          AND (
            (f.requester = auth.uid() AND f.addressee = p.user_id)
            OR (f.addressee = auth.uid() AND f.requester = p.user_id)
          )
        )
      )
    )
  );

-- Policy: Users can create comment likes for comments they can see
CREATE POLICY "Users can create comment likes for visible comments" ON comment_likes
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM comments c
      JOIN posts p ON p.id = c.post_id
      WHERE c.id = comment_likes.comment_id
      AND (
        p.user_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM friendships f
          WHERE f.status = 'accepted'
          AND (
            (f.requester = auth.uid() AND f.addressee = p.user_id)
            OR (f.addressee = auth.uid() AND f.requester = p.user_id)
          )
        )
      )
    )
  );

-- Policy: Users can delete their own comment likes
CREATE POLICY "Users can delete their own comment likes" ON comment_likes
  FOR DELETE USING (user_id = auth.uid());

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

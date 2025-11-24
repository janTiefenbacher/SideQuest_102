-- Posts table
CREATE TABLE posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  image_url TEXT,
  caption TEXT,
  location TEXT,
  upvotes INTEGER DEFAULT 0,
  downvotes INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Post likes table
CREATE TABLE post_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Post dislikes table
CREATE TABLE post_dislikes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- Create storage bucket for post images
INSERT INTO storage.buckets (id, name, public) VALUES ('post-images', 'post-images', true);

-- Enable RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_dislikes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for posts
CREATE POLICY "Users can view posts from friends" ON posts
  FOR SELECT USING (
    user_id IN (
      SELECT CASE 
        WHEN requester = auth.uid() THEN addressee
        ELSE requester
      END
      FROM friendships 
      WHERE (requester = auth.uid() OR addressee = auth.uid()) 
      AND status = 'accepted'
    )
    OR user_id = auth.uid()
  );

CREATE POLICY "Users can create their own posts" ON posts
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own posts" ON posts
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own posts" ON posts
  FOR DELETE USING (user_id = auth.uid());

-- RLS Policies for post_likes
CREATE POLICY "Users can view all likes" ON post_likes
  FOR SELECT USING (true);

CREATE POLICY "Users can like posts" ON post_likes
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can unlike their own likes" ON post_likes
  FOR DELETE USING (user_id = auth.uid());

-- RLS Policies for post_dislikes
CREATE POLICY "Users can view all dislikes" ON post_dislikes
  FOR SELECT USING (true);

CREATE POLICY "Users can dislike posts" ON post_dislikes
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can remove their own dislikes" ON post_dislikes
  FOR DELETE USING (user_id = auth.uid());

-- Function to update post vote counts
CREATE OR REPLACE FUNCTION update_post_votes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF TG_TABLE_NAME = 'post_likes' THEN
      UPDATE posts SET upvotes = upvotes + 1 WHERE id = NEW.post_id;
    ELSIF TG_TABLE_NAME = 'post_dislikes' THEN
      UPDATE posts SET downvotes = downvotes + 1 WHERE id = NEW.post_id;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF TG_TABLE_NAME = 'post_likes' THEN
      UPDATE posts SET upvotes = upvotes - 1 WHERE id = OLD.post_id;
    ELSIF TG_TABLE_NAME = 'post_dislikes' THEN
      UPDATE posts SET downvotes = downvotes - 1 WHERE id = OLD.post_id;
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers to update vote counts
CREATE TRIGGER update_post_likes_count
  AFTER INSERT OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_votes();

CREATE TRIGGER update_post_dislikes_count
  AFTER INSERT OR DELETE ON post_dislikes
  FOR EACH ROW EXECUTE FUNCTION update_post_votes();

-- Function to handle like/dislike logic (prevent both like and dislike)
CREATE OR REPLACE FUNCTION handle_post_vote()
RETURNS TRIGGER AS $$
BEGIN
  -- If user is liking, remove any existing dislike
  IF TG_TABLE_NAME = 'post_likes' THEN
    DELETE FROM post_dislikes 
    WHERE post_id = NEW.post_id AND user_id = NEW.user_id;
  -- If user is disliking, remove any existing like
  ELSIF TG_TABLE_NAME = 'post_dislikes' THEN
    DELETE FROM post_likes 
    WHERE post_id = NEW.post_id AND user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to handle mutual exclusivity of likes and dislikes
CREATE TRIGGER handle_like_vote
  BEFORE INSERT ON post_likes
  FOR EACH ROW EXECUTE FUNCTION handle_post_vote();

CREATE TRIGGER handle_dislike_vote
  BEFORE INSERT ON post_dislikes
  FOR EACH ROW EXECUTE FUNCTION handle_post_vote();

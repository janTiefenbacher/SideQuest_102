-- =============================================
-- FIX LIKES/DISLIKES SYSTEM
-- =============================================

-- 1. Überprüfen ob die Spalten existieren
-- =============================================
DO $$
BEGIN
    -- Add upvotes column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'upvotes') THEN
        ALTER TABLE posts ADD COLUMN upvotes INTEGER DEFAULT 0;
    END IF;
    
    -- Add downvotes column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'downvotes') THEN
        ALTER TABLE posts ADD COLUMN downvotes INTEGER DEFAULT 0;
    END IF;
END $$;

-- 2. Aktualisiere alle bestehenden Posts mit korrekten Like/Dislike Zahlen
-- =============================================
UPDATE posts 
SET upvotes = (
    SELECT COUNT(*) 
    FROM post_likes 
    WHERE post_likes.post_id = posts.id
),
downvotes = (
    SELECT COUNT(*) 
    FROM post_dislikes 
    WHERE post_dislikes.post_id = posts.id
);

-- 3. Erstelle/Ersetze die Funktion zum Aktualisieren der Vote-Zahlen
-- =============================================
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

-- 4. Lösche alte Trigger und erstelle neue
-- =============================================
DROP TRIGGER IF EXISTS update_post_likes_count ON post_likes;
DROP TRIGGER IF EXISTS update_post_dislikes_count ON post_dislikes;

-- Erstelle neue Trigger
CREATE TRIGGER update_post_likes_count
  AFTER INSERT OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION update_post_votes();

CREATE TRIGGER update_post_dislikes_count
  AFTER INSERT OR DELETE ON post_dislikes
  FOR EACH ROW EXECUTE FUNCTION update_post_votes();

-- 5. Erstelle/Ersetze die Funktion für Like/Dislike Logik
-- =============================================
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

-- 6. Lösche alte Trigger und erstelle neue für Like/Dislike Logik
-- =============================================
DROP TRIGGER IF EXISTS handle_like_vote ON post_likes;
DROP TRIGGER IF EXISTS handle_dislike_vote ON post_dislikes;

-- Erstelle neue Trigger
CREATE TRIGGER handle_like_vote
  BEFORE INSERT ON post_likes
  FOR EACH ROW EXECUTE FUNCTION handle_post_vote();

CREATE TRIGGER handle_dislike_vote
  BEFORE INSERT ON post_dislikes
  FOR EACH ROW EXECUTE FUNCTION handle_post_vote();

-- 7. Teste das System
-- =============================================
-- Zeige alle Posts mit ihren Like/Dislike Zahlen
SELECT 
    id,
    user_name,
    upvotes,
    downvotes,
    (upvotes - downvotes) as net_votes
FROM posts 
ORDER BY created_at DESC 
LIMIT 10;

-- Zeige Like/Dislike Statistiken
SELECT 
    'Total Posts' as metric,
    COUNT(*) as count
FROM posts
UNION ALL
SELECT 
    'Total Likes' as metric,
    COUNT(*) as count
FROM post_likes
UNION ALL
SELECT 
    'Total Dislikes' as metric,
    COUNT(*) as count
FROM post_dislikes;

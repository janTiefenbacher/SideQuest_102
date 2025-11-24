-- Quest System Tables for OnlyFriends App
-- This SQL creates the necessary tables for the daily quest system

-- Table for storing quest templates
CREATE TABLE quest_templates (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    difficulty VARCHAR(20) NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard')),
    points INTEGER NOT NULL CHECK (points > 0),
    category VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table for storing daily quests (one per day per user)
CREATE TABLE daily_quests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    quest_date DATE NOT NULL,
    easy_quest_id UUID NOT NULL REFERENCES quest_templates(id),
    medium_quest_id UUID NOT NULL REFERENCES quest_templates(id),
    hard_quest_id UUID NOT NULL REFERENCES quest_templates(id),
    selected_quest_id UUID REFERENCES quest_templates(id),
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one daily quest per user per day
    UNIQUE(user_id, quest_date)
);

-- Table for storing quest completions and progress
CREATE TABLE quest_completions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    daily_quest_id UUID NOT NULL REFERENCES daily_quests(id) ON DELETE CASCADE,
    quest_template_id UUID NOT NULL REFERENCES quest_templates(id),
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    points_earned INTEGER NOT NULL,
    completion_notes TEXT,
    
    -- Ensure one completion per quest per user
    UNIQUE(user_id, daily_quest_id, quest_template_id)
);

-- Table for storing user quest statistics
CREATE TABLE user_quest_stats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    total_points INTEGER DEFAULT 0,
    total_quests_completed INTEGER DEFAULT 0,
    easy_quests_completed INTEGER DEFAULT 0,
    medium_quests_completed INTEGER DEFAULT 0,
    hard_quests_completed INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_quest_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id)
);

-- Indexes for better performance
CREATE INDEX idx_daily_quests_user_date ON daily_quests(user_id, quest_date);
CREATE INDEX idx_daily_quests_date ON daily_quests(quest_date);
CREATE INDEX idx_quest_completions_user ON quest_completions(user_id);
CREATE INDEX idx_quest_completions_daily_quest ON quest_completions(daily_quest_id);
CREATE INDEX idx_quest_templates_difficulty ON quest_templates(difficulty);
CREATE INDEX idx_quest_templates_active ON quest_templates(is_active);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_quest_templates_updated_at 
    BEFORE UPDATE ON quest_templates 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_quests_updated_at 
    BEFORE UPDATE ON daily_quests 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_quest_stats_updated_at 
    BEFORE UPDATE ON user_quest_stats 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to create daily quest for a user
CREATE OR REPLACE FUNCTION create_daily_quest_for_user(p_user_id UUID, p_quest_date DATE)
RETURNS UUID AS $$
DECLARE
    v_daily_quest_id UUID;
    v_easy_quest_id UUID;
    v_medium_quest_id UUID;
    v_hard_quest_id UUID;
BEGIN
    -- Check if daily quest already exists
    SELECT id INTO v_daily_quest_id 
    FROM daily_quests 
    WHERE user_id = p_user_id AND quest_date = p_quest_date;
    
    IF v_daily_quest_id IS NOT NULL THEN
        RETURN v_daily_quest_id;
    END IF;
    
    -- Get random quests for each difficulty
    SELECT id INTO v_easy_quest_id 
    FROM quest_templates 
    WHERE difficulty = 'easy' AND is_active = true 
    ORDER BY RANDOM() 
    LIMIT 1;
    
    SELECT id INTO v_medium_quest_id 
    FROM quest_templates 
    WHERE difficulty = 'medium' AND is_active = true 
    ORDER BY RANDOM() 
    LIMIT 1;
    
    SELECT id INTO v_hard_quest_id 
    FROM quest_templates 
    WHERE difficulty = 'hard' AND is_active = true 
    ORDER BY RANDOM() 
    LIMIT 1;
    
    -- Create daily quest
    INSERT INTO daily_quests (user_id, quest_date, easy_quest_id, medium_quest_id, hard_quest_id)
    VALUES (p_user_id, p_quest_date, v_easy_quest_id, v_medium_quest_id, v_hard_quest_id)
    RETURNING id INTO v_daily_quest_id;
    
    RETURN v_daily_quest_id;
END;
$$ LANGUAGE plpgsql;

-- Function to complete a quest
CREATE OR REPLACE FUNCTION complete_quest(
    p_user_id UUID, 
    p_daily_quest_id UUID, 
    p_quest_template_id UUID,
    p_completion_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_points INTEGER;
    v_difficulty VARCHAR(20);
    v_quest_exists BOOLEAN;
BEGIN
    -- Check if quest exists and get points
    SELECT points, difficulty INTO v_points, v_difficulty
    FROM quest_templates 
    WHERE id = p_quest_template_id;
    
    IF v_points IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Check if quest is already completed
    SELECT EXISTS(
        SELECT 1 FROM quest_completions 
        WHERE user_id = p_user_id 
        AND daily_quest_id = p_daily_quest_id 
        AND quest_template_id = p_quest_template_id
    ) INTO v_quest_exists;
    
    IF v_quest_exists THEN
        RETURN FALSE;
    END IF;
    
    -- Insert completion
    INSERT INTO quest_completions (user_id, daily_quest_id, quest_template_id, points_earned, completion_notes)
    VALUES (p_user_id, p_daily_quest_id, p_quest_template_id, v_points, p_completion_notes);
    
    -- Update daily quest as completed
    UPDATE daily_quests 
    SET is_completed = true, completed_at = NOW()
    WHERE id = p_daily_quest_id AND user_id = p_user_id;
    
    -- Update user stats
    INSERT INTO user_quest_stats (user_id, total_points, total_quests_completed, easy_quests_completed, medium_quests_completed, hard_quests_completed)
    VALUES (p_user_id, v_points, 1, 
            CASE WHEN v_difficulty = 'easy' THEN 1 ELSE 0 END,
            CASE WHEN v_difficulty = 'medium' THEN 1 ELSE 0 END,
            CASE WHEN v_difficulty = 'hard' THEN 1 ELSE 0 END)
    ON CONFLICT (user_id) DO UPDATE SET
        total_points = user_quest_stats.total_points + v_points,
        total_quests_completed = user_quest_stats.total_quests_completed + 1,
        easy_quests_completed = user_quest_stats.easy_quests_completed + 
            CASE WHEN v_difficulty = 'easy' THEN 1 ELSE 0 END,
        medium_quests_completed = user_quest_stats.medium_quests_completed + 
            CASE WHEN v_difficulty = 'medium' THEN 1 ELSE 0 END,
        hard_quests_completed = user_quest_stats.hard_quests_completed + 
            CASE WHEN v_difficulty = 'hard' THEN 1 ELSE 0 END,
        last_quest_date = CURRENT_DATE,
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Insert sample quest templates
INSERT INTO quest_templates (title, description, difficulty, points, category) VALUES
-- Easy Quests
('Morgengruß', 'Sage 3 Freunden "Guten Morgen"', 'easy', 10, 'Sozial'),
('Gelbes Auto', 'Mache ein Foto von einem gelben Auto', 'easy', 15, 'Foto'),
('Freundschaft', 'Reagiere auf 5 Posts deiner Freunde', 'easy', 12, 'Sozial'),
('Rote Blume', 'Fotografiere eine rote Blume oder Pflanze', 'easy', 12, 'Foto'),
('Frühstück', 'Teile ein Foto von deinem Frühstück', 'easy', 10, 'Foto'),
('Wolken', 'Mache ein Foto von interessanten Wolken am Himmel', 'easy', 8, 'Foto'),
('Schuhe', 'Fotografiere deine Schuhe von heute', 'easy', 10, 'Foto'),

-- Medium Quests
('Gruppenaktivität', 'Organisiere eine Gruppenaktivität mit 3+ Freunden', 'medium', 25, 'Sozial'),
('Sonnenuntergang', 'Fotografiere einen schönen Sonnenuntergang', 'medium', 30, 'Foto'),
('Tagesrückblick', 'Teile einen ausführlichen Tagesrückblick mit deinen Freunden', 'medium', 20, 'Reflexion'),
('Architektur', 'Mache ein Foto von einem interessanten Gebäude', 'medium', 25, 'Foto'),
('Freundschafts-Challenge', 'Verbinde zwei deiner Freunde miteinander', 'medium', 22, 'Sozial'),

-- Hard Quests
('Community Event', 'Organisiere ein größeres Event für deine Freundesgruppe', 'hard', 50, 'Führung'),
('Kreatives Projekt', 'Erstelle ein mehrteiliges kreatives Projekt über mehrere Tage', 'hard', 60, 'Kreativ'),
('Freundschaftsbrücke', 'Verbinde zwei deiner Freunde, die sich noch nicht kennen', 'hard', 40, 'Sozial'),
('Inspirations-Challenge', 'Erstelle eine inspirierende Content-Serie für deine Freunde', 'hard', 55, 'Kreativ'),
('Community Builder', 'Gründe eine neue Freundesgruppe oder Community', 'hard', 70, 'Führung');

-- Row Level Security (RLS) policies
ALTER TABLE quest_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_quests ENABLE ROW LEVEL SECURITY;
ALTER TABLE quest_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_quest_stats ENABLE ROW LEVEL SECURITY;

-- Policies for quest_templates (everyone can read)
CREATE POLICY "Anyone can view quest templates" ON quest_templates
    FOR SELECT USING (true);

-- Policies for daily_quests (users can only see their own)
CREATE POLICY "Users can view their own daily quests" ON daily_quests
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own daily quests" ON daily_quests
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own daily quests" ON daily_quests
    FOR UPDATE USING (auth.uid() = user_id);

-- Policies for quest_completions (users can only see their own)
CREATE POLICY "Users can view their own quest completions" ON quest_completions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own quest completions" ON quest_completions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policies for user_quest_stats (users can only see their own)
CREATE POLICY "Users can view their own quest stats" ON user_quest_stats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own quest stats" ON user_quest_stats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own quest stats" ON user_quest_stats
    FOR UPDATE USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- OnlyFriends Supabase SQL setup
-- Run these statements in the SQL editor of your Supabase project.

-- 1) Profiles table to extend auth.users
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles(id, username)
  values (new.id, coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2) Simple posts table (optional sample content for feed)
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text,
  image_url text,
  created_at timestamptz not null default now()
);

-- 3) Row Level Security
alter table public.profiles enable row level security;
alter table public.posts enable row level security;

-- Friendships table for requests and accepted relations
create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester uuid not null references auth.users(id) on delete cascade,
  addressee uuid not null references auth.users(id) on delete cascade,
  status text not null check (status in ('pending','accepted','declined')) default 'pending',
  created_at timestamptz not null default now(),
  unique (requester, addressee)
);
alter table public.friendships enable row level security;

-- Profiles policies (drop + create for idempotency)
drop policy if exists "Public profiles are readable" on public.profiles;
create policy "Public profiles are readable" on public.profiles
  for select using (true);

drop policy if exists "Users manage own profile" on public.profiles;
create policy "Users manage own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- Posts policies
drop policy if exists "Read all posts" on public.posts;
create policy "Read all posts" on public.posts
  for select using (true);

drop policy if exists "Insert own posts" on public.posts;
create policy "Insert own posts" on public.posts
  for insert with check (auth.uid() = user_id);

drop policy if exists "Update own posts" on public.posts;
create policy "Update own posts" on public.posts
  for update using (auth.uid() = user_id);

drop policy if exists "Delete own posts" on public.posts;
create policy "Delete own posts" on public.posts
  for delete using (auth.uid() = user_id);

-- Friendships policies
drop policy if exists "Read related friendships" on public.friendships;
create policy "Read related friendships" on public.friendships
  for select using (auth.uid() = requester or auth.uid() = addressee);

drop policy if exists "Create request as requester" on public.friendships;
create policy "Create request as requester" on public.friendships
  for insert with check (auth.uid() = requester and requester <> addressee);

drop policy if exists "Update own or addressed friendship" on public.friendships;
create policy "Update own or addressed friendship" on public.friendships
  for update using (auth.uid() = requester or auth.uid() = addressee);

drop policy if exists "Delete own friendship" on public.friendships;
create policy "Delete own friendship" on public.friendships
  for delete using (auth.uid() = requester or auth.uid() = addressee);

-- 4) Helper: updated_at trigger for profiles
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists on_profiles_updated on public.profiles;
create trigger on_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- 5) Storage: bucket for images (run in storage schema)
-- create bucket if not exists
insert into storage.buckets (id, name, public)
  values ('onlyfriends', 'onlyfriends', true)
  on conflict (id) do nothing;

-- create bucket for profile pictures
insert into storage.buckets (id, name, public)
  values ('profile-pictures', 'profile-pictures', true)
  on conflict (id) do nothing;

-- NOTE: The following policies require ownership on storage.objects.
-- If you see "must be owner of table objects", skip this block and
-- create the equivalent policies in Dashboard → Storage → Policies.
--
-- NOTE: The following RLS policies require owner permissions on storage.objects.
-- If you get "must be owner of table objects" error, skip this block and
-- create the equivalent policies in Dashboard → Storage → Policies.
--
-- TEMPORARILY DISABLE RLS for testing - re-enable in production
-- NOTE: If you get "must be owner of table objects" error, skip this line
-- and disable RLS manually in Dashboard → Storage → Settings
-- alter table storage.objects disable row level security;
--
-- Drop existing policies if they exist
-- drop policy if exists "Public can read images" on storage.objects;
-- drop policy if exists "Users manage own images" on storage.objects;
--
-- Create policies for onlyfriends bucket
-- create policy "Public can read images" on storage.objects
--   for select using (bucket_id = 'onlyfriends');
--
-- create policy "Users manage own images" on storage.objects
--   for all using (bucket_id = 'onlyfriends' and (owner = auth.uid()))
--   with check (bucket_id = 'onlyfriends' and (owner = auth.uid()));

-- Policies for profile-pictures bucket
-- drop policy if exists "Public can read profile pictures" on storage.objects;
-- create policy "Public can read profile pictures" on storage.objects
--   for select using (bucket_id = 'profile-pictures');
--
-- drop policy if exists "Users manage own profile pictures" on storage.objects;
-- create policy "Users manage own profile pictures" on storage.objects
--   for all using (bucket_id = 'profile-pictures' and (owner = auth.uid()))
--   with check (bucket_id = 'profile-pictures' and (owner = auth.uid()));



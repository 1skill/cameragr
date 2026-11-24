-- Koco community, v1 (2026-11-24). Supabase project koco-community (Tokyo).
-- Decided with the user: community replaces the Book in v1; a check-in counts
-- only when posted publicly to a theme; only photos taken with Koco; posts may
-- use a photo taken any time if it fits the theme; streak rewards 3 / 7 / 14
-- days; limited rolls only from rewards; report, block, filter; account
-- deletion in the app. Mainland China: not listed.

-- People ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 30),
  -- Day boundaries for check-ins, fixed when the profile is made (travel does not move them).
  tz text not null default 'UTC',
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "profiles are public" on public.profiles for select using (true);
create policy "one's own profile" on public.profiles for insert with check (id = auth.uid());
create policy "one's own name" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- Only the name may change after creation (tz stays).
create function public.profiles_keep_tz() returns trigger language plpgsql as $$
begin new.tz := old.tz; new.created_at := old.created_at; return new; end $$;
create trigger profiles_keep_tz before update on public.profiles
  for each row execute function public.profiles_keep_tz();

-- Themes (set by Koco, read by all) -----------------------------------------
create table public.themes (
  id text primary key,                                  -- e.g. 2026-12-01-daily
  kind text not null check (kind in ('daily', 'weekly', 'festival')),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  title jsonb not null,                                 -- {"en": "...", "zh-Hans": "...", ...}
  prompt jsonb not null,
  cover_path text,
  suggested_film text,
  limited_film text                                     -- a festival's own roll, if any
);
alter table public.themes enable row level security;
create policy "themes are public" on public.themes for select using (true);

-- Blocks (each person's own) ------------------------------------------------
create table public.blocks (
  blocker uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  blocked uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
alter table public.blocks enable row level security;
create policy "see one's own blocks" on public.blocks for select using (blocker = auth.uid());
create policy "block" on public.blocks for insert with check (blocker = auth.uid());
create policy "unblock" on public.blocks for delete using (blocker = auth.uid());

-- Posts ----------------------------------------------------------------------
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  theme_id text not null references public.themes (id),
  photo_path text not null,                             -- in storage bucket "photos": <author>/<file>
  film_id text not null,
  caption text check (char_length(caption) <= 80),
  taken_at timestamptz,
  created_at timestamptz not null default now(),
  hidden boolean not null default false,               -- set by reports, or by Koco
  like_count integer not null default 0
);
create index posts_theme_recent on public.posts (theme_id, created_at desc) where not hidden;
create index posts_author on public.posts (author, created_at desc);
alter table public.posts enable row level security;

create policy "visible posts" on public.posts for select using (
  author = auth.uid()
  or (not hidden and not exists (
        select 1 from public.blocks b where b.blocker = auth.uid() and b.blocked = posts.author))
);
create policy "post to an open theme, as oneself, into one's own folder" on public.posts for insert with check (
  author = auth.uid()
  and split_part(photo_path, '/', 1) = auth.uid()::text
  and exists (select 1 from public.themes t where t.id = theme_id and now() between t.starts_at and t.ends_at)
);
create policy "delete one's own post" on public.posts for delete using (author = auth.uid());

-- Clients may set only what they post; the rest is the server's.
create function public.posts_server_fields() returns trigger language plpgsql as $$
begin
  new.created_at := now(); new.hidden := false; new.like_count := 0;
  return new;
end $$;
create trigger posts_server_fields before insert on public.posts
  for each row execute function public.posts_server_fields();

-- Likes ----------------------------------------------------------------------
create table public.likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.likes enable row level security;
create policy "likes are public" on public.likes for select using (true);
create policy "like" on public.likes for insert with check (user_id = auth.uid());
create policy "unlike" on public.likes for delete using (user_id = auth.uid());

create function public.likes_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then update posts set like_count = like_count + 1 where id = new.post_id;
  else update posts set like_count = greatest(like_count - 1, 0) where id = old.post_id; end if;
  return null;
end $$;
create trigger likes_count after insert or delete on public.likes
  for each row execute function public.likes_count();

-- Reports (written by anyone signed in, read only by Koco in the dashboard) --
create table public.reports (
  id bigint generated always as identity primary key,
  post_id uuid not null references public.posts (id) on delete cascade,
  reporter uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  reason text not null check (reason in ('nudity', 'violence', 'hate', 'spam', 'not-koco', 'other')),
  note text check (char_length(note) <= 200),
  created_at timestamptz not null default now(),
  handled boolean not null default false,
  unique (post_id, reporter)
);
alter table public.reports enable row level security;
create policy "report" on public.reports for insert with check (reporter = auth.uid());

-- Three different people reporting a post hide it until Koco looks.
create function public.reports_hide() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from reports where post_id = new.post_id) >= 3 then
    update posts set hidden = true where id = new.post_id;
  end if;
  return null;
end $$;
create trigger reports_hide after insert on public.reports
  for each row execute function public.reports_hide();

-- Streaks and rewards (the server counts; the app only asks) ----------------
-- Days in a row, in the person's own day, ending today or yesterday, with a post that day.
create function public.current_streak(who uuid default auth.uid()) returns integer
language sql stable security definer set search_path = public as $$
  with days as (
    select distinct (p.created_at at time zone pr.tz)::date as d
    from posts p join profiles pr on pr.id = p.author
    where p.author = who
  ), today as (
    select (now() at time zone (select tz from profiles where id = who))::date as t
  ), anchored as (
    select d, row_number() over (order by d desc) as n from days
  )
  select coalesce((
    select count(*)::integer from anchored, today
    where d = (select max(d) from days) - (n - 1)::integer
      and (select max(d) from days) >= (select t from today) - 1
  ), 0)
$$;

create table public.rewards (
  user_id uuid not null references public.profiles (id) on delete cascade,
  milestone integer not null check (milestone in (3, 7, 14)),
  film_id text not null,
  claimed_at timestamptz not null default now(),
  primary key (user_id, milestone)
);
alter table public.rewards enable row level security;
create policy "see one's own rewards" on public.rewards for select using (user_id = auth.uid());
-- No insert policy: only claim_reward below writes here.

create function public.claim_reward(m integer) returns text
language plpgsql security definer set search_path = public as $$
declare film text;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  film := case m when 3 then 'porto400' when 7 then 'dusk200' when 14 then 'ember400' end;
  if film is null then raise exception 'no such milestone'; end if;
  if current_streak(auth.uid()) < m then raise exception 'not yet'; end if;
  insert into rewards (user_id, milestone, film_id) values (auth.uid(), m, film)
    on conflict do nothing;
  return film;
end $$;

-- Leaving: one's account and everything in it (App Review 5.1.1(v)).
-- The app deletes the photo files first through Storage, then calls this.
create function public.delete_me() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  delete from auth.users where id = auth.uid();
end $$;

revoke all on function public.delete_me() from public, anon;
grant execute on function public.delete_me() to authenticated;
revoke all on function public.claim_reward(integer) from public, anon;
grant execute on function public.claim_reward(integer) to authenticated;

-- Photos -----------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 4194304, array['image/jpeg', 'image/heic'])
on conflict (id) do nothing;

create policy "upload into one's own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "remove one's own photos" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

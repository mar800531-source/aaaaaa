-- =====================================================================
-- دار الحجر مول — مخطط قاعدة البيانات (Supabase / PostgreSQL)
-- شغّله كاملاً في: Supabase Dashboard > SQL Editor
-- =====================================================================
create extension if not exists pgcrypto;

-- ---------- الجداول ----------
create table public.branches (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  address     text,
  phone       text,
  lat         double precision,
  lng         double precision,
  opens_at    time not null default '08:00',
  closes_at   time not null default '23:00',
  is_active   boolean not null default true,
  sort_order  int not null default 0
);

create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  icon        text not null default 'category',
  sort_order  int not null default 0,
  is_active   boolean not null default true
);

create table public.products (
  id          uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id) on delete set null,
  name        text not null,
  description text,
  image_url   text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);
create index on public.products (category_id);

-- سعر مستقل لكل فرع (غياب السجل = المنتج غير معروض في الفرع)
create table public.branch_prices (
  branch_id    uuid not null references public.branches(id) on delete cascade,
  product_id   uuid not null references public.products(id) on delete cascade,
  price        numeric(12,2) not null check (price >= 0),
  is_available boolean not null default true,
  primary key (branch_id, product_id)
);

-- العروض اليومية: تنتهي تلقائياً بعد 24 ساعة (expires_at)
create table public.offers (
  id          uuid primary key default gen_random_uuid(),
  branch_id   uuid not null references public.branches(id) on delete cascade,
  product_id  uuid not null references public.products(id) on delete cascade,
  old_price   numeric(12,2) not null,
  new_price   numeric(12,2) not null check (new_price < old_price),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default (now() + interval '24 hours')
);
create index on public.offers (branch_id, expires_at);

create table public.ratings (
  product_id uuid not null references public.products(id) on delete cascade,
  user_id    uuid not null default auth.uid(),
  stars      int  not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  primary key (product_id, user_id)
);

create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  body       text not null,
  created_at timestamptz not null default now()
);

create table public.app_settings (
  key   text primary key,
  value jsonb not null default '{}'::jsonb
);

create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- ---------- Views للتطبيق ----------
create view public.branch_products as
select p.id, p.name, p.description, p.image_url, p.category_id,
       bp.branch_id, bp.price,
       coalesce(r.avg_rating, 0) as avg_rating,
       coalesce(r.rating_count, 0) as rating_count
from public.products p
join public.branch_prices bp on bp.product_id = p.id
left join (
  select product_id, round(avg(stars), 2) as avg_rating, count(*) as rating_count
  from public.ratings group by product_id
) r on r.product_id = p.id
where p.is_active and bp.is_available;

create view public.active_offers as
select o.id, o.branch_id, o.product_id, o.old_price, o.new_price, o.expires_at,
       p.name, p.image_url
from public.offers o
join public.products p on p.id = o.product_id
where o.expires_at > now() and p.is_active;

grant select on public.branch_products, public.active_offers to anon, authenticated;

-- ---------- الأمان (RLS) ----------
do $$
declare t text;
begin
  foreach t in array array['branches','categories','products','branch_prices','notifications','app_settings'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "public read" on public.%I for select using (true)', t);
    execute format('create policy "admin write" on public.%I for all using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

alter table public.offers enable row level security;
create policy "public read active" on public.offers for select using (expires_at > now() or public.is_admin());
create policy "admin write" on public.offers for all using (public.is_admin()) with check (public.is_admin());

alter table public.ratings enable row level security;
create policy "read own or admin" on public.ratings for select using (user_id = auth.uid() or public.is_admin());
create policy "insert own" on public.ratings for insert with check (user_id = auth.uid());
create policy "update own" on public.ratings for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "delete own or admin" on public.ratings for delete using (user_id = auth.uid() or public.is_admin());

alter table public.admins enable row level security;
create policy "read self" on public.admins for select using (user_id = auth.uid());

-- ---------- تخزين الصور ----------
insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true)
on conflict do nothing;
create policy "images public read" on storage.objects for select using (bucket_id = 'product-images');
create policy "images admin write" on storage.objects for all
  using (bucket_id = 'product-images' and public.is_admin())
  with check (bucket_id = 'product-images' and public.is_admin());

-- ---------- بيانات أولية ----------
insert into public.categories (name, icon, sort_order) values
 ('المواد الغذائية','grocery',1), ('أدوات المطبخ','kitchen',2), ('الأدوات المنزلية','home',3),
 ('المنظفات','cleaning',4), ('المشروبات','drinks',5), ('البهارات','spices',6), ('الحلويات','sweets',7);

insert into public.app_settings (key, value) values
 ('contact', '{"phones":[],"address":"تعز، اليمن","email":"","social":{}}');

-- ---------- بعد إنشاء حساب المدير من Authentication > Users ----------
-- insert into public.admins (user_id) select id from auth.users where email = 'admin@example.com';

-- ---------- (اختياري) حذف العروض القديمة جداً — فعّل إضافة pg_cron أولاً ----------
-- select cron.schedule('purge-old-offers', '0 3 * * *',
--   $$ delete from public.offers where expires_at < now() - interval '7 days' $$);

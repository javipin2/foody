-- Ejecuta esto si te aparece: column "sede_id" does not exist
-- (tablas del menú creadas con el script antiguo y sede_firestore_id).

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'menu_categorias'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_categorias' and column_name = 'sede_id'
  ) then
    alter table public.menu_categorias add column sede_id text;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'menu_categorias' and column_name = 'sede_firestore_id'
    ) then
      update public.menu_categorias c set sede_id = c.sede_firestore_id where c.sede_id is null;
      alter table public.menu_categorias drop column sede_firestore_id;
    end if;
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'menu_productos'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'menu_productos' and column_name = 'sede_id'
  ) then
    alter table public.menu_productos add column sede_id text;
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = 'menu_productos' and column_name = 'sede_firestore_id'
    ) then
      update public.menu_productos p set sede_id = p.sede_firestore_id where p.sede_id is null;
      alter table public.menu_productos drop column sede_firestore_id;
    end if;
  end if;
end $$;

create index if not exists idx_menu_cat_sede on public.menu_categorias (sede_id);
create index if not exists idx_menu_prod_sede on public.menu_productos (sede_id);

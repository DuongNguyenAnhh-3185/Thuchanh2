const fs = require('node:fs');
const read = p => fs.readFileSync(p, 'utf8').replace(/\r\n/g, '\n').replace(/^\uFEFF/, '');
let sql = '-- CashewDoc TH2: run in Supabase SQL Editor as project owner.\n-- Preserves tables and data; review legacy storage paths before applying.\nbegin;\n';
for (const file of fs.readdirSync('supabase/migrations').filter(p => p.endsWith('.sql')).sort()) {
  let part = read('supabase/migrations/' + file).replace(/^begin;\s*$/gm, '').replace(/^commit;\s*$/gm, '');
  part = part.replace(/create policy (\w+)\s+on ([\w.]+)/gi, (match, name, table) =>
    'drop policy if exists ' + name + ' on ' + table + ';\n' + match);
  part = part.replace(/create table (public\.\w+)/gi, 'create table if not exists $1');
  part = part.replace('alter table public.documents\n  add constraint documents_storage_path_matches_identity',
    'alter table public.documents drop constraint if exists documents_storage_path_matches_identity;\nalter table public.documents\n  add constraint documents_storage_path_matches_identity');
  sql += '\n-- ' + file + '\n' + part + '\n';
}
sql += "\ncommit;\nnotify pgrst, 'reload schema';\n";
fs.writeFileSync('supabase_setup.sql', sql, 'utf8');
console.log('Generated supabase_setup.sql from ordered migrations.');

import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const files = ['index.html', 'app.html'];
const failures = [];
for (const file of files) {
  const html = readFileSync(file, 'utf8');
  if (!/^<!doctype html>/i.test(html.trim())) failures.push(file + ': doctype HTML manquant');
  const ids = [...html.matchAll(/\b id=["']([^"']+)["']/g)].map(m => m[1]);
  const duplicates = ids.filter((id, i) => ids.indexOf(id) !== i);
  if (duplicates.length) failures.push(file + ': identifiants HTML en double: ' + [...new Set(duplicates)].join(', '));
  const dir = mkdtempSync(join(tmpdir(), 'immopilot-check-'));
  try {
    const blocks = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
      .filter(m => !/\bsrc\s*=/.test(m[1]))
      .map(m => m[2]).filter(code => code.trim());
    for (let i = 0; i < blocks.length; i++) {
      const path = join(dir, 'inline-' + i + '.js');
      writeFileSync(path, blocks[i]);
      const result = spawnSync(process.execPath, ['--check', path], { encoding: 'utf8' });
      if (result.status !== 0) failures.push(file + ': syntaxe JavaScript invalide dans le script inline ' + i + '\n' + (result.stderr || result.stdout));
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
const rlsAudit = readFileSync('tests/rls-audit.sql', 'utf8');
for (const required of ['pg_policies', 'relrowsecurity', 'private.is_agency_member', 'public.create_agency', 'auth.uid()', 'does not replace multi-user runtime isolation tests', 'created_by', 'Agency UPDATE policy', 'WITH CHECK']) {
  if (!rlsAudit.includes(required)) failures.push('tests/rls-audit.sql: contrôle de sécurité attendu absent: ' + required);
}
const propertyMigration = readFileSync('supabase/migrations/202611250001_properties_and_mandates.sql', 'utf8');
for (const required of ['create table if not exists public.properties', 'create table if not exists public.mandates', 'private.is_agency_member(agency_id)', 'created_by = (select auth.uid())', 'enable row level security', 'mandates_property_agency_fk', 'properties_set_updated_at', 'mandates_set_updated_at', 'revoke all on public.properties, public.mandates from anon, authenticated']) {
  if (!propertyMigration.includes(required)) failures.push('migration biens/mandats: contrôle attendu absent: ' + required);
}
for (const table of ['properties', 'mandates']) {
  for (const action of ['read', 'create', 'update', 'delete']) {
    if (!propertyMigration.includes('Members can ' + action + ' ' + table)) failures.push('migration biens/mandats: politique RLS absente: ' + table + ' ' + action);
  }
}
const app = readFileSync('app.html', 'utf8');
for (const required of ['Nouveau', 'À contacter', 'En cours', 'Converti', 'Perdu', 'Historique des échanges', 'Exporter en CSV', 'Rappels et actions', 'agencySwitcher', 'selectAgency', 'agencyMemberships', 'csvCell', 'calendarGrid', 'calendarMonth', 'renderCalendar']) {
  if (!app.includes(required)) failures.push('app.html: élément fonctionnel attendu absent: ' + required);
}
for (const required of ['properties','mandates','loadProperties','renderProperties','openProperty','openMandate','propertyForm','mandateForm','addPropertyBtn','addMandateBtn','data-property-edit','data-property-delete','data-mandate-edit','data-mandate-delete']) { if (!app.includes(required)) failures.push('app.html: module biens/mandats incomplet: ' + required); }
if (!app.includes('<option>Perdu</option>')) failures.push('app.html: statut Perdu non disponible');
if (!app.includes('immopilot:selected-agency:')) failures.push('app.html: agence active non mémorisée par compte');
if (!app.includes("addEventListener('change',e=>selectAgency(e.target.value))")) failures.push('app.html: sélecteur multi-agence sans gestionnaire de changement');
if (!app.includes("if(/^\\s*[=+\\-@]/.test(text))text=\"'\"+text")) failures.push('app.html: protection CSV contre les formules de tableur absente');
if (!app.includes("addEventListener('click',()=>{calendarMonth=new Date(calendarMonth.getFullYear(),calendarMonth.getMonth()-1,1);renderCalendar()})")) failures.push('app.html: navigation mois précédent absente');
if (!app.includes("addEventListener('click',()=>{calendarMonth=new Date(calendarMonth.getFullYear(),calendarMonth.getMonth()+1,1);renderCalendar()})")) failures.push('app.html: navigation mois suivant absente');
if (!app.includes("data-calendar-view")) failures.push('app.html: ouverture de fiche depuis le calendrier absente');
if (failures.length) {
  console.error('ÉCHEC DES CONTRÔLES ImmoPilot\n' + failures.map(x => '- ' + x).join('\n'));
  process.exit(1);
}
console.log('Contrôles statiques ImmoPilot réussis: HTML présent, IDs uniques, scripts inline syntaxiquement valides, fonctions CRM essentielles détectées.');

import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const files = ['index.html', 'app.html'];
const failures = [];
for (const file of files) {
  const html = readFileSync(file, 'utf8');
  if (!/^<!doctype html>/i.test(html.trim())) failures.push(file + ': doctype HTML manquant');
  const ids = [...html.matchAll(/\\bid=["']([^"']+)["']/g)].map(m => m[1]);
  const duplicates = ids.filter((id, i) => ids.indexOf(id) !== i);
  if (duplicates.length) failures.push(file + ': identifiants HTML en double: ' + [...new Set(duplicates)].join(', '));
  const dir = mkdtempSync(join(tmpdir(), 'immopilot-check-'));
  try {
    const blocks = [...html.matchAll(/<script\\b([^>]*)>([\\s\\S]*?)<\\/script>/gi)]
      .filter(m => !/\\bsrc\\s*=/.test(m[1]))
      .map(m => m[2]).filter(code => code.trim());
    for (let i = 0; i < blocks.length; i++) {
      const path = join(dir, 'inline-' + i + '.js');
      writeFileSync(path, blocks[i]);
      const result = spawnSync(process.execPath, ['--check', path], { encoding: 'utf8' });
      if (result.status !== 0) failures.push(file + ': syntaxe JavaScript invalide dans le script inline ' + i + '\\n' + (result.stderr || result.stdout));
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
const app = readFileSync('app.html', 'utf8');
for (const required of ['Nouveau', 'À contacter', 'En cours', 'Converti', 'Perdu', 'Historique des échanges', 'Exporter en CSV', 'Rappels et actions']) {
  if (!app.includes(required)) failures.push('app.html: élément fonctionnel attendu absent: ' + required);
}
if (!app.includes("status:'Perdu'") && !app.includes('<option>Perdu</option>')) failures.push('app.html: statut Perdu non disponible');
if (failures.length) {
  console.error('ÉCHEC DES CONTRÔLES ImmoPilot\\n' + failures.map(x => '- ' + x).join('\\n'));
  process.exit(1);
}
console.log('Contrôles statiques ImmoPilot réussis: HTML présent, IDs uniques, scripts inline syntaxiquement valides, fonctions CRM essentielles détectées.');

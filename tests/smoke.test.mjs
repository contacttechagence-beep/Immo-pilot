import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync(new URL('../app.html', import.meta.url), 'utf8');

test('all ImmoPilot workspace modules have a navigation entry and a view', () => {
  const tabs = [...html.matchAll(/data-module-tab="([^"]+)"/g)].map((m) => m[1]);
  const expected = ['dashboard', 'contacts', 'properties', 'mandates', 'tasks', 'appointments', 'documents', 'team', 'audit'];
  for (const name of expected) assert.ok(tabs.includes(name), 'missing navigation tab: ' + name);
  for (const name of expected) {
    const viewId = name === 'dashboard' ? 'dashboardView' : name + 'Page';
    assert.ok(html.includes('id="' + viewId + '"'), 'missing module view: ' + viewId);
  }
});

test('authentication, Supabase persistence and core CRM actions remain wired', () => {
  for (const id of ['authForm', 'authEmail', 'authPassword', 'prospectForm', 'teamInviteForm', 'auditRefresh']) {
    assert.ok(html.includes('id="' + id + '"'), 'missing required control: ' + id);
  }
  for (const marker of ['createClient', 'onAuthStateChange', 'loadProspects', 'loadModuleData', 'uploadDocument', 'renderCalendar', 'loadAuditLogs']) {
    assert.ok(html.includes(marker), 'missing application capability: ' + marker);
  }
});

test('all inline JavaScript parses without syntax errors', () => {
  const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)];
  assert.ok(scripts.length > 0, 'no inline script found');
  scripts.forEach((match, index) => {
    assert.doesNotThrow(() => new vm.Script(match[1], { filename: 'app-inline-' + index + '.js' }));
  });
});

test('responsive layout and reduced-motion accessibility rules are present', () => {
  assert.match(html, /@media\s*\(max-width:\s*760px\)/);
  assert.match(html, /@media\s*\(max-width:\s*560px\)/);
  assert.match(html, /prefers-reduced-motion:\s*reduce/);
});


test('Supabase queries use one column per order() call', () => {
  const calls = [...html.matchAll(/\.order\(([^)]*)\)/g)].map((m) => m[1]);
  assert.ok(calls.length >= 3, 'expected ordering on CRM data queries');
  for (const args of calls) {
    const firstArgument = args.split(',')[0].trim();
    assert.ok(!firstArgument.includes(','), 'order() must receive one column name, not a comma-separated list: ' + args);
  }
  assert.match(html, /\.order\(order,\{ascending\}\)/);
  assert.match(html, /query=query\.order\(secondary,\{ascending:true\}\)/);
});


test('document storage stays agency-scoped and private in application flows', () => {
  assert.match(html, /storage\.from\('immopilot-documents'\)\.upload\(path,file/);
  assert.match(html, /const path=agencyId\+'\/'\+crypto\.randomUUID\(\)/);
  assert.match(html, /const payload=\{agency_id:agencyId,[\s\S]*storage_path:path/);
  assert.match(html, /storage\.from\('immopilot-documents'\)\.download\(d\.storage_path\)/);
  assert.match(html, /storage\.from\('immopilot-documents'\)\.remove\(\[d\.storage_path\]\)/);
  assert.match(html, /documents'\)\.delete\(\)\.eq\('id',id\)\.eq\('agency_id',agencyId\)/);
  assert.match(html, /file\.size>20\*1024\*1024/);
  assert.match(html, /if\(metaError\)\{await db\.storage\.from\('immopilot-documents'\)\.remove\(\[path\]\)/);
});

test('CRM reads and writes stay scoped to the active agency', () => {
  assert.match(html, /async function loadProspects\(\)[\s\S]*?\.eq\('agency_id',agencyId\)/);
  assert.match(html, /async function loadModuleData\(\)[\s\S]*?\.eq\('agency_id',agencyId\)/);
  assert.match(html, /async function loadAuditLogs\(\)[\s\S]*?\.eq\('agency_id',agencyId\)/);
  assert.match(html, /let payload=\{agency_id:agencyId\}/);
  assert.match(html, /db\.from\(table\)\.update\(payload\)\.eq\('id',editingModuleId\)\.eq\('agency_id',agencyId\)/);
  assert.match(html, /db\.from\(table\)\.delete\(\)\.eq\('id',id\)\.eq\('agency_id',agencyId\)/);
});


test('module forms validate non-negative numeric values and date ranges', () => {
  assert.match(html, /const numericFields=\['price','surface_area','rooms','bedrooms','fee_rate'\]/);
  assert.match(html, /payload\[key\]<0/);
  assert.match(html, /payload\.fee_rate>100/);
  assert.match(html, /payload\.end_date<payload\.start_date/);
  assert.match(html, /new Date\(payload\.ends_at\)<=new Date\(payload\.starts_at\)/);
});

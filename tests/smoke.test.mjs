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
  const scripts = [...html.matchAll(/<script\\b[^>]*>([\\s\\S]*?)<\\/script>/gi)];
  assert.ok(scripts.length > 0, 'no inline script found');
  scripts.forEach((match, index) => {
    assert.doesNotThrow(() => new vm.Script(match[1], { filename: 'app-inline-' + index + '.js' }));
  });
});

test('responsive layout and reduced-motion accessibility rules are present', () => {
  assert.match(html, /@media\\s*\\(max-width:\\s*760px\\)/);
  assert.match(html, /@media\\s*\\(max-width:\\s*560px\\)/);
  assert.match(html, /prefers-reduced-motion:\\s*reduce/);
});

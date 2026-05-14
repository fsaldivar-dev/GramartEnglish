import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import yaml from 'js-yaml';

export interface OpenApiDoc {
  openapi: string;
  info: { title: string; version: string };
  paths: Record<string, Record<string, unknown>>;
}

export interface LoadedOpenApi {
  doc: OpenApiDoc;
  path: string;
  routes: { method: string; path: string }[];
}

const EXPECTED_ROUTES: { method: string; path: string }[] = [
  { method: 'get', path: '/health' },
  { method: 'get', path: '/levels' },
  { method: 'post', path: '/placement/start' },
  { method: 'post', path: '/placement/submit' },
  { method: 'post', path: '/lessons' },
  { method: 'get', path: '/lessons/{lessonId}' },
  { method: 'post', path: '/lessons/{lessonId}/answers' },
  { method: 'post', path: '/lessons/{lessonId}/skip' },
  { method: 'post', path: '/lessons/{lessonId}/complete' },
  { method: 'get', path: '/words/{word}/examples' },
  { method: 'get', path: '/words/{word}/definition' },
  { method: 'get', path: '/me' },
  { method: 'patch', path: '/me' },
  { method: 'post', path: '/me/reset' },
  { method: 'get', path: '/progress' },
];

export function loadOpenApi(repoRoot: string): LoadedOpenApi {
  const candidates = [
    join(repoRoot, 'specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml'),
    join(repoRoot, '../specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml'),
  ];
  const path = candidates.find((p) => existsSync(p));
  if (!path) {
    throw new Error(`OpenAPI doc not found. Tried: ${candidates.join(', ')}`);
  }
  const raw = readFileSync(path, 'utf8');
  const doc = yaml.load(raw) as OpenApiDoc;
  if (!doc || typeof doc !== 'object' || !doc.paths) {
    throw new Error(`OpenAPI doc at ${path} is malformed`);
  }
  const routes: { method: string; path: string }[] = [];
  for (const [p, methods] of Object.entries(doc.paths)) {
    for (const m of Object.keys(methods)) {
      routes.push({ method: m.toLowerCase(), path: p });
    }
  }
  validateRoutes(routes);
  return { doc, path, routes };
}

function validateRoutes(routes: { method: string; path: string }[]): void {
  const have = new Set(routes.map((r) => `${r.method} ${r.path}`));
  const missing = EXPECTED_ROUTES.filter((r) => !have.has(`${r.method} ${r.path}`));
  if (missing.length > 0) {
    throw new Error(
      `OpenAPI doc missing expected routes: ${missing.map((r) => `${r.method.toUpperCase()} ${r.path}`).join(', ')}`,
    );
  }
}

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const vercel = JSON.parse(readFileSync(resolve(root, 'vercel.json'), 'utf8'));
const globalRule = vercel.headers?.find((rule) => rule.source === '/(.*)');
const headers = new Map(
  (globalRule?.headers ?? []).map(({ key, value }) => [key.toLowerCase(), value]),
);

const required = [
  'content-security-policy',
  'strict-transport-security',
  'x-content-type-options',
  'x-frame-options',
  'referrer-policy',
  'permissions-policy',
];

for (const header of required) {
  if (!headers.has(header)) throw new Error(`Missing security header: ${header}`);
}

const csp = headers.get('content-security-policy') ?? '';
for (const directive of ["default-src 'self'", "object-src 'none'", "frame-ancestors 'none'"]) {
  if (!csp.includes(directive)) throw new Error(`CSP is missing: ${directive}`);
}

const sourceFiles = [
  'next.config.ts',
  'vercel.json',
  ...['src/app/layout.tsx', 'src/lib/supabase.ts'],
];
for (const file of sourceFiles) {
  const contents = readFileSync(resolve(root, file), 'utf8');
  if (/service[_-]?role/i.test(contents)) {
    throw new Error(`Privileged Supabase credential reference found in landing/${file}`);
  }
}

console.log('Landing security configuration verified.');

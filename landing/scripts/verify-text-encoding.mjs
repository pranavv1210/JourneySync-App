import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

const sourceRoot = path.resolve('src');
const sourceExtensions = new Set(['.css', '.html', '.js', '.jsx', '.json', '.md', '.ts', '.tsx']);
const mojibakeMarkers = [
  '\u00c3',
  '\u00c2',
  '\u00e2\u20ac',
  '\ufffd',
];
const failures = [];

async function scan(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await scan(absolutePath);
      continue;
    }
    if (!sourceExtensions.has(path.extname(entry.name))) continue;

    const content = await readFile(absolutePath, 'utf8');
    const lines = content.split(/\r?\n/);
    lines.forEach((line, index) => {
      if (mojibakeMarkers.some((marker) => line.includes(marker))) {
        failures.push(`${path.relative(process.cwd(), absolutePath)}:${index + 1}`);
      }
    });
  }
}

await scan(sourceRoot);

if (failures.length > 0) {
  console.error(`Invalid or mis-decoded text found:\n${failures.join('\n')}`);
  process.exit(1);
}

console.log('Landing source text encoding check passed.');

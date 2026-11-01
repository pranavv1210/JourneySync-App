import fs from 'node:fs/promises';
import path from 'node:path';

const port = process.env.CHROME_DEBUG_PORT ?? '9222';
const outputDir = path.resolve(process.cwd(), '..', 'docs', 'qa', 'v1.11.0');
const widths = [320, 360, 375, 390, 414, 430, 768, 1024, 1440];

async function wait(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

const targets = await fetch(`http://127.0.0.1:${port}/json`).then((response) =>
  response.json(),
);
const target = targets.find((item) => item.type === 'page');
if (!target?.webSocketDebuggerUrl) {
  throw new Error('No Chrome page target is available for responsive QA.');
}

const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve, { once: true });
  socket.addEventListener('error', reject, { once: true });
});

let commandId = 0;
const pending = new Map();
socket.addEventListener('message', (event) => {
  const message = JSON.parse(event.data);
  if (!message.id || !pending.has(message.id)) return;
  const { resolve, reject } = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) reject(new Error(message.error.message));
  else resolve(message.result);
});

function send(method, params = {}) {
  const id = ++commandId;
  socket.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

await fs.mkdir(outputDir, { recursive: true });
await send('Page.enable');
await send('Runtime.enable');

const results = [];
for (const width of widths) {
  await send('Emulation.setDeviceMetricsOverride', {
    width,
    height: 1200,
    deviceScaleFactor: 1,
    mobile: width < 768,
  });
  await send('Page.navigate', { url: 'http://127.0.0.1:3000/' });
  await wait(900);
  const evaluation = await send('Runtime.evaluate', {
    expression: `JSON.stringify({
      viewport: window.innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      hasHorizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
      menuVisible: getComputedStyle(document.querySelector('.menu-toggle')).display !== 'none'
    })`,
    returnByValue: true,
  });
  const result = JSON.parse(evaluation.result.value);
  results.push({ width, ...result });
  const screenshot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: false,
  });
  await fs.writeFile(
    path.join(outputDir, `landing-${width}.png`),
    Buffer.from(screenshot.data, 'base64'),
  );

  if (width === 320) {
    await send('Runtime.evaluate', {
      expression: `document.querySelector('.menu-toggle')?.click()`,
    });
    await wait(150);
    const menuScreenshot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: false,
    });
    await fs.writeFile(
      path.join(outputDir, 'landing-320-menu.png'),
      Buffer.from(menuScreenshot.data, 'base64'),
    );
  }
}

await fs.writeFile(
  path.join(outputDir, 'responsive-results.json'),
  `${JSON.stringify(results, null, 2)}\n`,
);
socket.close();

if (results.some((result) => result.hasHorizontalOverflow)) {
  console.error(JSON.stringify(results, null, 2));
  process.exitCode = 1;
} else {
  console.log(JSON.stringify(results, null, 2));
}

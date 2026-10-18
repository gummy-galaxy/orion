import { chromium } from 'playwright';
const [file, out] = process.argv.slice(2);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 1600 }, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.log('PAGEERROR', e.message));
await page.goto('file://' + file);
await page.evaluate(() => document.fonts.ready); await page.waitForTimeout(3500);
await page.locator('#art').screenshot({ path: out });
await browser.close();

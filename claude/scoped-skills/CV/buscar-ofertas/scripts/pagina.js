const { chromium } = require('playwright-core');
(async () => {
  const [url, out, waitMs] = [process.argv[2], process.argv[3], +(process.argv[4] || 6000)];
  const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true,
    args: ['--disable-blink-features=AutomationControlled'] });
  const ctx = await browser.newContext({ userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36', locale: 'en-US' });
  const page = await ctx.newPage();
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
    await page.waitForTimeout(waitMs);
    const text = await page.evaluate(() => document.body.innerText);
    const links = await page.evaluate(() => [...document.querySelectorAll('a[href]')].map(a => a.innerText.trim().replace(/\s+/g,' ').slice(0,120) + ' -> ' + a.href).filter(s => s.length > 5));
    require('fs').writeFileSync(out, `TITLE: ${await page.title()}\nURL: ${page.url()}\n\n${text}\n\n=== LINKS ===\n${links.join('\n')}`);
    console.log('ok', out, text.length);
  } catch (e) { console.log('ERR', url, e.message.split('\n')[0]); }
  await browser.close();
})();

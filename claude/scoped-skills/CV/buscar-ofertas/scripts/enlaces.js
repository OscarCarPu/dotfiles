const { chromium } = require('playwright-core');
(async () => {
  const b = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true, args: ['--disable-blink-features=AutomationControlled'] });
  const p = await (await b.newContext({ userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36' })).newPage();
  await p.goto(process.argv[2], { waitUntil: 'domcontentloaded', timeout: 45000 }); await p.waitForTimeout(8000);
  const re = new RegExp(process.argv[3] || '.', 'i');
  const hrefs = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map(a => (a.innerText||a.getAttribute('aria-label')||'').trim().replace(/\s+/g,' ').slice(0,100) + ' -> ' + a.href));
  console.log([...new Set(hrefs)].filter(h => re.test(h)).join('\n')); await b.close();
})();

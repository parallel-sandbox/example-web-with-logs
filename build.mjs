import { build } from 'esbuild';
import { copyFileSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';

const release = process.env.PSBX_RELEASE;
if (!release) {
  console.error('PSBX_RELEASE is required, e.g. PSBX_RELEASE=$(git rev-parse --short HEAD) npm run build');
  process.exit(1);
}

rmSync('dist', { recursive: true, force: true });
mkdirSync('dist/assets', { recursive: true });

await build({
  entryPoints: ['src/app.js', 'src/log-init.js'],
  outdir: 'dist/assets',
  entryNames: '[name]-[hash]',
  bundle: true,
  minify: true,
  sourcemap: true,
  format: 'esm',
  target: 'es2022',
  external: ['@parallelsandbox/log'],
  define: { __PSBX_RELEASE__: JSON.stringify(release) },
});

const assets = readdirSync('dist/assets');
const appJs = assets.find((f) => /^app-.*\.js$/.test(f));
const logJs = assets.find((f) => /^log-init-.*\.js$/.test(f));

const html = readFileSync('src/index.html', 'utf8')
  .replace('__APP_JS__', `assets/${appJs}`)
  .replace('__LOG_JS__', `assets/${logJs}`);
writeFileSync('dist/index.html', html);
copyFileSync('src/styles.css', 'dist/styles.css');
writeFileSync('dist/release.txt', release + '\n');

console.log(`built release ${release}: ${appJs}, ${logJs}`);

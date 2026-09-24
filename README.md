# example-web-with-logs

ParallelSandbox 的範例 repo 之一：一頁靜態網頁，掛上瀏覽器 log SDK `@parallelsandbox/log`。頁上有一個按鈕，按下去會丟一個帶完整 stack 的未捕捉錯誤；SDK 把它送到你的 project，agent 用 `logs_errors` 就撈得到，stack 已經用上傳的 source map 還原成原始檔與行號。

English version below.

## 內容

| 檔案 | 說明 |
|---|---|
| `src/index.html` | 頁面。用 import map 把 `@parallelsandbox/log` 指到 npm 上 0.1.x 的套件（經 jsDelivr，`@0.1`），先載 `config.js` 再載兩個 module |
| `src/log-init.js` | 只做一件事：`init({ writeKey, endpoint, release })`，回傳的 logger 放在 `window.psbxLog`。write key 本身就指明是哪個 project。SDK 初始化後自動接管 `console`、`window` 的錯誤與未處理的 promise rejection |
| `src/app.js` | 頁面邏輯。按鈕經 `handleCheckout → prepareOrder → chargeCard` 三層呼叫丟出 `Error`，所以 stack 有三個 frame 可以還原 |
| `build.mjs` | esbuild：壓縮、產 source map、檔名帶 hash、把 release id 寫進 `dist/release.txt` |
| `docker/40-write-config.sh` | 容器啟動時用環境變數寫出 `config.js`（project id 只給頁面顯示、write key、endpoint、release），所以 write key 不進 image |
| `scripts/upload-sourcemaps.sh` | build 完把 `dist/assets/*.map` 上傳到 log server，`logs_errors` 才能還原 stack |

`package.json` 把 `@parallelsandbox/log`（`^0.1.1`）列在 `optionalDependencies`：頁面在瀏覽器裡經 import map 載入 SDK，不需要 bundler；你要改成 bundle 進去時把它移到 `dependencies`、在 `build.mjs` 拿掉 `external`，再 `npm install`。0.1.1 起，頁面經箱子的場景網址打開時，SDK 只送箱子 id，網址裡的 key 不會離開頁面。

## 本機跑

```bash
PSBX_RELEASE=$(git rev-parse --short HEAD) docker compose up -d --build --wait
open http://localhost:8080          # 按 Throw an error，頁面會顯示丟出的 stack
docker compose down
```

沒給 `PSBX_LOG_*` 環境變數時 compose 會用 `local` 的假值，頁面照常運作，錯誤只留在瀏覽器 console（SDK 不接受不是 `psw_` 開頭的 write key，會在 console 報一行錯）。

## 在 ParallelSandbox 的箱子裡跑

先用帳號的 API key 建一個 log project（在你自己的機器上，不要在箱子裡）。`origins` 列出會打開頁面的來源：箱子裡的 `http://localhost:8080`，以及經場景網址打開時的 `https://*.box.parallelsandbox.com`（不給 `origins` 時預設只有後者）：

```bash
curl -fsS -X POST https://log.parallelsandbox.com/v1/projects \
  -H "Authorization: Bearer psbx_YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "name": "example-web", "origins": ["http://localhost:8080", "https://*.box.parallelsandbox.com"] }'
```

回應是 `{"project": {"id": "prj_...", ...}, "writeKey": "psw_..."}`，write key 只出現這一次。它是可以放在網頁上的公開鍵，只能寫入這個 project 的 log；別把帳號的 API key 放進網頁。

以下每一步都是一個 MCP 工具呼叫。`sandbox_exec` 一定要帶 `note`：用看箱子的人讀的語言，一句話說這一步要做什麼。

1. 把 write key 存成 secret，名稱 `PSBX_LOG_WRITE_KEY`：`PUT https://api.parallelsandbox.com/v1/secrets/PSBX_LOG_WRITE_KEY` 帶 `{ "value": "psw_..." }`。箱子只在認領時拿到 secrets，收掉就消失，不會出現在 log 裡。

2. 起箱子，帶上這個 secret：

   ```json
   sandbox_start { "name": "example-web-with-logs", "services": [{ "name": "web", "port": 8080, "web": true }], "secrets": ["PSBX_LOG_WRITE_KEY"] }
   ```

   `web` 從箱子一開起來就在箱子裡解析到箱子自己，不需要接線；回傳的 `sceneUrl` 就是這個頁面，給你的瀏覽器或手機打開。

3. 放程式碼、build、跑：

   ```json
   sandbox_exec { "id": "<id>", "cmd": "git clone https://github.com/parallel-sandbox/example-web-with-logs.git", "note": "clone 範例 repo" }
   sandbox_exec { "id": "<id>", "cmd": "PSBX_RELEASE=$(git rev-parse --short HEAD) PSBX_LOG_PROJECT=<project id> PSBX_LOG_ENDPOINT=https://log.parallelsandbox.com docker compose up -d --build --wait", "cwd": "example-web-with-logs", "timeoutSec": 600, "note": "build 並帶 log 設定提供頁面" }
   ```

   `PSBX_LOG_WRITE_KEY` 已經是箱子的環境變數，compose 直接帶進容器。

4. 上傳 source map。在你自己的機器上做，API key 不進箱子；同一個 commit 的 build 產物相同，release id 也相同。stack 是在錯誤送到的那一刻還原的，所以要在按按鈕之前傳：

   ```bash
   git clone https://github.com/parallel-sandbox/example-web-with-logs.git && cd example-web-with-logs
   npm ci && PSBX_RELEASE=$(git rev-parse --short HEAD) npm run build
   PSBX_API_KEY=<api key> PSBX_LOG_PROJECT=<project id> ./scripts/upload-sourcemaps.sh
   ```

5. 在箱子的虛擬螢幕上開頁面，按下按鈕：

   ```json
   sandbox_exec { "id": "<id>", "cmd": "chromium --no-sandbox --kiosk --window-size=1280,800 --user-data-dir=/tmp/chrome http://localhost:8080/", "background": true, "note": "在箱子螢幕上打開頁面" }
   sandbox_shot { "id": "<id>" }
   sandbox_exec { "id": "<id>", "cmd": "xdotool mousemove 640 300 click 1", "note": "按下會丟錯誤的按鈕" }
   ```

   按鈕位置以 `sandbox_shot` 的截圖為準；也可以從 `takeoverUrl` 進去用滑鼠按。改用你自己的瀏覽器打開 `sceneUrl` 的話，送出的每一列都會帶這個箱子的 id。

6. 撈錯誤：

   ```json
   logs_errors { "project": "<project id>", "since": "10m" }
   ```

   回來的每一列有 `msg`、`release`、`box`（在箱子裡用 `localhost` 打開時是空的，經 `sceneUrl` 打開時是箱子 id）、`stack` 與還原後的 `stackResolved`：`chargeCard (src/app.js:9)`、`prepareOrder (src/app.js:14)`、`handleCheckout (src/app.js:18)`。

7. `sandbox_stop { "id": "<id>" }`。

## SDK 的用法

```js
import { init } from '@parallelsandbox/log';

const log = init({
  writeKey: 'psw_...',                         // 該 project 的 write key，可公開；它本身就指明是哪個 project
  endpoint: 'https://log.parallelsandbox.com', // log server（預設就是這個）
  release: 'a1b2c3d',                          // 與上傳 source map 時同一個 release id
});

log.info('checkout started', { cart: 3 });
log.error(new Error('card declined'), { step: 'charge' });
await log.flush();
```

`init` 之後 `console.log`、`console.info`、`console.warn`、`console.error`、未捕捉的錯誤與未處理的 promise rejection 會自動送出（預設等級 info、warn、error），頁面經箱子的場景網址打開時會帶上箱子 id。完整說明在 https://parallelsandbox.com/docs/log-sdk/ 。

---

# example-web-with-logs (English)

One of the ParallelSandbox example repos: a single static page with the browser log SDK `@parallelsandbox/log` attached. A button throws an uncaught error with a full stack; the SDK ships it to your project, and `logs_errors` returns it with the stack resolved to original files and lines through the uploaded source map.

## What is inside

| File | Notes |
|---|---|
| `src/index.html` | The page. An import map points `@parallelsandbox/log` at the 0.1.x npm package (via jsDelivr, `@0.1`); `config.js` loads before the two modules |
| `src/log-init.js` | Does one thing: `init({ writeKey, endpoint, release })`, keeping the returned logger on `window.psbxLog`. The write key names the project. Once initialised the SDK hooks `console`, window errors and unhandled promise rejections |
| `src/app.js` | Page logic. The button throws an `Error` through `handleCheckout → prepareOrder → chargeCard`, so there are three frames to resolve |
| `build.mjs` | esbuild: minify, emit source maps, hashed file names, write the release id to `dist/release.txt` |
| `docker/40-write-config.sh` | Writes `config.js` from environment variables at container start (the project id, shown on the page only, the write key, the endpoint, the release), so the write key never enters the image |
| `scripts/upload-sourcemaps.sh` | Uploads `dist/assets/*.map` to the log server after a build so `logs_errors` can resolve stacks |

`package.json` lists `@parallelsandbox/log` (`^0.1.1`) under `optionalDependencies`: the browser loads the SDK through the import map, no bundler needed. To bundle it instead, move it to `dependencies`, drop `external` in `build.mjs` and run `npm install`. From 0.1.1, a page opened through a box's scene URL sends only the box id; the key in that URL never leaves the page.

## Run locally

```bash
PSBX_RELEASE=$(git rev-parse --short HEAD) docker compose up -d --build --wait
open http://localhost:8080          # press Throw an error, the page shows the thrown stack
docker compose down
```

Without `PSBX_LOG_*` variables compose falls back to `local` placeholders; the page works and the error stays in the browser console (the SDK rejects a write key that does not start with `psw_` and logs one error line there).

## Run inside a ParallelSandbox box

Create a log project with your account's API key first, from your own machine, not from a box. `origins` lists where the page is opened from: `http://localhost:8080` inside the box, and `https://*.box.parallelsandbox.com` for a scene URL (without `origins` only the latter is allowed):

```bash
curl -fsS -X POST https://log.parallelsandbox.com/v1/projects \
  -H "Authorization: Bearer psbx_YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "name": "example-web", "origins": ["http://localhost:8080", "https://*.box.parallelsandbox.com"] }'
```

The response is `{"project": {"id": "prj_...", ...}, "writeKey": "psw_..."}`; the write key is shown only this once. It is a public key that can live in a web page and can only write logs into that project. Never put your account API key in a page.

Every step below is one MCP tool call. `sandbox_exec` requires a `note`: one sentence, in the language the person watching reads, saying what the step is for.

1. Store the write key as a secret named `PSBX_LOG_WRITE_KEY`: `PUT https://api.parallelsandbox.com/v1/secrets/PSBX_LOG_WRITE_KEY` with `{ "value": "psw_..." }`. A box receives secrets only when it is claimed, they vanish when it stops, and they never appear in logs.

2. Start a box with that secret:

   ```json
   sandbox_start { "name": "example-web-with-logs", "services": [{ "name": "web", "port": 8080, "web": true }], "secrets": ["PSBX_LOG_WRITE_KEY"] }
   ```

   `web` resolves inside the box to the box itself from the moment it starts; there is nothing to wire. The returned `sceneUrl` is this page, for your own browser or phone.

3. Put the code in, build, run:

   ```json
   sandbox_exec { "id": "<id>", "cmd": "git clone https://github.com/parallel-sandbox/example-web-with-logs.git", "note": "clone the example repo" }
   sandbox_exec { "id": "<id>", "cmd": "PSBX_RELEASE=$(git rev-parse --short HEAD) PSBX_LOG_PROJECT=<project id> PSBX_LOG_ENDPOINT=https://log.parallelsandbox.com docker compose up -d --build --wait", "cwd": "example-web-with-logs", "timeoutSec": 600, "note": "build and serve the page with its log settings" }
   ```

   `PSBX_LOG_WRITE_KEY` is already an environment variable on the box; compose passes it into the container.

4. Upload the source maps from your own machine, so your API key never enters the box. The same commit builds the same assets, so the release id matches. Stacks are resolved when an error arrives, so do this before you press the button:

   ```bash
   git clone https://github.com/parallel-sandbox/example-web-with-logs.git && cd example-web-with-logs
   npm ci && PSBX_RELEASE=$(git rev-parse --short HEAD) npm run build
   PSBX_API_KEY=<api key> PSBX_LOG_PROJECT=<project id> ./scripts/upload-sourcemaps.sh
   ```

5. Open the page on the box's virtual display and press the button:

   ```json
   sandbox_exec { "id": "<id>", "cmd": "chromium --no-sandbox --kiosk --window-size=1280,800 --user-data-dir=/tmp/chrome http://localhost:8080/", "background": true, "note": "open the page on the box screen" }
   sandbox_shot { "id": "<id>" }
   sandbox_exec { "id": "<id>", "cmd": "xdotool mousemove 640 300 click 1", "note": "click the button that throws" }
   ```

   Take the button position from the `sandbox_shot` screenshot, or click it through `takeoverUrl`. Open `sceneUrl` in your own browser instead and every row carries this box's id.

6. Query the errors:

   ```json
   logs_errors { "project": "<project id>", "since": "10m" }
   ```

   Every row carries `msg`, `release`, `box` (empty for a page opened at `localhost` inside the box, the box id through `sceneUrl`), `stack` and the resolved `stackResolved`: `chargeCard (src/app.js:9)`, `prepareOrder (src/app.js:14)`, `handleCheckout (src/app.js:18)`.

7. `sandbox_stop { "id": "<id>" }`.

## Using the SDK

```js
import { init } from '@parallelsandbox/log';

const log = init({
  writeKey: 'psw_...',                         // the project's write key, safe to publish; it names the project
  endpoint: 'https://log.parallelsandbox.com', // log server (this is the default)
  release: 'a1b2c3d',                          // same release id used when uploading source maps
});

log.info('checkout started', { cart: 3 });
log.error(new Error('card declined'), { step: 'charge' });
await log.flush();
```

After `init`, `console.log`, `console.info`, `console.warn`, `console.error`, uncaught errors and unhandled promise rejections are sent automatically (levels info, warn and error by default), and pages opened through a box's scene URL carry the box id. Full reference: https://parallelsandbox.com/en/docs/log-sdk/ .

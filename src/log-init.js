import { init } from '@parallelsandbox/log';

// init() hooks console, window errors and unhandled rejections, and returns a logger.
// The write key names the project, so no project id is passed here.
window.psbxLog = init({
  writeKey: window.PSBX_LOG.writeKey,
  endpoint: window.PSBX_LOG.endpoint,
  release: window.PSBX_LOG.release,
});

import { init } from '@parallelsandbox/log';

init({
  project: window.PSBX_LOG.project,
  writeKey: window.PSBX_LOG.writeKey,
  endpoint: window.PSBX_LOG.endpoint,
  release: window.PSBX_LOG.release,
});

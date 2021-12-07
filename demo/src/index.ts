import { consoleTransport, initialize, LogLevels } from '@grafana/frontend-agent-core';
import browserMetaPlugin from '@grafana/frontend-agent-plugin-browser-meta';
import getConsolePlugin from '@grafana/frontend-agent-plugin-console';
import errorsPlugin from '@grafana/frontend-agent-plugin-errors';
import performancePlugin from '@grafana/frontend-agent-plugin-performance';
import tracingPlugin from '@grafana/frontend-agent-plugin-tracing';

const agent = initialize({
  plugins: [browserMetaPlugin, getConsolePlugin([LogLevels.DEBUG]), errorsPlugin, performancePlugin, tracingPlugin],
  transports: [consoleTransport],
});

agent.logger.pushLog(['Manual event']);
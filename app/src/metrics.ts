import { Counter, Registry, collectDefaultMetrics } from "@prometheus-io/client";

export const registry = new Registry();

collectDefaultMetrics({ register: registry });

export const httpRequestsTotal = new Counter({
  name: "irongate_http_requests_total",
  help: "Total HTTP requests handled by IronGate.",
  labelNames: ["method", "route", "status"],
  registers: [registry]
});

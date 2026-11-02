import Fastify, { type FastifyInstance } from "fastify";
import { httpRequestsTotal, registry } from "./metrics.js";

export function buildApp(): FastifyInstance {
  const app = Fastify({
    logger: false
  });

  app.addHook("onResponse", async (request, reply) => {
    httpRequestsTotal.inc({
      method: request.method,
      route: request.routeOptions.url ?? "unknown",
      status: String(reply.statusCode)
    });
  });

  app.get("/", async () => ({
    service: "devops-pipeline",
    description:
      "Minimal deploy target for the DevOps Security Pipeline",
    version: process.env.APP_VERSION ?? "dev"
  }));

  app.get("/health", async () => ({
    status: "healthy",
    uptimeSeconds: Math.round(process.uptime())
  }));

  app.get("/metrics", async (_request, reply) => {
    reply.header("content-type", registry.contentType);
    return registry.metrics();
  });

  return app;
}

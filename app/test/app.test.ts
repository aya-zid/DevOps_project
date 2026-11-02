import { afterEach, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/app.js";

const apps: FastifyInstance[] = [];

function makeApp(): FastifyInstance {
  const app = buildApp();
  apps.push(app);
  return app;
}

afterEach(async () => {
  await Promise.all(apps.splice(0).map((app) => app.close()));
});

describe("DevOps Security Pipeline service", () => {
  it("reports a healthy status", async () => {
    const response = await makeApp().inject({
      method: "GET",
      url: "/health"
    });

    expect(response.statusCode).toBe(200);
    const body = response.json();
    expect(body.status).toBe("healthy");
    expect(body.uptimeSeconds).toBeGreaterThanOrEqual(0);
  });

  it("returns service metadata at the root", async () => {
    const response = await makeApp().inject({ method: "GET", url: "/" });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      service: "devops-pipeline",
      version: "dev"
    });
  });

  it("exposes Prometheus metrics including request counts", async () => {
    const app = makeApp();
    await app.inject({ method: "GET", url: "/health" });

    const response = await app.inject({ method: "GET", url: "/metrics" });

    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/plain");
    expect(response.body).toContain("devops_pipeline_http_requests_total");
    expect(response.body).toContain('route="/health"');
  });

  it("returns 404 for unknown routes", async () => {
    const response = await makeApp().inject({
      method: "GET",
      url: "/not-a-route"
    });

    expect(response.statusCode).toBe(404);
  });
});

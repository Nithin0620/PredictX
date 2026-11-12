import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "./app.js";

describe("GET /health", () => {
  it("returns ok with chain info", async () => {
    const res = await request(createApp()).get("/health");

    expect(res.status).toBe(200);
    expect(res.body.status).toBe("ok");
    expect(res.body.chainId).toBe(84532);
    expect(typeof res.body.timestamp).toBe("string");
  });

  it("does not leak the x-powered-by header", async () => {
    const res = await request(createApp()).get("/health");
    expect(res.headers["x-powered-by"]).toBeUndefined();
  });
});

import { DEFAULT_CHAIN, PROJECT_NAME } from "@predictx/shared";
import cors from "cors";
import express, { type Express } from "express";

/**
 * Builds the Express application without binding a port, so tests can import it.
 * Real modules (auth, markets, trading, portfolio, ...) land in Phase 14+.
 */
export function createApp(): Express {
  const app = express();

  app.disable("x-powered-by");
  app.use(cors());
  app.use(express.json());

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      service: `${PROJECT_NAME} API`,
      chain: DEFAULT_CHAIN.name,
      chainId: DEFAULT_CHAIN.id,
      timestamp: new Date().toISOString(),
    });
  });

  return app;
}

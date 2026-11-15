"use client";

import Link from "next/link";
import { ConnectButton } from "thirdweb/react";
import { thirdwebClient } from "@/lib/client";
import { config, isConfigured } from "@/lib/config";
import { FaucetButton } from "./faucet-button";

export function Header() {
  return (
    <header className="sticky top-0 z-30 border-b border-white/10 bg-[#070b14]/85 backdrop-blur-xl">
      <div className="mx-auto flex w-full max-w-6xl flex-wrap items-center gap-3 px-4 py-3 sm:px-6 lg:px-8">
        <Link href="/" className="mr-auto flex items-center gap-3">
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-cyan-400 text-sm font-black text-slate-950">
            PX
          </span>
          <span>
            <span className="block text-sm font-bold tracking-wide text-white">PredictX</span>
            <span className="block text-[10px] font-semibold uppercase tracking-[0.2em] text-cyan-300/80">
              Lite · Base Sepolia
            </span>
          </span>
        </Link>

        <nav className="order-3 flex w-full items-center gap-1 text-sm text-slate-300 sm:order-none sm:w-auto">
          <Link className="rounded-lg px-3 py-2 hover:bg-white/5 hover:text-white" href="/">
            Markets
          </Link>
          <Link className="rounded-lg px-3 py-2 hover:bg-white/5 hover:text-white" href="/create">
            Create
          </Link>
        </nav>

        <FaucetButton />

        {thirdwebClient ? (
          <ConnectButton
            client={thirdwebClient}
            chain={config.chain}
            connectButton={{ label: "Connect wallet" }}
            detailsButton={
              isConfigured
                ? { displayBalanceToken: { [config.chainId]: config.usdcAddress } }
                : undefined
            }
          />
        ) : (
          <span className="rounded-xl border border-amber-400/20 bg-amber-400/10 px-3 py-2 text-xs text-amber-200">
            Add thirdweb client ID
          </span>
        )}
      </div>
    </header>
  );
}

"use client";

import { useActiveWalletChain, useSwitchActiveWalletChain } from "thirdweb/react";
import { config } from "@/lib/config";
import { Button } from "./ui";

export function WrongNetworkBanner() {
  const activeChain = useActiveWalletChain();
  const switchChain = useSwitchActiveWalletChain();

  if (!activeChain || activeChain.id === config.chainId) return null;

  return (
    <div className="border-b border-amber-400/20 bg-amber-400/10">
      <div className="mx-auto flex w-full max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3 text-sm text-amber-100 sm:px-6 lg:px-8">
        <span>
          Your wallet is connected to {activeChain.name}. Switch to Base Sepolia to continue.
        </span>
        <Button
          variant="secondary"
          className="border-amber-300/30 bg-amber-300/10 text-amber-100 hover:bg-amber-300/20"
          onClick={() => void switchChain(config.chain)}
        >
          Switch network
        </Button>
      </div>
    </div>
  );
}

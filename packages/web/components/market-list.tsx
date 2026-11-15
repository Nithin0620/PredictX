"use client";

import Link from "next/link";
import type { ThirdwebContract } from "thirdweb";
import { useReadContract } from "thirdweb/react";
import { factoryContract, factoryMethods } from "@/lib/contracts";
import { isConfigured } from "@/lib/config";
import { MarketCard } from "./market-card";
import { SetupNotice } from "./setup-notice";
import { Card, Notice } from "./ui";

export function MarketList() {
  if (!isConfigured || !factoryContract) return <SetupNotice />;
  return <MarketListInner factory={factoryContract} />;
}

function MarketListInner({ factory }: { factory: ThirdwebContract }) {
  const { data, isLoading, error } = useReadContract({
    contract: factory,
    method: factoryMethods.getMarkets,
    params: [],
    queryOptions: { refetchInterval: 5_000 },
  });

  const markets = (data as readonly string[] | undefined) ?? [];

  return (
    <section className="mt-10">
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-white">Live markets</h2>
          <p className="mt-1 text-sm text-slate-400">
            Parimutuel YES/NO pools. Winners split the whole pool.
          </p>
        </div>
        <Link
          href="/create"
          className="inline-flex items-center justify-center rounded-xl bg-cyan-400 px-4 py-2.5 text-sm font-semibold text-slate-950 transition hover:bg-cyan-300"
        >
          Create market
        </Link>
      </div>

      {error ? (
        <Notice tone="error">
          Could not load markets. Check your RPC and factory address, then refresh.
        </Notice>
      ) : null}

      {isLoading ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {[0, 1, 2].map((item) => (
            <Card key={item} className="h-64 animate-pulse bg-slate-900/40" />
          ))}
        </div>
      ) : null}

      {!isLoading && markets.length === 0 ? (
        <Card className="py-12 text-center">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-cyan-400/10 text-2xl">
            ?
          </div>
          <h3 className="mt-4 text-lg font-semibold text-white">No markets yet</h3>
          <p className="mx-auto mt-2 max-w-md text-sm text-slate-400">
            Create the first prediction market, then share the link with a friend to test both
            sides.
          </p>
          <Link
            href="/create"
            className="mt-5 inline-flex items-center justify-center rounded-xl bg-cyan-400 px-4 py-2.5 text-sm font-semibold text-slate-950 transition hover:bg-cyan-300"
          >
            Create the first market
          </Link>
        </Card>
      ) : null}

      {!isLoading && markets.length > 0 ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {markets.map((address) => (
            <MarketCard key={address} address={address} />
          ))}
        </div>
      ) : null}
    </section>
  );
}

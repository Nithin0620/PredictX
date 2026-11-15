"use client";

import Link from "next/link";
import type { ThirdwebContract } from "thirdweb";
import { useReadContract } from "thirdweb/react";
import { getMarketContract, marketMethods } from "@/lib/contracts";
import { formatDeadline, formatPercent, formatUsdc, outcomeLabel, outcomeTone } from "@/lib/format";
import { useNow } from "@/lib/use-now";
import { Badge, Card } from "./ui";

export function MarketCard({ address }: { address: string }) {
  const contract = getMarketContract(address);
  if (!contract) return null;
  return <MarketCardInner contract={contract} address={address} />;
}

function MarketCardInner({ contract, address }: { contract: ThirdwebContract; address: string }) {
  const { data: question } = useReadContract({
    contract,
    method: marketMethods.question,
    params: [],
    queryOptions: { refetchInterval: 10_000 },
  });
  const { data: totalYes } = useReadContract({
    contract,
    method: marketMethods.totalYes,
    params: [],
    queryOptions: { refetchInterval: 5_000 },
  });
  const { data: totalNo } = useReadContract({
    contract,
    method: marketMethods.totalNo,
    params: [],
    queryOptions: { refetchInterval: 5_000 },
  });
  const { data: deadline } = useReadContract({
    contract,
    method: marketMethods.deadline,
    params: [],
  });
  const { data: outcome } = useReadContract({
    contract,
    method: marketMethods.outcome,
    params: [],
    queryOptions: { refetchInterval: 5_000 },
  });

  const now = useNow();
  const outcomeNumber = Number(outcome ?? 0);
  const isClosed = outcomeNumber === 0 && deadline !== undefined && now >= Number(deadline);
  const totalPool = (totalYes ?? 0n) + (totalNo ?? 0n);
  const yesShare = totalPool === 0n ? 50 : Number(((totalYes ?? 0n) * 10_000n) / totalPool) / 100;

  return (
    <Link href={`/market/${address}`} className="group block">
      <Card className="h-full transition group-hover:-translate-y-0.5 group-hover:border-cyan-400/30 group-hover:bg-slate-900">
        <div className="flex items-start justify-between gap-3">
          <Badge tone={isClosed ? "warning" : outcomeTone(outcomeNumber)}>
            {isClosed ? "CLOSED" : outcomeLabel(outcomeNumber)}
          </Badge>
          <span className="text-xs text-slate-500">#{address.slice(2, 6)}</span>
        </div>

        <h3 className="mt-4 line-clamp-2 min-h-14 text-base font-semibold leading-7 text-white">
          {question ?? "Loading market…"}
        </h3>

        <div className="mt-4 h-2 overflow-hidden rounded-full bg-rose-400/30">
          <div className="h-full rounded-full bg-emerald-400" style={{ width: `${yesShare}%` }} />
        </div>

        <div className="mt-2 flex justify-between text-xs text-slate-400">
          <span>YES {formatPercent(totalYes, totalPool)}</span>
          <span>NO {formatPercent(totalNo, totalPool)}</span>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-3 border-t border-white/10 pt-4 text-sm">
          <div>
            <div className="text-xs uppercase tracking-wider text-slate-500">Pool</div>
            <div className="mt-1 font-semibold text-white">{formatUsdc(totalPool)} mUSDC</div>
          </div>
          <div>
            <div className="text-xs uppercase tracking-wider text-slate-500">Deadline</div>
            <div className="mt-1 text-slate-300">{formatDeadline(deadline)}</div>
          </div>
        </div>
      </Card>
    </Link>
  );
}

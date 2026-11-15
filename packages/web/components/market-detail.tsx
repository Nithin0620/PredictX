"use client";

import Link from "next/link";
import { ZERO_ADDRESS, type ThirdwebContract } from "thirdweb";
import { useActiveAccount, useReadContract } from "thirdweb/react";
import { getMarketContract, marketMethods } from "@/lib/contracts";
import { isConfigured } from "@/lib/config";
import {
  formatDeadline,
  formatPercent,
  formatUsdc,
  outcomeLabel,
  outcomeTone,
  shortAddress,
} from "@/lib/format";
import { useNow } from "@/lib/use-now";
import { BetForm } from "./bet-form";
import { ClaimPanel } from "./claim-panel";
import { ResolvePanel } from "./resolve-panel";
import { SetupNotice } from "./setup-notice";
import { Badge, Card, Label, Notice, Stat } from "./ui";

export function MarketDetail({ address }: { address: string }) {
  if (!isConfigured) return <SetupNotice />;

  const contract = getMarketContract(address);
  if (!contract) {
    return <Notice tone="error">That market address is not valid.</Notice>;
  }

  return <MarketDetailInner contract={contract} address={address} />;
}

function MarketDetailInner({ contract, address }: { contract: ThirdwebContract; address: string }) {
  const account = useActiveAccount();
  const accountAddress = account?.address ?? ZERO_ADDRESS;
  const now = useNow();

  const questionQuery = useReadContract({
    contract,
    method: marketMethods.question,
    params: [],
  });
  const creatorQuery = useReadContract({ contract, method: marketMethods.creator, params: [] });
  const resolverQuery = useReadContract({ contract, method: marketMethods.resolver, params: [] });
  const deadlineQuery = useReadContract({ contract, method: marketMethods.deadline, params: [] });
  const createdAtQuery = useReadContract({
    contract,
    method: marketMethods.createdAt,
    params: [],
  });
  const totalYesQuery = useReadContract({
    contract,
    method: marketMethods.totalYes,
    params: [],
    queryOptions: { refetchInterval: 5_000 },
  });
  const totalNoQuery = useReadContract({
    contract,
    method: marketMethods.totalNo,
    params: [],
    queryOptions: { refetchInterval: 5_000 },
  });
  const outcomeQuery = useReadContract({
    contract,
    method: marketMethods.outcome,
    params: [],
    queryOptions: { refetchInterval: 5_000 },
  });
  const yesStakeQuery = useReadContract({
    contract,
    method: marketMethods.yesStake,
    params: [accountAddress],
    queryOptions: { enabled: Boolean(account), refetchInterval: 5_000 },
  });
  const noStakeQuery = useReadContract({
    contract,
    method: marketMethods.noStake,
    params: [accountAddress],
    queryOptions: { enabled: Boolean(account), refetchInterval: 5_000 },
  });
  const claimedQuery = useReadContract({
    contract,
    method: marketMethods.claimed,
    params: [accountAddress],
    queryOptions: { enabled: Boolean(account), refetchInterval: 5_000 },
  });

  const deadline = deadlineQuery.data;
  const outcome = Number(outcomeQuery.data ?? 0);
  const totalYes = totalYesQuery.data ?? 0n;
  const totalNo = totalNoQuery.data ?? 0n;
  const totalPool = totalYes + totalNo;
  const yesStake = yesStakeQuery.data ?? 0n;
  const noStake = noStakeQuery.data ?? 0n;
  const claimed = claimedQuery.data ?? false;
  const isClosed = outcome === 0 && deadline !== undefined && now >= Number(deadline);
  const yesShare = totalPool === 0n ? 50 : Number((totalYes * 10_000n) / totalPool) / 100;

  const refresh = () => {
    void questionQuery.refetch();
    void creatorQuery.refetch();
    void resolverQuery.refetch();
    void deadlineQuery.refetch();
    void createdAtQuery.refetch();
    void totalYesQuery.refetch();
    void totalNoQuery.refetch();
    void outcomeQuery.refetch();
    void yesStakeQuery.refetch();
    void noStakeQuery.refetch();
    void claimedQuery.refetch();
  };

  return (
    <div>
      <Link href="/" className="text-sm font-semibold text-cyan-300 hover:text-cyan-200">
        ← Back to markets
      </Link>

      <div className="mt-5 grid gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
        <div className="space-y-6">
          <Card>
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={isClosed ? "warning" : outcomeTone(outcome)}>
                {isClosed ? "CLOSED" : outcomeLabel(outcome)}
              </Badge>
              <span className="text-xs text-slate-500">Market #{address.slice(2, 8)}</span>
            </div>

            <h1 className="mt-4 text-2xl font-bold leading-tight tracking-tight text-white sm:text-3xl">
              {questionQuery.data ?? "Loading market…"}
            </h1>

            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              <Stat label="Total pool" value={`${formatUsdc(totalPool)} mUSDC`} />
              <Stat
                label="Deadline"
                value={formatDeadline(deadline)}
                hint="Resolution opens after this time"
              />
            </div>

            <div className="mt-5">
              <div className="h-3 overflow-hidden rounded-full bg-rose-400/30">
                <div
                  className="h-full rounded-full bg-emerald-400"
                  style={{ width: `${yesShare}%` }}
                />
              </div>
              <div className="mt-2 flex justify-between text-xs text-slate-400">
                <span>
                  YES {formatUsdc(totalYes)} · {formatPercent(totalYes, totalPool)}
                </span>
                <span>
                  NO {formatUsdc(totalNo)} · {formatPercent(totalNo, totalPool)}
                </span>
              </div>
            </div>

            <div className="mt-5 grid gap-3 border-t border-white/10 pt-4 text-sm sm:grid-cols-2">
              <div>
                <Label>Creator</Label>
                <div className="mt-1 font-mono text-slate-300">
                  {shortAddress(creatorQuery.data)}
                </div>
              </div>
              <div>
                <Label>Resolver</Label>
                <div className="mt-1 font-mono text-slate-300">
                  {shortAddress(resolverQuery.data)}
                </div>
              </div>
              <div>
                <Label>Created</Label>
                <div className="mt-1 text-slate-300">{formatDeadline(createdAtQuery.data)}</div>
              </div>
              <div>
                <Label>Your position</Label>
                <div className="mt-1 text-slate-300">
                  {formatUsdc(yesStake)} YES · {formatUsdc(noStake)} NO
                </div>
              </div>
            </div>
          </Card>

          <BetForm
            market={contract}
            marketAddress={address}
            outcome={outcome}
            deadline={deadline}
            onSuccess={refresh}
          />
        </div>

        <div className="space-y-4">
          <ClaimPanel
            market={contract}
            outcome={outcome}
            totalYes={totalYes}
            totalNo={totalNo}
            yesStake={yesStake}
            noStake={noStake}
            claimed={claimed}
            onSuccess={refresh}
          />
          <ResolvePanel
            market={contract}
            resolver={resolverQuery.data}
            outcome={outcome}
            deadline={deadline}
            onSuccess={refresh}
          />
          <Card>
            <h2 className="text-sm font-semibold text-white">How it settles</h2>
            <p className="mt-2 text-sm leading-6 text-slate-400">
              Winners split the entire pool in proportion to their winning stake. Losing-side funds
              stay in the pool. Rounding dust remains locked in the market contract.
            </p>
          </Card>
        </div>
      </div>
    </div>
  );
}

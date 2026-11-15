"use client";

import { useState } from "react";
import { prepareContractCall, type ThirdwebContract } from "thirdweb";
import { useSendAndConfirmTransaction } from "thirdweb/react";
import { marketMethods } from "@/lib/contracts";
import { errorMessage, formatUsdc, outcomeLabel } from "@/lib/format";
import { Badge, Button, Card, Notice, Stat } from "./ui";

export function ClaimPanel({
  market,
  outcome,
  totalYes,
  totalNo,
  yesStake,
  noStake,
  claimed,
  onSuccess,
}: {
  market: ThirdwebContract;
  outcome: number;
  totalYes: bigint;
  totalNo: bigint;
  yesStake: bigint;
  noStake: bigint;
  claimed: boolean;
  onSuccess: () => void;
}) {
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const { mutateAsync, isPending } = useSendAndConfirmTransaction({ payModal: false });

  if (outcome === 0) return null;

  const winningStake = outcome === 1 ? yesStake : noStake;
  if (winningStake === 0n) return null;

  const winningPool = outcome === 1 ? totalYes : totalNo;
  const totalPool = totalYes + totalNo;
  const payout = winningPool === 0n ? 0n : (winningStake * totalPool) / winningPool;

  async function handleClaim() {
    setError(null);
    setStatus(null);
    try {
      setStatus("Confirm claim in the wallet…");
      await mutateAsync(
        prepareContractCall({
          contract: market,
          method: marketMethods.claim,
          params: [],
        }),
      );
      setStatus("Claimed.");
      onSuccess();
    } catch (caught) {
      setStatus(null);
      setError(errorMessage(caught));
    }
  }

  return (
    <Card className="border-emerald-400/20 bg-emerald-400/[0.03]">
      <div className="flex items-center justify-between gap-3">
        <h2 className="text-sm font-semibold text-white">Your winnings</h2>
        <Badge tone={outcome === 1 ? "yes" : "no"}>{outcomeLabel(outcome)} won</Badge>
      </div>

      <div className="mt-4">
        <Stat
          label="Estimated payout"
          value={`${formatUsdc(payout)} mUSDC`}
          hint={`Winning stake: ${formatUsdc(winningStake)} mUSDC`}
        />
      </div>

      {claimed ? (
        <div className="mt-4">
          <Notice tone="success">Already claimed.</Notice>
        </div>
      ) : (
        <Button
          className="mt-4 w-full"
          variant="success"
          disabled={isPending}
          onClick={() => void handleClaim()}
        >
          {isPending ? "Claiming…" : "Claim winnings"}
        </Button>
      )}

      {status ? (
        <div className="mt-3">
          <Notice tone="info">{status}</Notice>
        </div>
      ) : null}
      {error ? (
        <div className="mt-3">
          <Notice tone="error">{error}</Notice>
        </div>
      ) : null}
    </Card>
  );
}

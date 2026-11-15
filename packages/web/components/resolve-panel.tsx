"use client";

import { useState } from "react";
import { prepareContractCall, type ThirdwebContract } from "thirdweb";
import { useActiveAccount, useSendAndConfirmTransaction } from "thirdweb/react";
import { marketMethods } from "@/lib/contracts";
import { errorMessage, formatDeadline, shortAddress } from "@/lib/format";
import { useNow } from "@/lib/use-now";
import { Button, Card, Notice } from "./ui";

export function ResolvePanel({
  market,
  resolver,
  outcome,
  deadline,
  onSuccess,
}: {
  market: ThirdwebContract;
  resolver: string | undefined;
  outcome: number;
  deadline: bigint | undefined;
  onSuccess: () => void;
}) {
  const account = useActiveAccount();
  const now = useNow();
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const { mutateAsync, isPending } = useSendAndConfirmTransaction({ payModal: false });

  const isResolver =
    Boolean(account?.address && resolver) &&
    account?.address.toLowerCase() === resolver?.toLowerCase();
  const canResolve =
    isResolver && outcome === 0 && deadline !== undefined && now >= Number(deadline);

  if (!isResolver || outcome !== 0) return null;

  async function handleResolve(result: 1 | 2) {
    setError(null);
    setStatus(null);
    try {
      setStatus("Confirm resolution in the wallet…");
      await mutateAsync(
        prepareContractCall({
          contract: market,
          method: marketMethods.resolve,
          params: [result],
        }),
      );
      setStatus(`Resolved ${result === 1 ? "YES" : "NO"}.`);
      onSuccess();
    } catch (caught) {
      setStatus(null);
      setError(errorMessage(caught));
    }
  }

  return (
    <Card className="border-amber-400/20 bg-amber-400/[0.03]">
      <h2 className="text-sm font-semibold text-white">Resolver controls</h2>
      <p className="mt-2 text-xs leading-5 text-slate-400">
        You are the resolver for this market ({shortAddress(resolver)}). Resolve after{" "}
        {formatDeadline(deadline)}.
      </p>

      {!canResolve ? (
        <div className="mt-3">
          <Notice tone="warning">Resolution opens after the deadline.</Notice>
        </div>
      ) : (
        <div className="mt-4 grid grid-cols-2 gap-2">
          <Button variant="success" disabled={isPending} onClick={() => void handleResolve(1)}>
            Resolve YES
          </Button>
          <Button variant="danger" disabled={isPending} onClick={() => void handleResolve(2)}>
            Resolve NO
          </Button>
        </div>
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

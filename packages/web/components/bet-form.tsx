"use client";

import { useState } from "react";
import { ZERO_ADDRESS, prepareContractCall, type ThirdwebContract } from "thirdweb";
import { toTokens, toUnits } from "thirdweb/utils";
import { useActiveAccount, useReadContract, useSendAndConfirmTransaction } from "thirdweb/react";
import { marketMethods, usdcContract, usdcMethods } from "@/lib/contracts";
import { errorMessage, formatUsdc } from "@/lib/format";
import { useNow } from "@/lib/use-now";
import { cn } from "@/lib/cn";
import { Button, Card, Label, Notice } from "./ui";

type BetFormProps = {
  market: ThirdwebContract;
  marketAddress: string;
  outcome: number;
  deadline: bigint | undefined;
  onSuccess: () => void;
};

export function BetForm(props: BetFormProps) {
  if (!usdcContract) return <Notice tone="warning">mUSDC address is not configured.</Notice>;
  return <BetFormInner {...props} usdc={usdcContract} />;
}

function BetFormInner({
  market,
  marketAddress,
  outcome,
  deadline,
  onSuccess,
  usdc,
}: BetFormProps & { usdc: ThirdwebContract }) {
  const account = useActiveAccount();
  const now = useNow();
  const [side, setSide] = useState<1 | 2>(1);
  const [amount, setAmount] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const { data: balance, refetch: refetchBalance } = useReadContract({
    contract: usdc,
    method: usdcMethods.balanceOf,
    params: [account?.address ?? ZERO_ADDRESS],
    queryOptions: { enabled: Boolean(account), refetchInterval: 5_000 },
  });
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    contract: usdc,
    method: usdcMethods.allowance,
    params: [account?.address ?? ZERO_ADDRESS, marketAddress],
    queryOptions: { enabled: Boolean(account), refetchInterval: 5_000 },
  });
  const { mutateAsync, isPending } = useSendAndConfirmTransaction({ payModal: false });

  const isClosed = outcome !== 0 || (deadline !== undefined && now >= Number(deadline));

  async function handleBet() {
    setError(null);
    setStatus(null);

    if (!account) {
      setError("Connect a wallet before betting.");
      return;
    }
    if (isClosed) {
      setError("Betting is closed for this market.");
      return;
    }

    let amountWei: bigint;
    try {
      amountWei = toUnits(amount, 6);
    } catch {
      setError("Enter a valid mUSDC amount with at most 6 decimals.");
      return;
    }

    if (amountWei <= 0n) {
      setError("Bet amount must be greater than zero.");
      return;
    }
    if (balance !== undefined && amountWei > balance) {
      setError(`You only have ${formatUsdc(balance)} mUSDC. Use the faucet first.`);
      return;
    }

    try {
      if ((allowance ?? 0n) < amountWei) {
        setStatus("Approving mUSDC…");
        await mutateAsync(
          prepareContractCall({
            contract: usdc,
            method: usdcMethods.approve,
            params: [marketAddress, amountWei],
          }),
        );
        await refetchAllowance();
      }

      setStatus("Confirm your bet in the wallet…");
      await mutateAsync(
        prepareContractCall({
          contract: market,
          method: marketMethods.bet,
          params: [side, amountWei],
        }),
      );

      setStatus(`Bet placed on ${side === 1 ? "YES" : "NO"}.`);
      setAmount("");
      await Promise.all([refetchBalance(), refetchAllowance()]);
      onSuccess();
    } catch (caught) {
      setStatus(null);
      setError(errorMessage(caught));
    }
  }

  return (
    <Card>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold text-white">Place a bet</h2>
          <p className="mt-1 text-sm text-slate-400">
            Your stake joins the selected side&apos;s pool.
          </p>
        </div>
        <div className="text-right text-xs text-slate-400">
          <div>Balance</div>
          <div className="text-sm font-semibold text-white">{formatUsdc(balance)} mUSDC</div>
        </div>
      </div>

      {isClosed ? (
        <div className="mt-4">
          <Notice tone="warning">
            {outcome === 0
              ? "The deadline has passed. Waiting for the resolver."
              : "This market is resolved. Betting is closed."}
          </Notice>
        </div>
      ) : (
        <form
          className="mt-5 space-y-4"
          onSubmit={(event) => {
            event.preventDefault();
            void handleBet();
          }}
        >
          <div className="grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={() => setSide(1)}
              className={cn(
                "rounded-xl border px-4 py-3 text-left transition",
                side === 1
                  ? "border-emerald-400/60 bg-emerald-400/15"
                  : "border-white/10 bg-white/[0.03] hover:border-white/20",
              )}
            >
              <span className="block text-sm font-bold text-emerald-300">YES</span>
              <span className="mt-1 block text-xs text-slate-400">Pays if resolved YES</span>
            </button>
            <button
              type="button"
              onClick={() => setSide(2)}
              className={cn(
                "rounded-xl border px-4 py-3 text-left transition",
                side === 2
                  ? "border-rose-400/60 bg-rose-400/15"
                  : "border-white/10 bg-white/[0.03] hover:border-white/20",
              )}
            >
              <span className="block text-sm font-bold text-rose-300">NO</span>
              <span className="mt-1 block text-xs text-slate-400">Pays if resolved NO</span>
            </button>
          </div>

          <div>
            <div className="mb-2 flex items-center justify-between">
              <Label>Amount</Label>
              <button
                type="button"
                className="text-xs font-semibold text-cyan-300 hover:text-cyan-200"
                onClick={() => setAmount(toTokens(balance ?? 0n, 6))}
              >
                Max
              </button>
            </div>
            <div className="flex items-center rounded-xl border border-white/10 bg-slate-950/60 px-4">
              <input
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
                inputMode="decimal"
                placeholder="0.00"
                className="min-w-0 flex-1 bg-transparent py-3 text-lg font-semibold text-white outline-none placeholder:text-slate-600"
              />
              <span className="text-sm font-semibold text-slate-400">mUSDC</span>
            </div>
          </div>

          <Button
            type="submit"
            className="w-full"
            variant={side === 1 ? "success" : "danger"}
            disabled={isPending || !account}
          >
            {isPending ? "Sending…" : `Bet ${side === 1 ? "YES" : "NO"}`}
          </Button>

          {!account ? (
            <p className="text-center text-xs text-slate-500">
              Connect a wallet to approve and place the bet.
            </p>
          ) : null}
        </form>
      )}

      {status ? (
        <div className="mt-4">
          <Notice tone="info">{status}</Notice>
        </div>
      ) : null}
      {error ? (
        <div className="mt-4">
          <Notice tone="error">{error}</Notice>
        </div>
      ) : null}
    </Card>
  );
}

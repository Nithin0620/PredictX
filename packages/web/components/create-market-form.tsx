"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { isAddress, prepareContractCall, readContract, type ThirdwebContract } from "thirdweb";
import { useActiveAccount, useSendAndConfirmTransaction } from "thirdweb/react";
import { factoryContract, factoryMethods } from "@/lib/contracts";
import { isConfigured } from "@/lib/config";
import { errorMessage } from "@/lib/format";
import { SetupNotice } from "./setup-notice";
import { Button, Card, Label, Notice } from "./ui";

export function CreateMarketForm() {
  if (!isConfigured || !factoryContract) return <SetupNotice />;
  return <CreateMarketFormInner factory={factoryContract} />;
}

function CreateMarketFormInner({ factory }: { factory: ThirdwebContract }) {
  const router = useRouter();
  const account = useActiveAccount();
  const [question, setQuestion] = useState("");
  const [deadline, setDeadline] = useState("");
  const [resolver, setResolver] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const { mutateAsync, isPending } = useSendAndConfirmTransaction({ payModal: false });

  async function handleSubmit() {
    setError(null);
    setStatus(null);

    if (!account) {
      setError("Connect a wallet before creating a market.");
      return;
    }

    const trimmedQuestion = question.trim();
    if (trimmedQuestion.length < 8) {
      setError("Write a clear question with at least 8 characters.");
      return;
    }

    const deadlineMs = new Date(deadline).getTime();
    if (!Number.isFinite(deadlineMs) || deadlineMs <= Date.now() + 60_000) {
      setError("Choose a deadline at least one minute in the future.");
      return;
    }

    const resolverAddress = resolver.trim() || account.address;
    if (!isAddress(resolverAddress)) {
      setError("Resolver must be a valid address, or leave it blank to use your wallet.");
      return;
    }

    try {
      setStatus("Confirm market creation in the wallet…");
      await mutateAsync(
        prepareContractCall({
          contract: factory,
          method: factoryMethods.createMarket,
          params: [trimmedQuestion, BigInt(Math.floor(deadlineMs / 1000)), resolverAddress],
        }),
      );

      setStatus("Market created. Opening…");
      const marketCount = await readContract({
        contract: factory,
        method: factoryMethods.marketCount,
        params: [],
      });
      const marketAddress = await readContract({
        contract: factory,
        method: factoryMethods.markets,
        params: [marketCount],
      });

      router.push(`/market/${marketAddress}`);
    } catch (caught) {
      setStatus(null);
      setError(errorMessage(caught));
    }
  }

  return (
    <Card className="mx-auto max-w-2xl">
      <h1 className="text-2xl font-bold tracking-tight text-white">Create a market</h1>
      <p className="mt-2 text-sm leading-6 text-slate-400">
        Ask a yes/no question, choose a deadline, and nominate a trusted resolver. The resolver can
        only settle the market after the deadline.
      </p>

      <form
        className="mt-6 space-y-5"
        onSubmit={(event) => {
          event.preventDefault();
          void handleSubmit();
        }}
      >
        <div>
          <Label>Question</Label>
          <textarea
            value={question}
            onChange={(event) => setQuestion(event.target.value)}
            rows={3}
            placeholder="Will ETH close above $4,000 on Friday?"
            className="mt-2 w-full resize-none rounded-xl border border-white/10 bg-slate-950/60 px-4 py-3 text-sm text-white outline-none placeholder:text-slate-600 focus:border-cyan-400/40"
          />
        </div>

        <div>
          <Label>Deadline</Label>
          <input
            type="datetime-local"
            value={deadline}
            onChange={(event) => setDeadline(event.target.value)}
            className="mt-2 w-full rounded-xl border border-white/10 bg-slate-950/60 px-4 py-3 text-sm text-white outline-none focus:border-cyan-400/40"
          />
          <p className="mt-2 text-xs text-slate-500">
            Times are interpreted in your local timezone.
          </p>
        </div>

        <div>
          <Label>Resolver</Label>
          <input
            value={resolver}
            onChange={(event) => setResolver(event.target.value)}
            placeholder={account?.address ?? "0x… (defaults to your wallet)"}
            className="mt-2 w-full rounded-xl border border-white/10 bg-slate-950/60 px-4 py-3 font-mono text-sm text-white outline-none placeholder:text-slate-600 focus:border-cyan-400/40"
          />
          <p className="mt-2 text-xs text-slate-500">
            Leave blank to make your connected wallet the resolver.
          </p>
        </div>

        <Button type="submit" className="w-full" disabled={isPending || !account}>
          {isPending ? "Creating…" : "Create market"}
        </Button>

        {!account ? (
          <p className="text-center text-xs text-slate-500">Connect a wallet to create a market.</p>
        ) : null}
      </form>

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

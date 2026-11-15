"use client";

import { useState } from "react";
import { ZERO_ADDRESS, prepareContractCall, type ThirdwebContract } from "thirdweb";
import { useActiveAccount, useReadContract, useSendAndConfirmTransaction } from "thirdweb/react";
import { usdcContract, usdcMethods } from "@/lib/contracts";
import { errorMessage, formatUsdc } from "@/lib/format";
import { Button } from "./ui";

export function FaucetButton() {
  if (!usdcContract) return null;
  return <FaucetButtonInner contract={usdcContract} />;
}

function FaucetButtonInner({ contract }: { contract: ThirdwebContract }) {
  const account = useActiveAccount();
  const [error, setError] = useState<string | null>(null);
  const { data: balance, refetch } = useReadContract({
    contract,
    method: usdcMethods.balanceOf,
    params: [account?.address ?? ZERO_ADDRESS],
    queryOptions: { enabled: Boolean(account), refetchInterval: 5_000 },
  });
  const { mutateAsync, isPending } = useSendAndConfirmTransaction({ payModal: false });

  if (!account) return null;

  async function handleFaucet() {
    setError(null);
    try {
      await mutateAsync(
        prepareContractCall({
          contract,
          method: usdcMethods.faucet,
          params: [],
        }),
      );
      await refetch();
    } catch (caught) {
      setError(errorMessage(caught));
    }
  }

  return (
    <div className="flex items-center gap-2">
      <span className="hidden text-xs text-slate-400 md:inline">{formatUsdc(balance)} mUSDC</span>
      <Button variant="secondary" onClick={() => void handleFaucet()} disabled={isPending}>
        {isPending ? "Minting…" : "Faucet"}
      </Button>
      {error ? <span className="max-w-40 truncate text-xs text-rose-300">{error}</span> : null}
    </div>
  );
}

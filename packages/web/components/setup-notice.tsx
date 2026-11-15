import { Card, Notice } from "./ui";

export function SetupNotice() {
  return (
    <Card className="border-amber-400/20 bg-amber-400/[0.03]">
      <h2 className="text-lg font-semibold text-white">Frontend setup needed</h2>
      <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-300">
        Create <code className="rounded bg-white/10 px-1.5 py-0.5">packages/web/.env.local</code>{" "}
        with the deployed Base Sepolia addresses and a thirdweb client ID.
      </p>
      <div className="mt-4 rounded-xl border border-white/10 bg-slate-950/70 p-4 font-mono text-xs leading-6 text-slate-300">
        <div>NEXT_PUBLIC_THIRDWEB_CLIENT_ID=...</div>
        <div>NEXT_PUBLIC_USDC_ADDRESS=0x...</div>
        <div>NEXT_PUBLIC_FACTORY_ADDRESS=0x...</div>
      </div>
      <div className="mt-4">
        <Notice tone="warning">
          Get a free client ID from{" "}
          <a
            className="font-semibold underline decoration-amber-300/50 underline-offset-2"
            href="https://thirdweb.com/create-api-key"
            target="_blank"
            rel="noreferrer"
          >
            thirdweb
          </a>
          . The app reads markets directly from Base Sepolia; no backend is required.
        </Notice>
      </div>
    </Card>
  );
}

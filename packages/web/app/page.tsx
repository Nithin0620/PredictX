import Link from "next/link";
import { MarketList } from "@/components/market-list";
import { Badge } from "@/components/ui";

const steps = [
  {
    title: "Pick a side",
    body: "Stake mUSDC on YES or NO before the deadline. Both sides feed one pool.",
  },
  {
    title: "Resolver settles",
    body: "After the deadline, the trusted resolver records the real outcome on-chain.",
  },
  {
    title: "Winners claim",
    body: "Winning stakes split the entire pool pro-rata. No AMM, no LP tokens, no backend.",
  },
];

export default function HomePage() {
  return (
    <div>
      <section className="relative overflow-hidden rounded-3xl border border-white/10 bg-slate-900/50 p-6 shadow-2xl shadow-black/30 sm:p-10">
        <div className="absolute -right-20 -top-24 h-64 w-64 rounded-full bg-cyan-400/10 blur-3xl" />
        <div className="relative max-w-3xl">
          <Badge tone="open">Base Sepolia testnet</Badge>
          <h1 className="mt-5 text-4xl font-black leading-[1.05] tracking-tight text-white sm:text-6xl">
            Bet on outcomes.
            <span className="block bg-gradient-to-r from-cyan-300 to-emerald-300 bg-clip-text text-transparent">
              Split the pool.
            </span>
          </h1>
          <p className="mt-5 max-w-2xl text-base leading-7 text-slate-300 sm:text-lg">
            PredictX Lite is a small parimutuel prediction market. Create a YES/NO question, stake
            mock USDC, resolve it after the deadline, and claim your share.
          </p>
          <div className="mt-7 flex flex-wrap gap-3">
            <Link
              href="/create"
              className="inline-flex items-center justify-center rounded-xl bg-cyan-400 px-5 py-3 text-sm font-bold text-slate-950 transition hover:bg-cyan-300"
            >
              Create a market
            </Link>
            <a
              href="#markets"
              className="inline-flex items-center justify-center rounded-xl border border-white/15 bg-white/5 px-5 py-3 text-sm font-semibold text-slate-100 transition hover:border-white/25 hover:bg-white/10"
            >
              Browse markets
            </a>
          </div>
        </div>
      </section>

      <section className="mt-6 grid gap-4 sm:grid-cols-3">
        {steps.map((step, index) => (
          <div key={step.title} className="rounded-2xl border border-white/10 bg-white/[0.03] p-5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-cyan-400/10 text-sm font-bold text-cyan-300">
              {index + 1}
            </div>
            <h2 className="mt-3 text-sm font-semibold text-white">{step.title}</h2>
            <p className="mt-2 text-sm leading-6 text-slate-400">{step.body}</p>
          </div>
        ))}
      </section>

      <div id="markets">
        <MarketList />
      </div>
    </div>
  );
}

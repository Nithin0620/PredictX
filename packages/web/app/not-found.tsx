import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mx-auto max-w-lg py-20 text-center">
      <div className="text-6xl font-black text-cyan-300">404</div>
      <h1 className="mt-4 text-2xl font-bold text-white">Market not found</h1>
      <p className="mt-2 text-sm text-slate-400">The page you are looking for does not exist.</p>
      <Link
        href="/"
        className="mt-6 inline-flex rounded-xl bg-cyan-400 px-5 py-3 text-sm font-bold text-slate-950 hover:bg-cyan-300"
      >
        Back to markets
      </Link>
    </div>
  );
}

import type { Metadata } from "next";
import type { ReactNode } from "react";
import { Header } from "@/components/header";
import { Providers } from "@/components/providers";
import { WrongNetworkBanner } from "@/components/wrong-network-banner";
import "./globals.css";

export const metadata: Metadata = {
  title: "PredictX Lite",
  description: "Parimutuel YES/NO prediction markets on Base Sepolia.",
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body className="min-h-screen text-slate-100 antialiased">
        <Providers>
          <Header />
          <WrongNetworkBanner />
          <main className="mx-auto w-full max-w-6xl px-4 pb-20 pt-8 sm:px-6 lg:px-8">
            {children}
          </main>
          <footer className="border-t border-white/10 py-8 text-center text-xs text-slate-500">
            PredictX Lite · Base Sepolia · testnet only · mock USDC has no value
          </footer>
        </Providers>
      </body>
    </html>
  );
}

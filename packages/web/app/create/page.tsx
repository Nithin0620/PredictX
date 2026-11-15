import Link from "next/link";
import { CreateMarketForm } from "@/components/create-market-form";

export default function CreateMarketPage() {
  return (
    <div>
      <Link href="/" className="text-sm font-semibold text-cyan-300 hover:text-cyan-200">
        ← Back to markets
      </Link>
      <div className="mt-6">
        <CreateMarketForm />
      </div>
    </div>
  );
}

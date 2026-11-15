import type { ButtonHTMLAttributes, HTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/cn";

type ButtonVariant = "primary" | "secondary" | "success" | "danger" | "ghost";

const buttonVariants: Record<ButtonVariant, string> = {
  primary:
    "bg-cyan-400 text-slate-950 hover:bg-cyan-300 disabled:bg-slate-700 disabled:text-slate-400",
  secondary:
    "border border-white/15 bg-white/5 text-slate-100 hover:border-white/25 hover:bg-white/10 disabled:border-white/5 disabled:text-slate-500",
  success:
    "bg-emerald-400 text-slate-950 hover:bg-emerald-300 disabled:bg-slate-700 disabled:text-slate-400",
  danger:
    "bg-rose-400 text-slate-950 hover:bg-rose-300 disabled:bg-slate-700 disabled:text-slate-400",
  ghost: "text-slate-300 hover:bg-white/5 hover:text-white disabled:text-slate-600",
};

export function Button({
  className,
  variant = "primary",
  type = "button",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant }) {
  return (
    <button
      type={type}
      className={cn(
        "inline-flex items-center justify-center rounded-xl px-4 py-2.5 text-sm font-semibold transition disabled:cursor-not-allowed",
        buttonVariants[variant],
        className,
      )}
      {...props}
    />
  );
}

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "rounded-2xl border border-white/10 bg-slate-900/70 p-5 shadow-2xl shadow-black/20 backdrop-blur",
        className,
      )}
      {...props}
    />
  );
}

type BadgeTone = "yes" | "no" | "open" | "neutral" | "warning";

const badgeTones: Record<BadgeTone, string> = {
  yes: "border-emerald-400/30 bg-emerald-400/10 text-emerald-300",
  no: "border-rose-400/30 bg-rose-400/10 text-rose-300",
  open: "border-cyan-400/30 bg-cyan-400/10 text-cyan-300",
  neutral: "border-white/15 bg-white/5 text-slate-300",
  warning: "border-amber-400/30 bg-amber-400/10 text-amber-300",
};

export function Badge({
  tone = "neutral",
  className,
  children,
}: {
  tone?: BadgeTone;
  className?: string;
  children: ReactNode;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-semibold tracking-wide",
        badgeTones[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

type NoticeTone = "info" | "error" | "success" | "warning";

const noticeTones: Record<NoticeTone, string> = {
  info: "border-cyan-400/20 bg-cyan-400/5 text-cyan-100",
  error: "border-rose-400/20 bg-rose-400/5 text-rose-100",
  success: "border-emerald-400/20 bg-emerald-400/5 text-emerald-100",
  warning: "border-amber-400/20 bg-amber-400/5 text-amber-100",
};

export function Notice({ tone = "info", children }: { tone?: NoticeTone; children: ReactNode }) {
  return (
    <div className={cn("rounded-xl border px-4 py-3 text-sm", noticeTones[tone])}>{children}</div>
  );
}

export function Label({ children }: { children: ReactNode }) {
  return (
    <span className="text-xs font-semibold uppercase tracking-widest text-slate-400">
      {children}
    </span>
  );
}

export function Stat({
  label,
  value,
  hint,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
}) {
  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.03] p-4">
      <Label>{label}</Label>
      <div className="mt-2 text-xl font-semibold text-white">{value}</div>
      {hint ? <div className="mt-1 text-xs text-slate-400">{hint}</div> : null}
    </div>
  );
}

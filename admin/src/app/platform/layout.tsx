export default function PlatformLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background p-8">
      <div className="mx-auto max-w-5xl">{children}</div>
    </div>
  );
}

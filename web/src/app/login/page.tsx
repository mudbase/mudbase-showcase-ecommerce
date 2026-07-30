import Link from "next/link"
import { LoginForm } from "@/components/auth/LoginForm"

export default function LoginPage(): React.JSX.Element {
  return (
    <div className="container flex justify-center py-16">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-1 text-center">
          <h1 className="font-display text-2xl font-semibold tracking-tight">Sign in</h1>
          <p className="text-sm text-muted-foreground">Welcome back to Commonwealth Goods.</p>
        </div>
        <LoginForm />
        <p className="text-center text-sm text-muted-foreground">
          New here?{" "}
          <Link href="/register" className="underline underline-offset-4">
            Create an account
          </Link>
        </p>
      </div>
    </div>
  )
}

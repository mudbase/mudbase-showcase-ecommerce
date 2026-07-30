"use client"

import Link from "next/link"
import { useRouter } from "next/navigation"
import { RegisterForm } from "@/components/auth/RegisterForm"

export default function RegisterPage(): React.JSX.Element {
  const router = useRouter()

  return (
    <div className="container flex justify-center py-16">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-1 text-center">
          <h1 className="font-display text-2xl font-semibold tracking-tight">Create your account</h1>
          <p className="text-sm text-muted-foreground">Track orders and check out faster next time.</p>
        </div>
        <RegisterForm onSuccess={() => router.push("/")} />
        <p className="text-center text-sm text-muted-foreground">
          Already have an account?{" "}
          <Link href="/login" className="underline underline-offset-4">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  )
}

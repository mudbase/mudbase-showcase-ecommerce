import { NextRequest, NextResponse } from "next/server"
import { z } from "zod"
import { createOrderPaymentLink } from "@/lib/mudbase-server"

const bodySchema = z.object({
  orderId: z.string().min(1),
  amount: z.string().min(1),
  currency: z.string().min(1),
  network: z.string().min(1),
  redirectUrl: z.string().url(),
})

export async function POST(request: NextRequest): Promise<NextResponse> {
  const parsed = bodySchema.safeParse(await request.json().catch(() => null))
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request body" }, { status: 400 })
  }

  const { orderId, amount, currency, network, redirectUrl } = parsed.data

  const result = await createOrderPaymentLink({
    amount,
    currency,
    network,
    redirectUrl,
    description: `Commonwealth Goods order ${orderId}`,
  })

  if (!result.ok) {
    const status = result.reason === "kyc_required" ? 403 : 502
    return NextResponse.json({ error: result.message, reason: result.reason }, { status })
  }

  return NextResponse.json({ link: result.link }, { status: 201 })
}

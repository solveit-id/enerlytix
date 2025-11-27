import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { Prisma } from "@prisma/client";
import { TARIF_PER_KWH } from "@/lib/meterEnergy";

export async function POST(req: Request) {
  try {
    const body = await req.json();

    const userId = Number(body.user_id);
    const amount = Number(body.amount);

    if (!userId || !amount || amount <= 0) {
      return NextResponse.json(
        { error: "Invalid user_id or amount" },
        { status: 400 }
      );
    }

    const meter = await prisma.meter.findFirst({
      where: { userId },
    });

    if (!meter) {
      return NextResponse.json(
        { error: "Meter tidak ditemukan" },
        { status: 404 }
      );
    }

    const kwhAdded = amount / TARIF_PER_KWH;

    const tokenNumber = Math.random()
      .toString(36)
      .substring(2, 10)
      .toUpperCase();

    const result = await prisma.$transaction(
      async (tx: Prisma.TransactionClient) => {
        const tokenHistory = await tx.tokenHistory.create({
          data: {
            meterId: meter.id,
            tokenNumber,
            kwhAdded,
            price: amount,
          },
        });

        const updatedMeter = await tx.meter.update({
          where: { id: meter.id },
          data: {
            tokenBalance: { increment: amount },
            lastUpdate: new Date(),
          },
        });

        return { tokenHistory, updatedMeter };
      }
    );

    return NextResponse.json(
      {
        message: "Token berhasil dibeli",
        token: result.tokenHistory.tokenNumber,
        kwhAdded: result.tokenHistory.kwhAdded,
        meter: {
          id: result.updatedMeter.id,
          tokenBalance: result.updatedMeter.tokenBalance,
          currentKwh: result.updatedMeter.currentKwh,
        },
      },
      { status: 200 }
    );
  } catch (error: any) {
    console.error("POST /api/user/buy-token error:", error);
    return NextResponse.json(
      { error: error.message || "Terjadi kesalahan server" },
      { status: 500 }
    );
  }
}
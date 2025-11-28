import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { Prisma } from "@prisma/client";
import { TARIF_PER_KWH, updateMeterEnergyForMeter } from "@/lib/meterEnergy";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const userIdRaw = body.user_id ?? body.userId;
    const amountRaw = body.amount;

    const userId = Number(userIdRaw);
    const amount = Number(amountRaw);

    if (!userId || Number.isNaN(userId) || !amount || amount <= 0) {
      return NextResponse.json(
        {
          success: false,
          message: "user_id / userId atau amount tidak valid",
        },
        { status: 400 }
      );
    }

    const meter = await prisma.meter.findFirst({
      where: { userId },
    });

    if (!meter) {
      return NextResponse.json(
        {
          success: false,
          message: "Meter tidak ditemukan",
        },
        { status: 404 }
      );
    }

    await updateMeterEnergyForMeter(meter.id);

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
        success: true,
        message: "Token berhasil dibeli",
        data: {
          tokenNumber: result.tokenHistory.tokenNumber,
          kwhAdded: result.tokenHistory.kwhAdded,
          meter: {
            id: result.updatedMeter.id,
            tokenBalance: result.updatedMeter.tokenBalance,
            currentKwh: result.updatedMeter.currentKwh,
          },
        },
      },
      { status: 200 }
    );
  } catch (error: any) {
    console.error("POST /api/user/buyToken error:", error);
    return NextResponse.json(
      {
        success: false,
        message: error?.message ?? "Terjadi kesalahan server",
      },
      { status: 500 }
    );
  }
}
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { TARIF_PER_KWH } from "@/lib/meterEnergy";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const meterId = Number(body.meterId);
    const amount = Number(body.amount);

    if (!meterId || !amount || amount <= 0) {
      return NextResponse.json(
        { message: "meterId dan amount wajib diisi dan > 0" },
        { status: 400 }
      );
    }

    const meter = await prisma.meter.findUnique({
      where: { id: meterId },
    });

    if (!meter) {
      return NextResponse.json(
        { message: "Meter not found" },
        { status: 404 }
      );
    }

    const kwhAdded = amount / TARIF_PER_KWH;
    const tokenNumber = Math.random()
      .toString(36)
      .substring(2, 10)
      .toUpperCase();

    const result = await prisma.$transaction(async (tx) => {
      await tx.tokenHistory.create({
        data: {
          meterId,
          tokenNumber,
          kwhAdded,
          price: amount,
        },
      });

      const updatedMeter = await tx.meter.update({
        where: { id: meterId },
        data: {
          tokenBalance: { increment: amount },
          lastUpdate: new Date(),
        },
      });

      return updatedMeter;
    });

    return NextResponse.json({
      message: "Top-up berhasil",
      meter: {
        id: result.id,
        tokenBalance: result.tokenBalance,
        currentKwh: result.currentKwh,
      },
    });
  } catch (error) {
    console.error("POST /api/admin/topup-token error:", error);
    return NextResponse.json(
      { message: "Internal server error" },
      { status: 500 }
    );
  }
}
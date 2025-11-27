import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { updateMeterEnergyForMeter } from "@/lib/meterEnergy";

export async function POST(req: NextRequest) {
  try {
    const { userId, watt } = await req.json();

    const userIdNum = Number(userId);
    const wattNum = Number(watt);

    if (!userIdNum || wattNum < 0) {
      return NextResponse.json(
        { message: "userId dan watt wajib diisi dan watt >= 0" },
        { status: 400 }
      );
    }

    const meter = await prisma.meter.findFirst({
      where: { userId: userIdNum },
    });

    if (!meter) {
      return NextResponse.json(
        { message: "Meter tidak ditemukan" },
        { status: 404 }
      );
    }

    await updateMeterEnergyForMeter(meter.id);

    const updated = await prisma.meter.update({
      where: { id: meter.id },
      data: {
        currentWatt: wattNum,
        lastUpdate: new Date(),
      },
    });

    return NextResponse.json({
      success: true,
      meter: {
        id: updated.id,
        currentWatt: updated.currentWatt,
        tokenBalance: updated.tokenBalance,
      },
    });
  } catch (e) {
    console.error("POST /api/user/setWatt error:", e);
    return NextResponse.json(
      { message: "Internal server error" },
      { status: 500 }
    );
  }
}
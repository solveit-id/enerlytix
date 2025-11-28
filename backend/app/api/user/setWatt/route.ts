import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { updateMeterEnergyForMeter } from "@/lib/meterEnergy";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const userIdRaw = body.userId ?? body.user_id;
    const wattRaw = body.watt;

    const userId = Number(userIdRaw);
    const watt = Number(wattRaw);

    if (!userId || Number.isNaN(userId) || watt < 0 || Number.isNaN(watt)) {
      return NextResponse.json(
        {
          success: false,
          message: "userId / user_id dan watt wajib diisi, watt >= 0",
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

    const updated = await prisma.meter.update({
      where: { id: meter.id },
      data: {
        currentWatt: watt,
        lastUpdate: new Date(),
      },
    });

    return NextResponse.json(
      {
        success: true,
        message: "Watt berhasil diupdate",
        data: {
          meter: {
            id: updated.id,
            currentWatt: updated.currentWatt,
            tokenBalance: updated.tokenBalance,
          },
        },
      },
      { status: 200 }
    );
  } catch (e) {
    console.error("POST /api/user/setWatt error:", e);
    return NextResponse.json(
      {
        success: false,
        message: "Terjadi kesalahan server saat mengubah watt",
      },
      { status: 500 }
    );
  }
}
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { updateMeterEnergyForMeter } from "@/lib/meterEnergy";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const userIdParam =
      searchParams.get("userId") ?? searchParams.get("user_id");

    if (!userIdParam) {
      return NextResponse.json(
        {
          success: false,
          message: "userId / user_id wajib diisi",
        },
        { status: 400 }
      );
    }

    const userId = Number(userIdParam);
    if (Number.isNaN(userId)) {
      return NextResponse.json(
        {
          success: false,
          message: "userId harus berupa angka",
        },
        { status: 400 }
      );
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        meters: {
          take: 1,
        },
      },
    });

    if (!user || user.meters.length === 0) {
      return NextResponse.json(
        {
          success: false,
          message: "User atau meter tidak ditemukan",
        },
        { status: 404 }
      );
    }

    const meter = user.meters[0];

    await updateMeterEnergyForMeter(meter.id);

    const updatedMeter = await prisma.meter.findUnique({
      where: { id: meter.id },
    });

    if (!updatedMeter) {
      return NextResponse.json(
        {
          success: false,
          message: "Meter tidak ditemukan setelah update",
        },
        { status: 500 }
      );
    }

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const endOfToday = new Date();
    endOfToday.setHours(23, 59, 59, 999);

    const todayUsage = await prisma.usageHistory.findFirst({
      where: {
        meterId: updatedMeter.id,
        usageDate: {
          gte: startOfToday,
          lte: endOfToday,
        },
      },
      orderBy: { usageDate: "desc" },
    });

    const kwhToday = todayUsage?.kwhUsed ?? 0;

    return NextResponse.json(
      {
        success: true,
        message: "Dashboard berhasil dimuat",
        data: {
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
          },
          meter: {
            id: updatedMeter.id,
            meterNumber: updatedMeter.meterNumber,
            alias: updatedMeter.alias,
            powerLimitVa: updatedMeter.powerLimitVa,
            tokenBalance: updatedMeter.tokenBalance,
            currentKwh: updatedMeter.currentKwh,
            kwhToday,
          },
        },
      },
      { status: 200 }
    );
  } catch (error) {
    console.error("GET /api/user/dashboard error:", error);
    return NextResponse.json(
      {
        success: false,
        message: "Terjadi kesalahan server saat memuat dashboard",
      },
      { status: 500 }
    );
  }
}
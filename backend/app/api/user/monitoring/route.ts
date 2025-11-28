import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import type { UsageHistory } from "@prisma/client";
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

    if (!user) {
      return NextResponse.json(
        {
          success: false,
          message: "User tidak ditemukan",
        },
        { status: 404 }
      );
    }

    let meter = user.meters[0];

    if (!meter) {
      const meterNumber = `MT-${user.id.toString().padStart(6, "0")}`;
      const now = new Date();

      meter = await prisma.meter.create({
        data: {
          userId: user.id,
          meterNumber,
          alias: "Meter Utama",
          powerLimitVa: 1300,
          currentKwh: 0,
          tokenBalance: 0,
          currentWatt: 0,
          lastUpdate: now,
        },
      });
    }

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

    const lastUsages = await prisma.usageHistory.findMany({
      where: { meterId: updatedMeter.id },
      orderBy: { usageDate: "desc" },
      take: 5,
    });

    const history = (lastUsages as UsageHistory[])
      .map((u: UsageHistory) => ({
        date: u.usageDate,
        kwhUsed: u.kwhUsed,
      }))
      .reverse();

    return NextResponse.json(
      {
        success: true,
        message: "Monitoring berhasil dimuat",
        data: {
          meter: {
            id: updatedMeter.id,
            powerLimitVa: updatedMeter.powerLimitVa,
            tokenBalance: updatedMeter.tokenBalance,
            currentWatt: updatedMeter.currentWatt,
          },
          kwhToday,
          history,
        },
      },
      { status: 200 }
    );
  } catch (error) {
    console.error("GET /api/user/monitoring error:", error);
    return NextResponse.json(
      {
        success: false,
        message: "Terjadi kesalahan server saat memuat monitoring",
      },
      { status: 500 }
    );
  }
}
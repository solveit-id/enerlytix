import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { updateAllMetersEnergy } from '@/lib/meterEnergy';

export async function GET(_req: NextRequest) {
  try {
    await updateAllMetersEnergy();

    const meters = await prisma.meter.findMany({
      include: {
        user: true,
      },
    });

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    const endOfToday = new Date();
    endOfToday.setHours(23, 59, 59, 999);

    const todayAgg = await prisma.usageHistory.aggregate({
      _sum: {
        kwhUsed: true,
      },
      where: {
        usageDate: {
          gte: startOfToday,
          lte: endOfToday,
        },
      },
    });

    const totalKwhToday = todayAgg._sum.kwhUsed ?? 0;

    const activeUsers = meters.length;

    const list = meters.map((m) => ({
      meterId: m.id,
      userId: m.userId,
      name: m.user.name,
      token: m.tokenBalance,
      kwh: m.currentKwh,
      watt: m.currentWatt,
    }));

    return NextResponse.json({
      totalKwhToday,
      activeUsers,
      list,
    });
  } catch (error) {
    console.error('GET /api/admin/monitoring error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 },
    );
  }
}
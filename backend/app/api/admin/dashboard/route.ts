import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { updateAllMetersEnergy } from '@/lib/meterEnergy';

export async function GET(_req: NextRequest) {
  try {
    await updateAllMetersEnergy();

    const totalUsers = await prisma.user.count({
      where: { role: 'USER' },
    });

    const totalMeters = await prisma.meter.count();

    const totalKwhAgg = await prisma.meter.aggregate({
      _sum: { currentKwh: true },
    });
    const totalKwh = totalKwhAgg._sum.currentKwh ?? 0;

    const totalTokenPriceAgg = await prisma.tokenHistory.aggregate({
      _sum: { price: true },
    });
    const totalTokenPrice = totalTokenPriceAgg._sum.price ?? 0;

    const lowTokenMeters = await prisma.meter.count({
      where: {
        tokenBalance: { lt: 10000 },
      },
    });

    const recentUsers = await prisma.user.findMany({
      where: { role: 'USER' },
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: {
        meters: {
          take: 1,
        },
      },
    });

    const recentUsersMapped = recentUsers.map((u) => {
      const meter = u.meters[0];
      return {
        id: u.id,
        name: u.name,
        email: u.email,
        tokenBalance: meter?.tokenBalance ?? 0,
      };
    });

    return NextResponse.json({
      totalUsers,
      totalMeters,
      totalKwh,
      totalTokenPrice,
      lowTokenMeters,
      recentUsers: recentUsersMapped,
    });
  } catch (error) {
    console.error('GET /api/admin/dashboard error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 },
    );
  }
}
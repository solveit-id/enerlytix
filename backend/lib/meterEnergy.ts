import { prisma } from "@/lib/prisma";

export const TARIF_PER_KWH = 1000;

const TIME_ACCEL =
  process.env.METER_TIME_ACCEL != null
    ? Number(process.env.METER_TIME_ACCEL)
    : 1;

export async function updateMeterEnergyForMeter(meterId: number) {
  const meter = await prisma.meter.findUnique({
    where: { id: meterId },
  });

  if (!meter) return;

  const now = new Date();
  const last = meter.lastUpdate;
  const deltaMs = now.getTime() - last.getTime();

  const deltaHoursReal = deltaMs / (1000 * 60 * 60);

  const deltaHours = deltaHoursReal * (TIME_ACCEL > 0 ? TIME_ACCEL : 1);

  if (deltaHours <= 0 || meter.currentWatt <= 0 || meter.tokenBalance <= 0) {
    await prisma.meter.update({
      where: { id: meter.id },
      data: {
        lastUpdate: now,
        ...(meter.tokenBalance <= 0 ? { currentWatt: 0 } : {}),
      },
    });
    return;
  }

  const idealKwh = (meter.currentWatt * deltaHours) / 1000;

  const maxAffordableKwh = meter.tokenBalance / TARIF_PER_KWH;

  const actualKwh = Math.min(idealKwh, maxAffordableKwh);

  if (actualKwh <= 0) {
    await prisma.meter.update({
      where: { id: meter.id },
      data: {
        lastUpdate: now,
        currentWatt: 0,
        tokenBalance: 0,
      },
    });
    return;
  }

  let cost = Math.floor(actualKwh * TARIF_PER_KWH);
  if (cost > meter.tokenBalance) {
    cost = meter.tokenBalance;
  }

  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  const endOfToday = new Date();
  endOfToday.setHours(23, 59, 59, 999);

  const todayUsage = await prisma.usageHistory.findFirst({
    where: {
      meterId: meter.id,
      usageDate: {
        gte: startOfToday,
        lte: endOfToday,
      },
    },
  });

  if (!todayUsage) {
    await prisma.usageHistory.create({
      data: {
        meterId: meter.id,
        usageDate: now,
        kwhUsed: actualKwh,
      },
    });
  } else {
    await prisma.usageHistory.update({
      where: { id: todayUsage.id },
      data: {
        kwhUsed: todayUsage.kwhUsed + actualKwh,
      },
    });
  }

  const newTokenBalance = meter.tokenBalance - cost;

  await prisma.meter.update({
    where: { id: meter.id },
    data: {
      currentKwh: meter.currentKwh + actualKwh,
      tokenBalance: newTokenBalance,
      lastUpdate: now,
      ...(newTokenBalance <= 0 ? { currentWatt: 0 } : {}),
    },
  });
}

export async function updateAllMetersEnergy() {
  const meters = await prisma.meter.findMany({
    select: { id: true },
  });

  for (const m of meters) {
    await updateMeterEnergyForMeter(m.id);
  }
}
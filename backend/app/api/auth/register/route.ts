import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import bcrypt from "bcryptjs";
import { updateMeterEnergyForMeter } from "@/lib/meterEnergy";

export async function POST(req: NextRequest) {
  try {
    let name, email, password;

    try {
      const body = await req.json();
      name = body.name;
      email = body.email;
      password = body.password;
    } catch {
      return NextResponse.json(
        { success: false, message: "Invalid JSON format" },
        { status: 400 }
      );
    }

    if (!name || !email || !password) {
      return NextResponse.json(
        { success: false, message: "Semua field wajib diisi" },
        { status: 400 }
      );
    }

    const exist = await prisma.user.findUnique({ where: { email } });
    if (exist) {
      return NextResponse.json(
        { success: false, message: "Email sudah digunakan" },
        { status: 409 }
      );
    }

    const hash = await bcrypt.hash(password, 10);

    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          name,
          email,
          passwordHash: hash,
          role: "USER",
        },
      });

      const meterNumber = `MT-${user.id.toString().padStart(6, "0")}`;

      const now = new Date();

      const meter = await tx.meter.create({
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

      return { user, meter };
    });

    await updateMeterEnergyForMeter(result.meter.id);

    const { user } = result;

    return NextResponse.json(
      {
        success: true,
        message: "Register berhasil",
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
        },
      },
      { status: 201 }
    );
  } catch (err) {
    console.error("[REGISTER] Error:", err);
    return NextResponse.json(
      { success: false, message: "Terjadi kesalahan server" },
      { status: 500 }
    );
  }
}
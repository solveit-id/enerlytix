import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import bcrypt from "bcryptjs";

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

    const user = await prisma.user.create({
      data: {
        name,
        email,
        passwordHash: hash,
        role: "USER",
      },
    });

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
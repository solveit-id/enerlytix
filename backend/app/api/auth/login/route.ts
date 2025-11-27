import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import bcrypt from "bcryptjs";   
import { createSession } from "@/lib/session";

export async function POST(req: NextRequest) {
  const start = Date.now();

  try {
    let email, password;

    try {
      const body = await req.json();
      email = body.email;
      password = body.password;
    } catch {
      return NextResponse.json(
        { success: false, message: "Invalid JSON body" },
        { status: 400 }
      );
    }

    if (!email || !password) {
      return NextResponse.json(
        { success: false, message: "email dan password wajib diisi" },
        { status: 400 }
      );
    }

    const t1 = Date.now();
    const user = await prisma.user.findUnique({ where: { email } });
    const t2 = Date.now();

    if (!user) {
      return NextResponse.json(
        { success: false, message: "Email atau password salah" },
        { status: 401 }
      );
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    const t3 = Date.now();

    if (!ok) {
      return NextResponse.json(
        { success: false, message: "Email atau password salah" },
        { status: 401 }
      );
    }

    const session = await createSession(user.id);

    console.log("[LOGIN] Done in", Date.now() - start, "ms | DB:", t2-t1, "ms | Bcrypt:", t3-t2, "ms");

    return NextResponse.json({
      success: true,
      message: "Login berhasil",
      data: {
        token: session.token,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
        },
      },
    });

  } catch (error) {
    console.error("[LOGIN] Error:", error);
    return NextResponse.json(
      { success: false, message: "Terjadi kesalahan server" },
      { status: 500 }
    );
  }
}
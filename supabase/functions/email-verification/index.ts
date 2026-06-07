// Supabase Edge Function: подтверждение email 6-значным кодом.
//
// Действия (POST JSON):
//   { "action": "send",   "email": "user@mail.ru" }
//       → генерирует код, сохраняет в email_codes, отправляет письмо по SMTP.
//   { "action": "verify", "email": "user@mail.ru", "code": "123456" }
//       → проверяет код (срок 10 минут, до 5 попыток). { verified: true|false }
//
// Секреты (Supabase → Project Settings → Edge Functions → Secrets):
//   SMTP_HOST   например smtp.yandex.ru (Яндекс) или smtp.mail.ru (Mail.ru)
//   SMTP_PORT   465 (SSL)
//   SMTP_USER   полный адрес почты-отправителя
//   SMTP_PASS   пароль приложения (НЕ обычный пароль аккаунта!)
//   SMTP_FROM   адрес в поле From (обычно = SMTP_USER)
//   SUPABASE_URL              (есть по умолчанию)
//   SUPABASE_SERVICE_ROLE_KEY (есть по умолчанию)
//
// Деплой:
//   supabase functions deploy email-verification --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CODE_TTL_MIN = 10;
const MAX_ATTEMPTS = 5;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function genCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function sendEmail(to: string, code: string) {
  const client = new SMTPClient({
    connection: {
      hostname: Deno.env.get("SMTP_HOST")!,
      port: Number(Deno.env.get("SMTP_PORT") ?? "465"),
      tls: true,
      auth: {
        username: Deno.env.get("SMTP_USER")!,
        password: Deno.env.get("SMTP_PASS")!,
      },
    },
  });

  const from = Deno.env.get("SMTP_FROM") ?? Deno.env.get("SMTP_USER")!;

  await client.send({
    from: `AI Service <${from}>`,
    to,
    subject: `Код подтверждения: ${code}`,
    content: `Ваш код подтверждения: ${code}\n\nКод действует ${CODE_TTL_MIN} минут.\nЕсли вы не регистрировались — проигнорируйте это письмо.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color:#1E293B;">Подтверждение email</h2>
        <p style="color:#475569;">Ваш код подтверждения для AI Service:</p>
        <div style="font-size: 34px; font-weight: 800; letter-spacing: 8px;
                    color:#2563EB; background:#EFF6FF; padding: 16px 0;
                    text-align:center; border-radius:12px; margin: 16px 0;">
          ${code}
        </div>
        <p style="color:#94A3B8; font-size:13px;">
          Код действует ${CODE_TTL_MIN} минут. Если вы не регистрировались —
          просто проигнорируйте это письмо.
        </p>
      </div>
    `,
  });

  await client.close();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { action, email, code } = await req.json();
    const mail = (email ?? "").toString().trim().toLowerCase();

    if (!mail || !mail.includes("@")) {
      return json({ error: "Некорректный email" }, 400);
    }

    // ── Отправка кода ────────────────────────────────────────────────
    if (action === "send") {
      const newCode = genCode();
      const expiresAt = new Date(
        Date.now() + CODE_TTL_MIN * 60 * 1000,
      ).toISOString();

      // Инвалидируем прежние коды этого email
      await supabase
        .from("email_codes")
        .update({ used: true })
        .eq("email", mail)
        .eq("used", false);

      const { error: insErr } = await supabase.from("email_codes").insert({
        email: mail,
        code: newCode,
        purpose: "registration",
        expires_at: expiresAt,
      });
      if (insErr) {
        return json({ error: "Не удалось сохранить код" }, 500);
      }

      try {
        await sendEmail(mail, newCode);
      } catch (e) {
        return json({ error: `Ошибка отправки письма: ${e}` }, 500);
      }

      return json({ ok: true });
    }

    // ── Проверка кода ────────────────────────────────────────────────
    if (action === "verify") {
      const inputCode = (code ?? "").toString().trim();
      if (inputCode.length !== 6) {
        return json({ verified: false, error: "Код должен быть из 6 цифр" });
      }

      const { data: rows } = await supabase
        .from("email_codes")
        .select("*")
        .eq("email", mail)
        .eq("used", false)
        .order("created_at", { ascending: false })
        .limit(1);

      const row = rows?.[0];
      if (!row) {
        return json({ verified: false, error: "Код не найден, запросите новый" });
      }
      if (new Date(row.expires_at).getTime() < Date.now()) {
        return json({ verified: false, error: "Код истёк, запросите новый" });
      }
      if (row.attempts >= MAX_ATTEMPTS) {
        return json({ verified: false, error: "Слишком много попыток, запросите новый код" });
      }

      if (row.code !== inputCode) {
        await supabase
          .from("email_codes")
          .update({ attempts: row.attempts + 1 })
          .eq("id", row.id);
        return json({ verified: false, error: "Неверный код" });
      }

      // Успех — помечаем код использованным
      await supabase
        .from("email_codes")
        .update({ used: true })
        .eq("id", row.id);

      // Помечаем профиль (если уже создан)
      await supabase
        .from("user_profiles")
        .update({ email_verified: true })
        .eq("email", mail);

      return json({ verified: true });
    }

    return json({ error: "Неизвестное действие" }, 400);
  } catch (e) {
    return json({ error: `Внутренняя ошибка: ${e}` }, 500);
  }
});

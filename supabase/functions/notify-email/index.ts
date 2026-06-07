// Supabase Edge Function: дублирование уведомлений на email.
//
// Вызывается триггером БД при вставке строки в notifications.
// Body (POST JSON): { user_id, title, message }
//   → находит email пользователя, проверяет подтверждённость и согласие,
//     отправляет письмо по тому же SMTP, что и коды подтверждения.
//
// Использует те же секреты SMTP_* что и email-verification.
//
// Деплой:
//   supabase functions deploy notify-email
//   (JWT-проверку можно оставить включённой — триггер шлёт anon-ключ)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sendEmail(to: string, title: string, message: string) {
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

  // Короткая тема — корректно отображается во всех клиентах
  const subject = title.length > 50 ? `${title.slice(0, 47)}…` : title;

  await client.send({
    from: `AI Service <${from}>`,
    to,
    subject: subject,
    content: `${title}\n\n${message}\n\n— AI Service`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
        <h2 style="color:#1E293B; font-size:18px;">${escapeHtml(title)}</h2>
        <p style="color:#475569; font-size:14px; line-height:1.5; white-space:pre-line;">${escapeHtml(message)}</p>
        <hr style="border:none; border-top:1px solid #E2E8F0; margin:16px 0;">
        <p style="color:#94A3B8; font-size:12px;">
          Это уведомление сервиса AI Service. Чтобы отключить письма —
          измените настройки в профиле.
        </p>
      </div>
    `,
  });
  await client.close();
}

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
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

    const { user_id, title, message } = await req.json();
    if (!user_id || !title) {
      return json({ error: "user_id и title обязательны" }, 400);
    }

    // Находим email пользователя и его настройки
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("email, email_verified, email_notifications")
      .eq("id", user_id)
      .maybeSingle();

    const email = profile?.email?.toString().trim();
    if (!email || !email.includes("@")) {
      return json({ skipped: "нет email" });
    }
    // Не шлём, если почта не подтверждена или пользователь отключил уведомления
    if (profile?.email_verified === false) {
      return json({ skipped: "email не подтверждён" });
    }
    if (profile?.email_notifications === false) {
      return json({ skipped: "уведомления отключены пользователем" });
    }

    try {
      await sendEmail(email, title.toString(), (message ?? "").toString());
    } catch (e) {
      return json({ error: `Ошибка отправки: ${e}` }, 500);
    }

    return json({ ok: true });
  } catch (e) {
    return json({ error: `Внутренняя ошибка: ${e}` }, 500);
  }
});

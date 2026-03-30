import { serve } from "https://deno.land/std/http/server.ts";
import { Resend } from "npm:resend";

const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);

// Required CORS headers
const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  try {
    const body = await req.json();
    const { contactEmail, userName, riskReason } = body;

    if (!contactEmail || !riskReason) {
      return new Response(
        JSON.stringify({ error: "Missing parameters (contactEmail, riskReason)" }),
        { status: 400, headers }
      );
    }

    const fullName = userName?.trim() || "A MindMate user";

    // Improved email message
    const htmlMessage = `
      <p>Hello,</p>
      <p>You are receiving this alert because <strong>${fullName}</strong> has added you as their trusted emergency contact.</p>
      <p><strong>Reason for alert:</strong> ${riskReason}</p>
      <p style="color:red;font-weight:bold;">⚠ Please check on them immediately.</p>
      <p>Thank you for being there for them.</p>
    `;

    const emailResponse = await resend.emails.send({
      from: "MindMate Alerts <onboarding@resend.dev>",
      to: contactEmail,
      subject: "🚨 MindMate Emergency Alert",
      html: htmlMessage,
    });

    console.log("Email sent:", emailResponse);

    return new Response(JSON.stringify({ success: true }), { status: 200, headers });
  } catch (error) {
    console.error("Error sending emergency email:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers });
  }
});

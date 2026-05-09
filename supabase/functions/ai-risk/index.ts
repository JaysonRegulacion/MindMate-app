import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("VALID_AI_KEY");
const MODEL = "gpt-4.1-mini";

serve(async (req) => {
  try {
    if (!OPENAI_API_KEY) {
      console.error("❌ OpenAI key missing!");
      return new Response(JSON.stringify({ riskScore: 0, riskReason: "Server misconfigured" }), { status: 500, headers: { "Content-Type": "application/json" } });
    }

    if (req.method !== "POST") {
      return new Response(JSON.stringify({ riskScore: 0, riskReason: "Only POST allowed" }), { status: 405, headers: { "Content-Type": "application/json" } });
    }

    const body = await req.json().catch(() => null);
    console.log("🧪 Incoming request body:", body);

    if (!body) {
      return new Response(JSON.stringify({ riskScore: 0, riskReason: "Invalid JSON body" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }

    const { userId, userName, moods = [], journals = [], chats = [] } = body;

    const systemPrompt = `You are a strict mental-health risk classifier for a wellness companion application.


      You will receive a JSON object with user context (moods, journals, chats, and a set of extracted pattern flags).
      Your job is to produce exactly one JSON object ONLY with two fields:
      - "riskScore": number (0-10)
      - "riskReason": complete short string (max 42 characters)

      Scoring rubric (use conservatively):
      0-2: Normal or mild stress — no cause for concern.
      3-5: Clear stress indicators (persistent low mood, overwhelmed, withdrawal, poor sleep, acute stressors).
      6-8: Depressive indicators (explicit hopelessness, repeated negative self-appraisals, emptiness, loneliness).
      9-10: Self-harm intent, repeated ideation, talk of wanting to disappear, suicidal planning, attempts, or imminent danger.

      Return ONLY the JSON object with no extra text, no backticks, no explanation.
    `;

    const contextForAI = {
      userId: userId ?? "unknown",
      userName: userName ?? "unknown",
      moods: Array.isArray(moods) ? moods.slice(-15) : [],
      journals: Array.isArray(journals) ? journals.slice(-10) : [],
      chats: Array.isArray(chats) ? chats.slice(-20) : [],
    };

    const aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `Context JSON: ${JSON.stringify(contextForAI)}` },
          { role: "user", content: "Respond ONLY with JSON." },
        ],
        max_tokens: 300,
        temperature: 0.7,
      }),
    });

    if (!aiRes.ok) {
      const text = await aiRes.text();
      console.error("❌ OpenAI API error:", aiRes.status, text);
      return new Response(JSON.stringify({ riskScore: 0, riskReason: "AI unavailable" }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    const aiData = await aiRes.json();
    const raw = aiData.choices?.[0]?.message?.content ?? "";
    console.log("🧪 AI raw response:", raw);

    let parsed;
    try {
      const jsonStart = raw.indexOf("{");
      const jsonText = jsonStart >= 0 ? raw.slice(jsonStart) : raw;
      parsed = JSON.parse(jsonText);
    } catch (err) {
      console.error("❌ Failed to parse AI output as JSON:", err, "raw:", raw);
      parsed = { riskScore: 0, riskReason: "AI output parse error" };
    }

    const riskScore = Math.max(0, Math.min(10, Number(parsed.riskScore || 0)));
    const riskReason = typeof parsed.riskReason === "string" ? parsed.riskReason : String(parsed.riskReason || "");

    console.log(`✅ Risk parsed -> score: ${riskScore}, reason: ${riskReason}`);

    return new Response(JSON.stringify({ riskScore, riskReason }), { headers: { "Content-Type": "application/json" } });

  } catch (e) {
    console.error("❌ Unexpected error in ai-risk:", e);
    return new Response(JSON.stringify({ riskScore: 0, riskReason: "internal error" }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});

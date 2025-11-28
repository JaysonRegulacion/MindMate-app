import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("VALID_AI_KEY")!;

serve(async (req) => {
  const headers = { "Content-Type": "application/json" };

  try {
    const body = await req.json();
    const journalText = body.message?.trim() ?? "";

    if (!journalText) {
      return new Response(JSON.stringify({ error: "Journal text is required" }), { status: 400, headers });
    }

    // Ask OpenAI to detect the mood
    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        messages: [
          {
            role: "system",
            content: "You are an assistant that detects the main mood of a journal entry in one word: Happy, Sad, Angry, Anxious, Calm, Excited, Neutral."
          },
          {
            role: "user",
            content: journalText,
          }
        ],
        max_tokens: 5,
      }),
    });

    const data = await resp.json();
    const mood = data.choices?.[0]?.message?.content?.trim() ?? "Neutral";

    return new Response(JSON.stringify({ mood }), { headers });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers });
  }
});

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("VALID_AI_KEY")!;

serve(async (req) => {
  const headers = { "Content-Type": "application/json" };

  try {
    const body = await req.json();
    const message = body.message?.trim() ?? "";

    if (!message) {
      return new Response(JSON.stringify({ error: "Message is required" }), { status: 400, headers });
    }

    // Detect if input is just an emoji/mood (no extra words)
    const emojiOnly = /^\p{Emoji}+$/u.test(message);

    const resp = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-nano",
        messages: [
          {
            role: "system",
            content: emojiOnly
              ? `You are MindMate, a supportive AI friend. 
                 If the user sends only an emoji/mood, respond with a **single short motivational tip or calming action**. 
                 Keep it under 1 sentences.`
              : `You are MindMate, a supportive AI friend for mental health. 
                 The user is explaining their feelings. Give a warm, encouraging, and slightly longer response (1-2 sentences).`
          },
          {
            role: "user",
            content: message,
          },
        ],
        max_tokens: emojiOnly ? 25 : 75,
      }),
    });

    const data = await resp.json();
    const reply =
      data.choices?.[0]?.message?.content?.trim() ??
      (emojiOnly ? "Take a deep breath and smile." : "I'm here to listen and support you.");

    return new Response(JSON.stringify({ reply }), { headers });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers });
  }
});

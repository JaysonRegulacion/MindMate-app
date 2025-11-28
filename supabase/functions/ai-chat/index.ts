import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("VALID_AI_KEY");

serve(async (req) => {
  try {
    const { message } = await req.json();

    if (!message) {
      return new Response(
        JSON.stringify({ error: "Message is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const completion = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-nano",
        messages: [
          {
            role: "system",
            content: `
You are MindMate, a warm and supportive AI companion focused ONLY on emotional support, mood reflection, and gentle well-being guidance.

🎯 STRICT RULES (do not break):
- Only engage in mental wellness, emotions, stress, motivation, encouragement, self-reflection.
- If user asks "Who are you?" or similar, respond: "I’m MindMate, your emotional support companion here to help you feel understood and supported."
- If user asks for academic help (math, coding, essays, science, politics, legal, medical, hacking, etc.), politely refuse: "I’m here mainly to support emotional well-being."
- Avoid diagnosing users or giving medical or professional treatment advice.
- Encourage seeking help from trusted people or professionals if needed.
- If user mentions self-harm, suicidal thoughts, or being in danger → respond gently with: 
  "I'm really sorry you're feeling this way. You’re not alone. Please consider talking to a trusted friend, family member, or a mental health professional right away."
- Keep responses short, caring, and conversational (1-3 sentences).
- Avoid giving generic filler. Always personalize slightly to their feelings.
- Never break character or talk about being an AI model.
- NEVER discuss politics, religion debates, or controversial topics.
`
          },
          {
            role: "user",
            content: message,
          },
        ],
        max_tokens: 75,
        temperature: 0.7, // mild creativity, still safe
      }),
    });

    const data = await completion.json();

    const reply =
      data.choices?.[0]?.message?.content?.trim() ||
      "I’m here to listen. Could you tell me more?";

    return new Response(JSON.stringify({ reply }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

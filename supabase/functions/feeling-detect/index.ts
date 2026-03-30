import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY"); // store key in env
const GROQ_URL = "https://api.groq.com/v1/llm/inference";

serve(async (req) => {
  try {
    const { journal } = await req.json();

    const payload = {
      model: "llama-3.1-8b-instant",
      prompt: `You are a mental health assistant. Analyze the journal and output JSON with:
        - universal_emotion
        - feelings (array)
        - risk_level (low, moderate, high)

        Journal:
        "${journal}"`,
      max_tokens: 200
    };

    const response = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    return new Response(JSON.stringify({ success: true, data }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ success: false, error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});

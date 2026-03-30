import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const HF_API_URL =
  "https://router.huggingface.co/hf-inference/models/j-hartmann/emotion-english-distilroberta-base";

// Minimum confidence to accept an emotion
const CONFIDENCE_THRESHOLD = 0.35;

// HuggingFace emotion → MindMate mood mapping
const emotionToMood: Record<string, { main: string; sub: string[] }> = {
  joy: {
    main: "Happy",
    sub: ["Content", "Excited", "Grateful"],
  },
  sadness: {
    main: "Sad",
    sub: ["Lonely", "Down", "Hopeless"],
  },
  anger: {
    main: "Angry",
    sub: ["Irritated", "Frustrated"],
  },
  fear: {
    main: "Fear",
    sub: ["Worried", "Overwhelmed"],
  },
  disgust: {
    main: "Disgust",
    sub: ["Uncomfortable", "Repulsed"],
  },
  surprise: {
    main: "Surprise",
    sub: ["Shocked", "Amazed"],
  },
  neutral: {
    main: "Neutral",
    sub: ["Calm", "Okay"],
  },
};

serve(async (req) => {
  try {
    const { text } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length < 3) {
      return new Response(
        JSON.stringify({ error: "Valid text is required" }),
        { status: 400 }
      );
    }

    // Call Hugging Face
    const hfResponse = await fetch(HF_API_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("HF_TOKEN")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ inputs: text }),
    });

    if (!hfResponse.ok) {
      const err = await hfResponse.text();
      return new Response(
        JSON.stringify({ error: "HuggingFace API error", details: err }),
        { status: 500 }
      );
    }

    let data = await hfResponse.json();

    // HF sometimes wraps results in an extra array
    if (Array.isArray(data) && Array.isArray(data[0])) {
      data = data[0];
    }

    // Sort emotions by confidence
    const sorted = data.sort(
      (a: any, b: any) => b.score - a.score
    );

    const topEmotion = sorted[0];
    const confidence = Number(topEmotion.score.toFixed(2));

    // Low confidence → unclear mood
    if (confidence < CONFIDENCE_THRESHOLD) {
      return new Response(
        JSON.stringify({
          primary_mood: "Unclear",
          confidence,
          suggestion: "How are you really feeling?",
          raw_emotions: sorted,
        }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    const mapping = emotionToMood[topEmotion.label] ?? {
      main: "Neutral",
      sub: ["Okay"],
    };

    return new Response(
      JSON.stringify({
        primary_mood: mapping.main,
        sub_moods: mapping.sub,
        emotion_source: topEmotion.label,
        confidence,
        raw_emotions: sorted,
      }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (e) {
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        message: String(e),
      }),
      { status: 500 }
    );
  }
});

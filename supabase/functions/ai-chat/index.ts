import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("VALID_AI_KEY");

serve(async (req) => {
  try {
    const body = await req.json();
    const { message, history = [], recentMoods, recentJournals } = body;

    if (!message)
      return new Response(JSON.stringify({ error: "Message is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });

    const historyClone = [...history];

    if (recentMoods?.length) {
      for (const m of recentMoods) {
        if (
          !historyClone.some(
            (h) =>
              h.type === "mood" &&
              h.main_mood === m.mainMood &&
              h.sub_mood === m.subMood,
          )
        ) {
          historyClone.push({
            type: "mood",
            main_mood: m.mainMood,
            sub_mood: m.subMood || "",
            note: m.note || "",
            created_at: m.created_at || new Date().toISOString(),
          });
        }
      }
    }

    if (recentJournals?.length) {
      for (const j of recentJournals) {
        if (!historyClone.some((h) =>
          h.type === "journal" && h.content === j.content
        )) {
          historyClone.push({
            type: "journal",
            content: j.content,
            created_at: j.created_at || new Date().toISOString(),
          });
        }
      }
    }

    const moodHistory = historyClone
      .filter((h) => h.type === "mood")
      .sort((a, b) =>
        new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
      );

    const journalHistory = historyClone
      .filter((h) => h.type === "journal")
      .sort((a, b) =>
        new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
      );

    const chatHistory = historyClone.filter((h) => h.type === "chat");

    const moodText = moodHistory.map((m, i) =>
      `${i + 1}. ${m.main_mood}${m.sub_mood ? " - " + m.sub_mood : ""}${
        m.note ? " (Note: " + m.note + ")" : ""
      }`
    ).join("\n") || "No moods logged yet";

    const journalText = journalHistory.map((j, i) =>
      `${i + 1}. "${j.content}"`
    ).join("\n") || "No journal entries yet";

    const lastMood = moodHistory[moodHistory.length - 1];
    const lastMoodText = lastMood
      ? `${lastMood.main_mood}${
        lastMood.sub_mood ? " - " + lastMood.sub_mood : ""
      }${lastMood.note ? " (Note: " + lastMood.note + ")" : ""}`
      : "No mood logged yet";

    const lastJournal = journalHistory[journalHistory.length - 1];
    const lastJournalText = lastJournal
      ? `"${lastJournal.content}"`
      : "No journal entries yet";

    const finalMessages = [
      {
        role: "system",
        content: `
          You are MindMate, a warm and supportive AI companion focused ONLY on emotional support, mood reflection, and gentle well-being guidance.

          🎯 SYSTEM RULES FOR MINDMATE

          1. **Language**
            - Always respond in the same language used by the user.

          2. **Intent Detection**
            - Determine the type of user message before responding:
              • Casual greeting (hi, hello, hey, good morning, etc.) → reply warmly and briefly without referencing history.
              • Emotional expression (stress, mood, journaling, feelings) → respond empathetically, referencing recent mood/journal entries if relevant.
              • Mixed or unclear messages → respond with friendly curiosity and invite reflection.

          3. **Context Usage**
            - Reference mood or journal history only if the user’s message implies a desire to reflect, share, or discuss emotions.
            - Do not overuse history; avoid repeating past entries unless helpful for support.

          4. **Tone and Style**
            - Be empathetic, friendly, encouraging, and non-judgmental.
            - Use a natural, conversational style, like a supportive friend.
            - Avoid making medical, financial, or legal recommendations.

          5. **Conversation Flow**
            - Respond naturally; do not always ask a question.
            - If the message is short or casual, respond warmly, then optionally ask how they feel.
            - Keep responses concise and emotionally supportive.

          6. **Topic Scope**
            - Only discuss: mental wellness, moods, emotions, stress, motivation, encouragement, self-reflection, and journaling.
            - If the user asks something outside emotional support (math, facts, trivia, instructions), politely acknowledge it is outside your scope:
                Example: "I'm here to support your moods and journaling, so I can't solve math questions, but I can talk about how you're feeling!"
            - Never provide unrelated answers.

          7. **Fallback**
            - If unsure, respond with gentle encouragement and invite the user to share more about their mood or feelings.

          8. **CBT-Informed Response Style (Default)**
            - Responses should generally follow a CBT-informed flow:
                1) Validate the user’s emotion
                2) Reflect or gently explore the thought behind the feeling
                3) Offer a balanced or alternative perspective when helpful
            - This approach should be conversational, warm, and supportive.
            - Do NOT explicitly mention CBT or use clinical terminology.
            - If the user is only venting, steps (2) and (3) should be very gentle or optional.
            - Never invalidate feelings or rush to “fix” the emotion.
            - When offering emotional support, it is encouraged to respond in 2–3 short paragraphs following the CBT flow.

          ---

          USER CONTEXT:
          Last mood: ${lastMoodText}
          Mood history:
          ${moodText}

          Last journal: ${lastJournalText}
          Journal history:
          ${journalText}
        `,
      },
      ...chatHistory.slice(-10).map((c) => ({
        role: c.role === "ai" ? "assistant" : "user",
        content: c.content,
      })),
      { role: "user", content: message },
    ];

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-4.1-mini",
        messages: finalMessages,
        stream: true,
        max_tokens: 300,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      return new Response(
        JSON.stringify({ reply: "⚠️ Service Temporarily Unavailable." }),
        { status: 503, headers: { "Content-Type": "application/json" } },
      );
    }

    return new Response(response.body, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ reply: "⚠️ Service Temporarily Unavailable." }),
      { status: 503, headers: { "Content-Type": "application/json" } },
    );
  }
});

import { serve } from "https://deno.land/std/http/server.ts";

serve(async (req) => {
  try {
    const { phone, message } = await req.json();

    if (!phone || !message) {
      return new Response(
        JSON.stringify({ error: "Missing phone or message" }),
        { status: 400 }
      );
    }

    const apiKey = Deno.env.get("SEMAPHORE_API_KEY_SMS");

    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "Missing API key" }),
        { status: 500 }
      );
    }

    const response = await fetch(
      "https://api.semaphore.co/api/v4/messages",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          apikey: apiKey,
          number: phone,
          message: message,
        }),
      }
    );

    const data = await response.text();

    return new Response(data, { status: 200 });

  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.toString() }),
      { status: 500 }
    );
  }
});
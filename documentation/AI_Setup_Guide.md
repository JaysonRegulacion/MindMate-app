AI Setup Guide

Purpose

This guide explains how to reconnect the AI services used by MindMate when deploying the system on a new Supabase project or database.

---

AI Services Used

1. OpenAI GPT-4.1 Mini

Purpose:

- Chat support
- Wellness recommendations
- Risk assessment
- Emotional reflection

Provider:
OpenAI

Website:
"https://platform.openai.com" (https://platform.openai.com)

---

2. Hugging Face Emotion Detection

Model:
j-hartmann/emotion-english-distilroberta-base

Purpose:

- Emotion detection
- Mood classification

Provider:
Hugging Face

Website:
"https://huggingface.co" (https://huggingface.co)

---

Required API Keys

The following API keys must be obtained:

Service| Required
OpenAI API Key| Yes
Hugging Face API Token| Yes

---

OpenAI Setup

Step 1

Create an OpenAI account.

Step 2

Generate an API Key.

Example:

sk-xxxxxxxxxxxxxxxx

Step 3

Open Supabase Dashboard.

Navigate to:

Project Settings
→ Edge Functions
→ Secrets

Create:

VALID_AI_KEY

Value:

YOUR_OPENAI_API_KEY

---

Hugging Face Setup

Step 1

Create a Hugging Face account.

Step 2

Generate an Access Token.

Step 3

Add the token to Supabase Secrets.

Secret Name:

HF_TOKEN

Value:

YOUR_HUGGINGFACE_TOKEN

---

Files That Use OpenAI

Location:

supabase/functions/chat/index.ts

Important Code:

const OPENAI_API_KEY =
  Deno.env.get("VALID_AI_KEY");

If the secret name changes, update this line.

---

Files That Use Hugging Face

Location:

supabase/functions/emotion-analysis/index.ts

Important Code:

Deno.env.get("HF_TOKEN")

If the secret name changes, update this line.

---

Deploying Edge Functions

After creating a new Supabase project:

Deploy the functions:

supabase functions deploy ai-chat

supabase functions deploy mood-detect

---

Flutter Configuration

If a new Supabase project is created:

Update:

lib/main.dart

Replace:

supabaseUrl
supabaseAnonKey

with the new project's credentials.

Example:

unawaited(Supabase.initialize(
  url: 'NEW_SUPABASE_URL',
  anonKey: 'NEW_SUPABASE_ANON_KEY',
));

---

Database Migration

Create a new Supabase project.

Run:

database/schema.sql

to recreate all tables.

---

Required Changes When Rebuilding

1. Create a new Supabase project.
2. Import database/schema.sql.
3. Update Supabase URL and Anon Key.
4. Create VALID_AI_KEY secret.
5. Create HF_TOKEN secret.
6. Deploy Edge Functions.
7. Build Flutter application.

---

Verification Checklist

✓ OpenAI key added

✓ Hugging Face token added

✓ Database schema imported

✓ Edge Functions deployed

✓ Flutter configuration updated

✓ Chat AI working

✓ Emotion Detection working

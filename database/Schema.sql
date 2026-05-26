Database Schema:

CREATE TABLE public.app_versions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  platform text NOT NULL,
  version_code integer NOT NULL,
  force_update boolean DEFAULT true,
  apk_url text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  latest_version text NOT NULL DEFAULT '1.0.0'::text,
  CONSTRAINT app_versions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.chat_messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role text NOT NULL,
  content text NOT NULL,
  created_at timestamp without time zone DEFAULT now(),
  mood_id uuid,
  journal_id uuid,
  CONSTRAINT chat_messages_pkey PRIMARY KEY (id),
  CONSTRAINT chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT chat_messages_mood_id_fkey FOREIGN KEY (mood_id) REFERENCES public.moods(id),
  CONSTRAINT chat_messages_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES public.journals(id),
  CONSTRAINT messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.emergency_contacts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  name text,
  contact_email text,
  relationship text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  contact_number text,
  CONSTRAINT emergency_contacts_pkey PRIMARY KEY (id),
  CONSTRAINT emergency_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.journals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  content text,
  created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'utc'::text),
  updated_at timestamp with time zone DEFAULT now(),
  mood text,
  CONSTRAINT journals_pkey PRIMARY KEY (id),
  CONSTRAINT journals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.moods (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  main_mood text NOT NULL CHECK (main_mood = ANY (ARRAY['Angry'::text, 'Disgust'::text, 'Fear'::text, 'Happy'::text, 'Neutral'::text, 'Sad'::text, 'Surprise'::text])),
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  tip text,
  sub_mood text,
  journal_id uuid UNIQUE,
  CONSTRAINT moods_pkey PRIMARY KEY (id),
  CONSTRAINT moods_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT moods_journal_fk FOREIGN KEY (journal_id) REFERENCES public.journals(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text UNIQUE,
  first_name text,
  last_name text,
  avatar_url text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_notifications (
  user_id uuid NOT NULL UNIQUE,
  last_sent timestamp with time zone NOT NULL DEFAULT now(),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT user_notifications_pkey PRIMARY KEY (user_id, id),
  CONSTRAINT user_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

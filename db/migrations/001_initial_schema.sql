-- 001_initial_schema.sql
-- German Notebook App: initial schema (PostgreSQL / Supabase)
--
-- SAFE TO RUN MORE THAN ONCE
--   * Every CREATE uses IF NOT EXISTS, so a second run changes nothing.
--   * schema_migrations records which versions have been applied. It is the
--     same idea as EF Core's __EFMigrationsHistory table.
--   * IF NOT EXISTS does NOT update a table that already exists. Never edit
--     this file after it has been applied anywhere; put changes in a new
--     file (002_something.sql) instead.

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Migration history
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migrations (
    version    text        PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 1. Auth: users, OTP challenges, sessions
-- ---------------------------------------------------------------------------

-- One row per person. Created on the first SUCCESSFUL OTP verification.
-- The CHECK makes the database reject an email that was not normalized
-- (lowercase, no surrounding spaces) by the app.
CREATE TABLE IF NOT EXISTS users (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    email         text        NOT NULL UNIQUE,
    created_at    timestamptz NOT NULL DEFAULT now(),
    last_login_at timestamptz,
    CONSTRAINT users_email_normalized CHECK (email = lower(btrim(email)))
);

-- Pending login codes, keyed by email (the user may not exist yet).
-- Only a HASH of the code is stored, never the code itself.
--   attempts    : wrong guesses so far; the app locks the code at a maximum
--   consumed_at : set when the code is used, so each code works once
CREATE TABLE IF NOT EXISTS otp_challenges (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    email       text        NOT NULL,
    code_hash   text        NOT NULL,
    expires_at  timestamptz NOT NULL,
    attempts    integer     NOT NULL DEFAULT 0,
    consumed_at timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT otp_email_normalized CHECK (email = lower(btrim(email))),
    CONSTRAINT otp_attempts_nonnegative CHECK (attempts >= 0)
);

-- Used to find the latest code for an email and to rate-limit requests.
CREATE INDEX IF NOT EXISTS ix_otp_challenges_email_created
    ON otp_challenges (email, created_at DESC);

-- Refresh tokens. Only a HASH of the token is stored.
--   family_id   : every token issued from one login shares a family; if an
--                 already-replaced token is ever reused, revoke the family
--   replaced_at : set when the token is rotated for a new one
--   revoked_at  : set on logout or when theft is suspected
CREATE TABLE IF NOT EXISTS sessions (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    family_id   uuid        NOT NULL,
    token_hash  text        NOT NULL UNIQUE,
    expires_at  timestamptz NOT NULL,
    replaced_at timestamptz,
    revoked_at  timestamptz,
    user_agent  text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_sessions_user_id   ON sessions (user_id);
CREATE INDEX IF NOT EXISTS ix_sessions_family_id ON sessions (family_id);

-- ---------------------------------------------------------------------------
-- 2. Words: shared dictionary, user's saved words, tags
-- ---------------------------------------------------------------------------

-- Shared AI results, one per normalized word, so each word is paid for once.
--   word_key     : normalized lookup key, e.g. 'guten morgen'
--                  (the app also collapses repeated inner spaces)
--   display_word : how it is shown, e.g. 'Guten Morgen'
--   examples     : JSON array, e.g. [{"de": "...", "en": "..."}]
CREATE TABLE IF NOT EXISTS dictionary_entries (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    word_key       text        NOT NULL UNIQUE,
    display_word   text        NOT NULL,
    part_of_speech text,
    article        text,
    plural         text,
    meaning        text        NOT NULL,
    explanation    text        NOT NULL,
    examples       jsonb       NOT NULL DEFAULT '[]'::jsonb,
    model          text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT entries_word_key_normalized CHECK (word_key = lower(btrim(word_key))),
    CONSTRAINT entries_article_valid CHECK (article IS NULL OR article IN ('der', 'die', 'das'))
);

-- A user's saved copy of a word.
--   meaning_override / explanation_override : the user's edits; NULL means
--   "use the shared entry's text".
CREATE TABLE IF NOT EXISTS user_words (
    id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    entry_id             uuid        NOT NULL REFERENCES dictionary_entries (id) ON DELETE RESTRICT,
    meaning_override     text,
    explanation_override text,
    notes                text,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_words_user_entry_unique UNIQUE (user_id, entry_id)
);

-- Situations such as "greetings" or "ordering food", private to each user.
CREATE TABLE IF NOT EXISTS tags (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name       text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tags_name_not_blank CHECK (btrim(name) <> '')
);

-- Tag names are unique per user, ignoring case ("Greetings" = "greetings").
CREATE UNIQUE INDEX IF NOT EXISTS ux_tags_user_name
    ON tags (user_id, lower(name));

-- Join table: many words per tag, many tags per word.
-- The primary key covers lookups by word; the extra index covers lookups by tag.
-- Note: nothing here stops a word from being linked to ANOTHER user's tag.
-- The API must check that both belong to the logged-in user.
CREATE TABLE IF NOT EXISTS user_word_tags (
    user_word_id uuid NOT NULL REFERENCES user_words (id) ON DELETE CASCADE,
    tag_id       uuid NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
    PRIMARY KEY (user_word_id, tag_id)
);

CREATE INDEX IF NOT EXISTS ix_user_word_tags_tag_id ON user_word_tags (tag_id);

-- ---------------------------------------------------------------------------
-- 3. Lock out Supabase's auto-generated data API
-- ---------------------------------------------------------------------------
-- Supabase exposes tables in the public schema over a REST API using a public
-- "anon" key. With RLS enabled and NO policies, that API can read nothing.
-- The .NET server connects with the database owner role, which skips RLS, so
-- the app is unaffected. Running ENABLE twice is harmless.
ALTER TABLE schema_migrations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_challenges      ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE dictionary_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_words          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags                ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_word_tags      ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 4. Record that this version has been applied
-- ---------------------------------------------------------------------------
INSERT INTO schema_migrations (version)
VALUES ('001_initial_schema')
ON CONFLICT (version) DO NOTHING;

COMMIT;

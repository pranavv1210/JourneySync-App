-- JourneySync SOS alert telemetry fields
-- Run this in Supabase SQL editor (project database).

alter table if exists public.rides
  add column if not exists alert_lat double precision,
  add column if not exists alert_lng double precision,
  add column if not exists alert_speed double precision,
  add column if not exists alert_signal text,
  add column if not exists alert_battery text,
  add column if not exists alert_elevation text,
  add column if not exists alert_by_avatar_url text;

# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some Oxlint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and Oxlint's TypeScript related rules in your project.

## Beta Signup Supabase Setup

The beta signup modal writes to `public.beta_applications` in Supabase.

The landing site reads `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` when they are provided by the host. If those variables are missing, it falls back to the same public Supabase URL and anon key used by the Flutter app so the beta form still works on deployed builds.

Before launch, apply the latest beta signup migration in Supabase:

```sql
supabase/migrations/20260702_beta_email_device_registration.sql
```

That migration creates or updates `public.beta_applications`, enables RLS, allows anonymous inserts, and adds duplicate protection for email and device IDs.

The signup flow also invokes the Supabase Edge Function at:

```text
supabase/functions/send-beta-welcome-email
```

Deploy that function and configure these Supabase secrets:

```text
BREVO_API_KEY=<Brevo transactional API key, not the SMTP password>
BREVO_SENDER_EMAIL=<verified Brevo sender email>
BREVO_SENDER_NAME=JourneySync
BREVO_REPLY_TO_EMAIL=journeysync.app@gmail.com
BETA_DOWNLOAD_URL=https://journeysyncrideapp.in/journeysync.apk
```

The welcome email subject is:

```text
You're in: download the JourneySync Beta
```

The email includes a welcome note, beta safety note, support contact, and the Android beta download link.

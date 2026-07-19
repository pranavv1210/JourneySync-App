/// <reference lib="deno.ns" />

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const defaultDownloadUrl = 'https://journeysyncrideapp.in/journeysync.apk';
const defaultDownloadPageUrl = 'https://journeysyncrideapp.in/beta/download';
const defaultIosBetaUrl = 'https://journeysyncrideapp.in/beta/download';

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function isValidEmail(value: unknown) {
  return typeof value === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function normalizePlatform(value: unknown) {
  return value === 'ios' ? 'ios' : 'android';
}

function buildEmailHtml(
  downloadUrl: string,
  downloadPageUrl: string,
  iosBetaUrl: string,
  platform: 'android' | 'ios',
) {
  const isIos = platform === 'ios';
  const ctaUrl = isIos ? iosBetaUrl : downloadPageUrl;
  const ctaLabel = isIos ? 'Open iOS Beta Status' : 'Open Beta Download Page';
  const platformCopy = isIos
    ? 'You selected iOS. JourneySync iOS testing will be distributed through TestFlight once the Apple build is ready. We saved your iOS interest and will send TestFlight access when it opens.'
    : 'You selected Android. Open the beta download page below, then tap Download APK. This keeps the app download on JourneySync\'s own domain instead of an email tracking redirect.';
  const fallbackCopy = isIos
    ? 'You can also check the beta page for the latest Android download and iOS TestFlight status.'
    : 'If the APK does not download from Gmail, open the beta page in Chrome and use the Download Android Beta button near the bottom of the page.';

  return `<!doctype html>
<html>
  <body style="margin:0;background:#f4efea;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#1f2937;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4efea;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;overflow:hidden;border:1px solid #eadfd2;">
            <tr>
              <td style="padding:28px 28px 12px;">
                <p style="margin:0 0 10px;color:#db7706;font-size:12px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;">JourneySync Beta</p>
                <h1 style="margin:0;color:#111827;font-size:28px;line-height:1.12;">You're in. Welcome to the ride.</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 28px 0;color:#4b5563;font-size:16px;line-height:1.65;">
                <p style="margin:0 0 16px;">Thanks for joining the JourneySync beta. You're helping shape a group riding app built around live coordination, Ride Radar, shared ride context, and safety-first workflows.</p>
                <p style="margin:0 0 22px;">${platformCopy}</p>
                <p style="margin:0 0 28px;">
                  <a href="${ctaUrl}" style="display:inline-block;background:#b45f04;color:#ffffff;text-decoration:none;font-weight:800;border-radius:12px;padding:14px 20px;">${ctaLabel}</a>
                </p>
                <p style="margin:0 0 16px;font-size:14px;color:#6b7280;">${fallbackCopy}</p>
                <p style="margin:0 0 24px;word-break:break-all;font-size:14px;color:#b45f04;">
                  journeysyncrideapp.in/beta/download
                </p>
              </td>
            </tr>
            <tr>
              <td style="background:#171717;color:#d1d5db;padding:22px 28px;font-size:13px;line-height:1.6;">
                <p style="margin:0 0 8px;font-weight:800;color:#ffffff;">Beta note</p>
                <p style="margin:0;">This is an early test build. Use it only when you are comfortable testing beta software, and keep normal road safety, emergency services, and rider judgment first.</p>
                <p style="margin:16px 0 0;">Questions or feedback? Reply to this email or contact journeysync.app@gmail.com.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildEmailText(
  downloadUrl: string,
  downloadPageUrl: string,
  iosBetaUrl: string,
  platform: 'android' | 'ios',
) {
  const isIos = platform === 'ios';
  return [
    "You're in. Welcome to the JourneySync Beta.",
    '',
    "Thanks for joining the JourneySync beta. You're helping shape a group riding app built around live coordination, Ride Radar, shared ride context, and safety-first workflows.",
    '',
    isIos
      ? 'You selected iOS. TestFlight access will be sent when the iOS beta opens:'
      : 'You selected Android. Open the beta download page, then tap Download APK:',
    isIos ? iosBetaUrl : downloadPageUrl,
    '',
    isIos
      ? 'You can also check this page for the latest Android download and iOS beta status:'
      : 'If the APK does not download from Gmail, open this page in Chrome and use the Download Android Beta button near the bottom:',
    downloadPageUrl.replace(/^https?:\/\//, ''),
    '',
    'Beta note: This is an early test build. Use it only when you are comfortable testing beta software, and keep normal road safety, emergency services, and rider judgment first.',
    '',
    'Questions or feedback? Reply to this email or contact journeysync.app@gmail.com.',
  ].join('\n');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const brevoApiKey = Deno.env.get('BREVO_API_KEY');
  if (!brevoApiKey) {
    return jsonResponse({ error: 'BREVO_API_KEY is not configured' }, 500);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400);
  }

  const email = typeof payload.email === 'string' ? payload.email.trim().toLowerCase() : '';
  if (!isValidEmail(email)) {
    return jsonResponse({ error: 'Valid email is required' }, 400);
  }
  const platform = normalizePlatform(payload.platform);

  const downloadUrl = Deno.env.get('BETA_DOWNLOAD_URL') || defaultDownloadUrl;
  const downloadPageUrl =
    Deno.env.get('BETA_DOWNLOAD_PAGE_URL') || defaultDownloadPageUrl;
  const iosBetaUrl = Deno.env.get('IOS_BETA_URL') || defaultIosBetaUrl;
  const senderEmail = Deno.env.get('BREVO_SENDER_EMAIL') || 'journeysync.app@gmail.com';
  const senderName = Deno.env.get('BREVO_SENDER_NAME') || 'JourneySync';
  const replyToEmail = Deno.env.get('BREVO_REPLY_TO_EMAIL') || 'journeysync.app@gmail.com';

  const brevoResponse = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      accept: 'application/json',
      'api-key': brevoApiKey,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      sender: {
        name: senderName,
        email: senderEmail,
      },
      to: [{ email }],
      replyTo: {
        email: replyToEmail,
        name: senderName,
      },
      subject: platform === 'ios'
        ? "You're in: JourneySync iOS beta access"
        : "You're in: download the JourneySync Android Beta",
      htmlContent: buildEmailHtml(downloadUrl, downloadPageUrl, iosBetaUrl, platform),
      textContent: buildEmailText(downloadUrl, downloadPageUrl, iosBetaUrl, platform),
      tags: ['beta-signup', platform],
    }),
  });

  if (!brevoResponse.ok) {
    const details = await brevoResponse.text();
    console.error('Brevo email send failed', brevoResponse.status, details);
    return jsonResponse({ error: 'Email send failed' }, 502);
  }

  const result = await brevoResponse.json();
  return jsonResponse({ ok: true, messageId: result.messageId ?? null });
});

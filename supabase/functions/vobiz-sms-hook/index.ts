// Supabase Auth Hook: Custom SMS Provider → Vobiz Voice OTP
//
// Deploy:  supabase functions deploy vobiz-sms-hook
// Secrets:
//   supabase secrets set VOBZ_AUTH_ID=MA_XXXXXX VOBZ_AUTH_TOKEN=xxx \
//     VOBZ_FROM=+919876543210 \
//     VOBZ_ANSWER_URL=https://<project-ref>.supabase.co/functions/v1/vobiz-sms-hook
// Enable:  Supabase Dashboard → Auth → Hooks → SMS Provider → Custom
//          Hook URI: https://<project-ref>.supabase.co/functions/v1/vobiz-sms-hook
//
// Flow:
//   signInWithOtp(phone:) → Supabase Auth generates OTP → fires this hook
//   → this hook places a Vobiz voice call to the user's number
//   → when answered, Vobiz calls answer_url (?token=...) → returns Voice XML
//   → TTS speaks the OTP → user enters it → verifyOTP() validates.

const VOBZ_API = 'https://api.vobiz.ai/api/v1';
const VOBZ_AUTH_ID = Deno.env.get('VOBZ_AUTH_ID') ?? '';
const VOBZ_AUTH_TOKEN = Deno.env.get('VOBZ_AUTH_TOKEN') ?? '';
const VOBZ_FROM = Deno.env.get('VOBZ_FROM') ?? '';
const VOBZ_ANSWER_URL = Deno.env.get('VOBZ_ANSWER_URL') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function xmlResponse(body: string): Response {
  return new Response(body, {
    headers: { 'Content-Type': 'text/xml', ...corsHeaders },
  });
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

function buildVoiceXml(token: string): string {
  const digits = token.split('').join('. ');
  return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Speak voice="WOMAN" language="en-US">Your Soulful Bhakti verification code is. ${digits}. Repeat. ${digits}.</Speak>
</Response>`;
}

async function placeVobizCall(phone: string, answerUrl: string): Promise<boolean> {
  const body = {
    from: VOBZ_FROM,
    to: phone.replace('+', ''),
    answer_url: answerUrl,
    answer_method: 'POST',
    time_limit: '60',
    caller_name: 'SoulfulBhakti',
  };

  const res = await fetch(`${VOBZ_API}/Account/${VOBZ_AUTH_ID}/Call/`, {
    method: 'POST',
    headers: {
      'X-Auth-ID': VOBZ_AUTH_ID,
      'X-Auth-Token': VOBZ_AUTH_TOKEN,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  console.log('Vobiz call response', res.status, await res.text());
  return res.ok;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method === 'POST') {
    const url = new URL(req.url);

    // Path 1: Vobiz answer_url callback — Vobiz posts here when user answers.
    // The token was embedded in the query string when the call was placed.
    const queryToken = url.searchParams.get('token');
    if (queryToken) {
      return xmlResponse(buildVoiceXml(queryToken));
    }

    // Path 2: Supabase Auth Hook invocation with { phone, token, type }.
    try {
      const body = await req.json();
      const phone = body.phone as string | undefined;
      const token = body.token as string | undefined;

      if (!phone || !token) {
        return jsonResponse(400, { error: 'phone and token are required' });
      }

      const answerUrl = `${VOBZ_ANSWER_URL}?token=${encodeURIComponent(token)}`;
      const sent = await placeVobizCall(phone, answerUrl);

      return sent
        ? jsonResponse(200, { success: true })
        : jsonResponse(500, { error: 'Vobiz call failed' });
    } catch (e) {
      console.error('hook error', e);
      return jsonResponse(500, { error: String(e) });
    }
  }

  return jsonResponse(405, { error: 'Method not allowed' });
});

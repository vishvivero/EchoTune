// Polar.sh Webhook Handler → Supabase Edge Function
// Handles: license key activation from Polar checkout
// Deploy: supabase functions deploy polar-webhook
//
// Set secrets:
//   supabase secrets set POLAR_WEBHOOK_SECRET=<your-webhook-secret>

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const POLAR_WEBHOOK_SECRET = Deno.env.get("POLAR_WEBHOOK_SECRET") || "";

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body = await req.json();
    const event = body.type || body.event;

    console.log(`Polar webhook received: ${event}`);

    // Handle license key granted (checkout completed)
    if (
      event === "checkout.created" ||
      event === "order.created" ||
      event === "benefit.granted"
    ) {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

      // Extract customer info from various Polar event shapes
      const customer =
        body.data?.customer || body.data?.order?.customer || {};
      const email = customer.email || body.data?.customer_email;

      if (!email) {
        console.log("No email in webhook payload, skipping");
        return new Response(JSON.stringify({ ok: true, skipped: true }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      // Extract license key if present
      const licenseKey =
        body.data?.properties?.license_key ||
        body.data?.benefit?.properties?.license_key ||
        null;

      // Extract referral code from checkout metadata/custom fields
      const referredBy =
        body.data?.metadata?.referral_code ||
        body.data?.custom_field_data?.referral_code ||
        null;

      // Extract expiry
      const expiresAt =
        body.data?.properties?.expires_at ||
        body.data?.benefit?.properties?.expires_at ||
        null;

      console.log(
        `Registering user: ${email}, key: ${licenseKey ? "***" : "none"}, referred_by: ${referredBy || "none"}`
      );

      const { data, error } = await supabase.rpc("register_beta_user", {
        p_email: email,
        p_polar_license_key: licenseKey,
        p_polar_customer_id: customer.id || null,
        p_referred_by: referredBy,
        p_license_expires_at: expiresAt,
      });

      if (error) {
        console.error("register_beta_user error:", error);
        return new Response(JSON.stringify({ ok: false, error: error.message }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }

      console.log("User registered:", JSON.stringify(data));

      return new Response(JSON.stringify({ ok: true, data }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Acknowledge other events
    return new Response(JSON.stringify({ ok: true, event, handled: false }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Webhook error:", err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

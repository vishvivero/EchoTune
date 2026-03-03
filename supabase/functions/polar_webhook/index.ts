import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

interface PolarWebhookPayload {
  type: string;
  data: {
    id?: string;
    customer_email?: string;
    product_id?: string;
    subscription_id?: string;
    [key: string]: any;
  };
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
const polarSecret = Deno.env.get("POLAR_WEBHOOK_SECRET") || "";

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Verify Polar webhook signature (HMAC-SHA256)
async function verifyPolarSignature(
  payload: string,
  signature: string
): Promise<boolean> {
  try {
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(polarSecret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const payloadSignature = await crypto.subtle.sign(
      "HMAC",
      key,
      encoder.encode(payload)
    );
    const payloadSignatureHex = Array.from(new Uint8Array(payloadSignature))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    return payloadSignatureHex === signature;
  } catch (e) {
    console.error("Signature verification error:", e);
    return false;
  }
}

serve(async (req: Request) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    });
  }

  try {
    const signature = req.headers.get("x-polar-signature") || "";
    const rawBody = await req.text();
    const payload: PolarWebhookPayload = JSON.parse(rawBody);

    // Verify signature
    if (!verifyPolarSignature(rawBody, signature)) {
      console.warn("Invalid Polar webhook signature");
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 401,
      });
    }

    console.log(`Processing Polar webhook: ${payload.type}`);

    // Handle subscription checkout completed
    if (payload.type === "subscription.checkout.completed") {
      const customerEmail = payload.data.customer_email;
      const customerId = payload.data.id;
      const subscriptionId = payload.data.subscription_id;

      if (!customerEmail || !customerId) {
        return new Response(
          JSON.stringify({ error: "Missing required fields" }),
          { status: 400 }
        );
      }

      // Check if user exists in beta_users
      const { data: existingUser } = await supabase
        .from("beta_users")
        .select("id")
        .eq("email", customerEmail)
        .single();

      if (!existingUser) {
        // User is new, create beta_users entry with initial license
        const { data: newUser, error: insertError } = await supabase
          .from("beta_users")
          .insert({
            email: customerEmail,
            polar_customer_id: customerId,
            referral_code: `ECHO-${Date.now().toString(36).toUpperCase()}`,
            license_type: "beta",
            license_expires_at: new Date(
              Date.now() + 90 * 24 * 60 * 60 * 1000
            ).toISOString(), // 3 months
          })
          .select("id")
          .single();

        if (insertError) {
          console.error("Error creating new user:", insertError);
          return new Response(
            JSON.stringify({ error: "User creation failed" }),
            { status: 500 }
          );
        }

        console.log(`New user created: ${customerEmail} (${newUser.id})`);
      } else {
        // Existing user: update polar_customer_id and extend license
        const { error: updateError } = await supabase
          .from("beta_users")
          .update({
            polar_customer_id: customerId,
            license_expires_at: new Date(
              Date.now() + 365 * 24 * 60 * 60 * 1000
            ).toISOString(), // 1 year for paid
          })
          .eq("id", existingUser.id);

        if (updateError) {
          console.error("Error updating user:", updateError);
          return new Response(
            JSON.stringify({ error: "User update failed" }),
            { status: 500 }
          );
        }

        console.log(`User upgraded: ${customerEmail}`);
      }
    }

    // Handle referral completion via custom meta
    if (payload.type === "subscription.checkout.completed") {
      const customerEmail = payload.data.customer_email;
      const customMetadata = payload.data.metadata || {};
      const referralCode = customMetadata.referral_code;

      if (referralCode && customerEmail) {
        // Call complete_referral RPC
        const { data, error } = await supabase.rpc("complete_referral", {
          referral_code: referralCode,
          new_user_email: customerEmail,
          polar_customer_id: payload.data.id,
        });

        if (error) {
          console.error("Referral completion error:", error);
        } else {
          console.log(`Referral completed: ${referralCode} → ${customerEmail}`);
        }
      }
    }

    // Handle subscription upgrade/downgrade
    if (
      payload.type === "subscription.updated" ||
      payload.type === "subscription.created"
    ) {
      const customerEmail = payload.data.customer_email;
      if (customerEmail) {
        // Update license expiry based on new subscription status
        const { error } = await supabase
          .from("beta_users")
          .update({
            license_expires_at: new Date(
              Date.now() + 365 * 24 * 60 * 60 * 1000
            ).toISOString(),
          })
          .eq("email", customerEmail);

        if (error) {
          console.error("Error updating subscription:", error);
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 }
    );
  }
});

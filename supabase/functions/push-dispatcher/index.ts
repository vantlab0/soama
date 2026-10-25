// ============================================================================
// SOAMA MARKETPLACE: PUSH NOTIFICATION DISPATCHER EDGE FUNCTION
// Path: supabase/functions/push-dispatcher/index.ts
// Description: Secure, server-side push notification dispatcher that reads
//              pending items from push_notification_queue, sends to FCM/APNs,
//              cleans up stale/unregistered tokens, and updates status.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") ?? "";

serve(async (req: Request) => {
  // CORS check
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Fetch pending notifications from queue (up to 50 at a time)
    const { data: queueItems, error: queueError } = await supabase
      .from("push_notification_queue")
      .select(`
        id,
        notification_id,
        recipient_id,
        title,
        body,
        payload,
        retry_count
      `)
      .eq("status", "pending")
      .lt("retry_count", 3)
      .limit(50);

    if (queueError) {
      throw new Error(`Failed to read push queue: ${queueError.message}`);
    }

    if (!queueItems || queueItems.length === 0) {
      return new Response(JSON.stringify({ status: "idle", message: "No pending push notifications." }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const results = [];

    for (const item of queueItems) {
      // Mark as processing
      await supabase
        .from("push_notification_queue")
        .update({ status: "processing" })
        .eq("id", item.id);

      // Get active device tokens for recipient
      const { data: tokens, error: tokenError } = await supabase
        .from("user_device_tokens")
        .select("id, token, platform")
        .eq("user_id", item.recipient_id)
        .eq("is_active", true);

      if (tokenError || !tokens || tokens.length === 0) {
        // No tokens registered for user; mark completed
        await supabase
          .from("push_notification_queue")
          .update({
            status: "sent",
            processed_at: new Date().toISOString(),
            error_message: "No active device tokens found for recipient",
          })
          .eq("id", item.id);
        continue;
      }

      let allSucceeded = true;
      const invalidTokenIds: string[] = [];

      for (const t of tokens) {
        if (!FCM_SERVER_KEY) {
          // If FCM credentials are not configured in environment, log safely without failing silently
          console.warn(`[PushDispatcher] FCM_SERVER_KEY not configured. Simulated delivery for token: ${t.token.substring(0, 8)}...`);
          continue;
        }

        try {
          // Send to FCM HTTP Legacy or v1
          const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `key=${FCM_SERVER_KEY}`,
            },
            body: JSON.stringify({
              to: t.token,
              notification: {
                title: item.title,
                body: item.body,
                sound: "default",
              },
              data: item.payload,
              priority: "high",
            }),
          });

          const fcmJson = await fcmResponse.json();

          // Check if token is invalid or expired
          if (fcmJson.failure && fcmJson.results && fcmJson.results.length > 0) {
            const error = fcmJson.results[0].error;
            if (error === "NotRegistered" || error === "InvalidRegistration") {
              invalidTokenIds.push(t.id);
            } else {
              allSucceeded = false;
            }
          }
        } catch (dispatchErr) {
          console.error(`[PushDispatcher] Dispatch error for token ${t.id}:`, dispatchErr);
          allSucceeded = false;
        }
      }

      // Cleanup invalid tokens if any were discovered
      if (invalidTokenIds.length > 0) {
        await supabase
          .from("user_device_tokens")
          .update({ is_active: false, updated_at: new Date().toISOString() })
          .in("id", invalidTokenIds);
      }

      // Update queue item state
      await supabase
        .from("push_notification_queue")
        .update({
          status: allSucceeded ? "sent" : "failed",
          retry_count: item.retry_count + (allSucceeded ? 0 : 1),
          processed_at: new Date().toISOString(),
        })
        .eq("id", item.id);

      results.push({ queue_id: item.id, status: allSucceeded ? "sent" : "failed" });
    }

    return new Response(JSON.stringify({ status: "success", processed: results.length, details: results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    console.error("[PushDispatcher] Top-level handler failure:", err);
    return new Response(JSON.stringify({ status: "error", error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

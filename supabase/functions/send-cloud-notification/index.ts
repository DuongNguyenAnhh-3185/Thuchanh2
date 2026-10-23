import { createClient } from "npm:@supabase/supabase-js@2";
import {
  createRemoteJWKSet,
  importPKCS8,
  jwtVerify,
  SignJWT,
} from "npm:jose@5";

const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const firebaseIssuer = `https://securetoken.google.com/${firebaseProjectId}`;
const firebaseKeys = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const authorization = request.headers.get("Authorization") ?? "";
    const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
    if (!token || !firebaseProjectId) {
      return json({ error: "Firebase authorization is required" }, 401);
    }

    const { payload } = await jwtVerify(token, firebaseKeys, {
      issuer: firebaseIssuer,
      audience: firebaseProjectId,
      algorithms: ["RS256"],
    });
    if (
      typeof payload.sub !== "string" ||
      payload.email_verified !== true
    ) {
      return json({ error: "Verified Firebase user is required" }, 401);
    }

    const body = await request.json();
    const event = body.event;
    const resourceId = body.resource_id;
    const recipientId = body.recipient_id;
    if (typeof resourceId !== "string") {
      return json({ error: "resource_id is required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Supabase function credentials are missing");
    }
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let targetUserId: string;
    let title: string;
    let message: string;
    let dispatchKey: string;

    if (event === "borrow_requested" || event === "borrow_responded") {
      const { data: borrowRequest, error } = await admin
        .from("borrow_requests")
        .select("id, owner_id, requester_id, status, document_title")
        .eq("id", resourceId)
        .single();
      if (error || !borrowRequest) {
        return json({ error: "Borrow request not found" }, 404);
      }
      if (event === "borrow_requested") {
        if (
          borrowRequest.requester_id !== payload.sub ||
          borrowRequest.status !== "pending"
        ) {
          return json({ error: "Borrow request is not owned by caller" }, 403);
        }
        targetUserId = borrowRequest.owner_id;
        title = "Yêu cầu mượn tài liệu";
        message = `Có yêu cầu mượn “${borrowRequest.document_title}”.`;
        dispatchKey = `borrow_requested:${resourceId}`;
      } else {
        if (
          borrowRequest.owner_id !== payload.sub ||
          !["approved", "rejected"].includes(borrowRequest.status)
        ) {
          return json({ error: "Borrow request response is not authorized" }, 403);
        }
        targetUserId = borrowRequest.requester_id;
        title = borrowRequest.status === "approved"
          ? "Yêu cầu mượn được chấp nhận"
          : "Yêu cầu mượn bị từ chối";
        message = `Yêu cầu cho “${borrowRequest.document_title}” đã được ${
          borrowRequest.status === "approved" ? "chấp nhận" : "từ chối"
        }.`;
        dispatchKey = `borrow_responded:${resourceId}:${borrowRequest.status}`;
      }
    } else if (event === "document_shared") {
      if (typeof recipientId !== "string" || recipientId === payload.sub) {
        return json({ error: "recipient_id is invalid" }, 400);
      }
      const { data: document, error: documentError } = await admin
        .from("documents")
        .select("id, owner_id, title")
        .eq("id", resourceId)
        .single();
      if (documentError || !document) {
        return json({ error: "Document not found" }, 404);
      }
      const { data: permission, error: permissionError } = await admin
        .from("permissions")
        .select("user_id, granted_by, updated_at")
        .eq("document_id", resourceId)
        .eq("user_id", recipientId)
        .single();
      if (
        permissionError ||
        !permission ||
        permission.granted_by !== payload.sub ||
        document.owner_id !== payload.sub
      ) {
        return json({ error: "Document share is not authorized" }, 403);
      }
      targetUserId = recipientId;
      title = "Tài liệu được chia sẻ";
      message = `Bạn được chia sẻ tài liệu “${document.title}”.`;
      dispatchKey = `document_shared:${resourceId}:${recipientId}:${permission.updated_at}`;
    } else {
      return json({ error: "Unsupported notification event" }, 400);
    }

    const { data: devices, error: deviceError } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", targetUserId);
    if (deviceError) throw deviceError;
    if (!devices?.length) return json({ sent: 0 }, 200);

    const { error: dispatchError } = await admin
      .from("notification_dispatches")
      .insert({ dispatch_key: dispatchKey });
    if (dispatchError?.code === "23505") {
      return json({ sent: 0, duplicate: true }, 200);
    }
    if (dispatchError) throw dispatchError;

    try {
    const serviceAccountValue = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountValue) {
      throw new Error("Firebase service account secret is missing");
    }
    const serviceAccount = JSON.parse(serviceAccountValue);
    if (
      serviceAccount.project_id !== firebaseProjectId ||
      typeof serviceAccount.client_email !== "string" ||
      typeof serviceAccount.private_key !== "string"
    ) {
      throw new Error("Firebase service account is invalid");
    }

    const accessToken = await getGoogleAccessToken(serviceAccount);
    const responses = await Promise.all(
      devices.map(({ token: deviceToken }) =>
        fetch(
          `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: deviceToken,
                notification: { title, body: message },
                data: { event, resource_id: resourceId },
              },
            }),
          },
        )
      ),
    );
    const failures = await Promise.all(
      responses
        .filter((response) => !response.ok)
        .map(async (response) => `${response.status}: ${await response.text()}`),
    );
    if (failures.length > 0) {
      throw new Error(`FCM delivery failed for ${failures.length} device(s)`);
    }
    return json({ sent: responses.length }, 200);
    } catch (error) {
      const { error: cleanupError } = await admin
        .from("notification_dispatches")
        .delete()
        .eq("dispatch_key", dispatchKey);
      if (cleanupError) {
        console.error("Failed to release notification idempotency key", cleanupError);
      }
      throw error;
    }
  } catch (error) {
    console.error("Cloud notification delivery failed", error);
    return json({ error: "Cloud notification delivery failed" }, 500);
  }
});

async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const tokenUrl = "https://oauth2.googleapis.com/token";
  const privateKey = await importPKCS8(
    serviceAccount.private_key,
    "RS256",
  );
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience(tokenUrl)
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);

  const response = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google OAuth token request failed: ${response.status}`);
  }
  const result = await response.json();
  if (typeof result.access_token !== "string") {
    throw new Error("Google OAuth response did not include an access token");
  }
  return result.access_token;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

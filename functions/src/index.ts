import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();

export const sendNotification = onCall(async (request) => {
  const { token, title, body } = request.data;

  // Ensure request.auth context exists
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated.",
    );
  }

  if (!token) {
    throw new HttpsError("invalid-argument", "FCM token is required.");
  }

  if (!title || !body) {
    throw new HttpsError("invalid-argument", "Title and body are required.");
  }

  const message = {
    token: token,

    notification: {
      title: title,
      body: body,
    },

    data: {
      type: "general",
    },
  };

  try {
    const response = await getMessaging().send(message);

    return {
      success: true,
      messageId: response,
    };
  } catch (error) {
    console.error("FCM error:", error);

    throw new HttpsError("internal", "Failed to send notification.");
  }
});

import { initializeApp } from "firebase-admin/app";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import OpenAI from "openai";

initializeApp();

const openAIKey = defineSecret("OPENAI_API_KEY");
const defaultModel = defineString("OPENAI_MODEL", {
  default: "gpt-5.4"
});

const SYSTEM_PROMPT = [
  "You are Forma Coach, a training and recovery assistant inside a health app.",
  "Use only the health context and conversation history provided in the request.",
  "Be practical, concise, and specific.",
  "Never diagnose, prescribe, or present medical advice.",
  "If the provided data is thin or contradictory, say so clearly.",
  "Prefer 3 to 6 sentence answers unless the user asks for more detail.",
  "Focus on training load, recovery, consistency, sleep, movement, and trends."
].join(" ");

export const coach = onRequest(
  {
    region: "europe-west2",
    timeoutSeconds: 60,
    memory: "256MiB",
    cors: true,
    invoker: "public",
    secrets: [openAIKey]
  },
  async (request, response) => {
    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "POST") {
      response.status(405).json({
        error: { message: "Method not allowed" }
      });
      return;
    }

    try {
      const payload = normalizePayload(request.body);
      const client = new OpenAI({ apiKey: openAIKey.value() });

      const openAIResponse = await client.responses.create({
        model: payload.model ?? defaultModel.value(),
        reasoning: { effort: "low" },
        max_output_tokens: 700,
        input: [
          {
            role: "system",
            content: [
              {
                type: "input_text",
                text: SYSTEM_PROMPT
              }
            ]
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: buildPrompt(payload)
              }
            ]
          }
        ]
      });

      const reply = openAIResponse.output_text?.trim();
      if (!reply) {
        response.status(502).json({
          error: { message: "OpenAI returned an empty reply" }
        });
        return;
      }

      response.status(200).json({
        reply,
        model: openAIResponse.model
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown server error";
      response.status(400).json({
        error: { message }
      });
    }
  }
);

function normalizePayload(body) {
  if (!body || typeof body !== "object") {
    throw new Error("Request body must be a JSON object.");
  }

  const messages = Array.isArray(body.messages) ? body.messages : [];
  if (messages.length === 0) {
    throw new Error("At least one message is required.");
  }

  const sanitizedMessages = messages
    .slice(-10)
    .map((message) => {
      if (!message || typeof message !== "object") {
        throw new Error("Invalid message payload.");
      }

      const role = message.role === "assistant" ? "assistant" : "user";
      const content = typeof message.content === "string" ? message.content.trim() : "";
      if (!content) {
        throw new Error("Messages must include non-empty content.");
      }

      return {
        role,
        content: content.slice(0, 3000)
      };
    });

  const context = body.context;
  if (!context || typeof context !== "object") {
    throw new Error("Context is required.");
  }

  return {
    model: typeof body.model === "string" && body.model.trim() ? body.model.trim() : null,
    messages: sanitizedMessages,
    context: {
      measurementSystem: safeString(context.measurementSystem, 32),
      disclaimer: safeString(context.disclaimer, 280),
      weeklyMetrics: safeArray(context.weeklyMetrics, 12),
      monthlyMetrics: safeArray(context.monthlyMetrics, 12),
      weeklyInsights: safeArray(context.weeklyInsights, 6),
      monthlyInsights: safeArray(context.monthlyInsights, 6)
    }
  };
}

function buildPrompt(payload) {
  const conversation = payload.messages
    .map((message) => `${message.role.toUpperCase()}: ${message.content}`)
    .join("\n");

  return [
    "Health context JSON:",
    JSON.stringify(payload.context, null, 2),
    "",
    "Conversation:",
    conversation
  ].join("\n");
}

function safeArray(value, maxItems) {
  return Array.isArray(value) ? value.slice(0, maxItems) : [];
}

function safeString(value, maxLength) {
  return typeof value === "string" ? value.slice(0, maxLength) : "";
}

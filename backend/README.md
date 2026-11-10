# Cloud coach private trial

Native iPhone integration and backend implementation. Disabled by default.
No OpenAI secret or shared trial token is included in the repository or app.

## Deployment gates

1. Verify Netlify Database is included in the chosen team plan, without upgrading.
2. Use branch `native-ios/cloud-coach`, base directory `backend`, build command
   `npm test`, publish directory `public`, functions directory `netlify/functions`.
   These paths are relative to the base. Do not deploy the repository root.
3. Deploy with AI disabled; verify migration and unauthenticated/disabled behavior.
4. In Netlify, add production-only Functions-scoped `BBB_OPENAI_API_KEY` and a
   separate cryptographically random `BBB_TRIAL_TOKEN` (at least 32 characters).
   Do not put secrets in commits, build logs, or chat. Do not use AI Gateway keys.
5. Only after reviewing billing and those checks, set `BBB_AI_ENABLED=true` and
   redeploy. Environment changes need a new deploy to reach Functions.
6. In the iPhone app, open Guided Goals > Cloud AI settings, enter the Netlify
   HTTPS root address and trial token, then explicitly enable cloud consent.
   The OpenAI API key never goes into the iPhone app.

This is one trusted tester's token, not production multi-user authentication.
Rotate the token if exposed. No automatic fallback to Apple AI on cloud failure.
Disabling cloud consent explicitly returns to on-device AI.

## Trial cost controls

Pinned model: `gpt-5.4-mini-2026-03-17`, no tools, no reasoning, max 2,400 output
tokens. Input is capped at 32,000 serialized UTF-8 bytes and the entire provider
request at 40,000 bytes including instructions/schema. Oversized requests are
rejected; old messages are not silently dropped. No automatic API retries.
A transactional database counter reserves at most 100 calls, lifetime,
including failed calls. It does not replenish on redeploy or month rollover.
Database failures fail closed. Previews cannot make provider calls.

At the verified model prices ($0.75/M input, $4.50/M output), a deliberately
conservative planning allowance of 50,000 input tokens plus 2,400 output tokens
is $0.0483/call, or $4.83 for 100 calls. This is a planning estimate, not an
account-wide dollar cap: provider token accounting/pricing, hosting usage, and
other projects on the same billing account are separate. Keep auto recharge off
and review actual usage before increasing the code-level lifetime allowance.

## Privacy and behavior

POST `/.netlify/functions/coach` requires Bearer authentication. Only the current
conversation, goal notes, and earlier completed outcomes are sent. The backend
stores only the usage counter, not chats. No application chat/key logging.
`store:false` does not promise zero provider retention. Chats stay on the phone.
No browsing or external actions. Guidance about current facts may be inaccurate.

Replies distinguish ongoing conversation, waiting for an outside action, and
an outcome ready for review. Agreement alone must not count as completion.
The user must confirm the outcome before the next brick unlocks.

## Verification

Run `npm ci && npm test` here. Local tests cover validation, auth and disabled
states, failure handling, provider payload, structured plans, and 110 concurrent
reservations against the local database emulator (100 succeed). Provider calls
are mocked: these tests spend no credit and do not evaluate live coaching quality.
Native tests cover older-save compatibility, endpoint safety and completion
readiness; macOS CI is required to compile/test SwiftUI.

Before release, test a real opted-in cloud conversation: agree to a proposed
lesson, verify it advances rather than repeats, demonstrate the finish criterion,
review the outcome once, then reopen and verify saved progress. Test an offline
retry and confirm messages are not duplicated. Do not reset existing saved goals.

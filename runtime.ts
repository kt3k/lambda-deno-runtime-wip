import { handler } from "./function.ts";

const { AWS_LAMBDA_RUNTIME_API } = Deno.env();
const REQUEST_ID_HEADER = "Lambda-Runtime-Aws-Request-Id";
const API_PREFIX = `http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation`;

async function main() {
  while (true) {
    const invocation = await fetch(`${API_PREFIX}/next`);
    const requestId = invocation.headers.get(REQUEST_ID_HEADER);
    const payload = await invocation.json();
    const res = await handler(payload);
    const body = typeof res === "string" ? { statusCode: 200, body: res } : res;
    await (await fetch(`${API_PREFIX}/${requestId}/response`, {
      method: "POST",
      body: JSON.stringify(body)
    })).blob();
  }
}

main();

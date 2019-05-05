import { handler } from "./function.ts"

const { AWS_LAMBDA_RUNTIME_API } = Deno.env()
const REQUEST_ID_HEADER = "Lambda-Runtime-Aws-Request-Id"
const API_INVOCATION = `http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation`

async function main() {
  while (true) {
    const invocation = await fetch(`${API_INVOCATION}/next`)
    const requestId = invocation.headers.get(REQUEST_ID_HEADER)
    const payload = await invocation.json()
    const res = await handler(payload)
    await(await fetch(`${API_INVOCATION}/${requestId}/response`, {
      method: "POST",
      body: typeof res === "string" ? res : JSON.stringify(res)
    })).blob()
  }
}

main()

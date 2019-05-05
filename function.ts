export async function handler(event) {
  return `hello from Deno in AWS Lambda\n${JSON.stringify(Deno.version)}`
}

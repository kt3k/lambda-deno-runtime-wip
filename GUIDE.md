This guide describes how to write AWS Lambda function in deno at the time of this writing (deno v0.4.0). Many things could be improved later and you'll be able to skip these steps in future.

AWS Lambda supports [Custom Runtimes][]. You can write your own runtime in any language and provide it to AWS Lambda. In this guide, I'll show you how to write a custom runtime in deno and deploy it to AWS Lambda.

# Prerequisites

This guide describes the 2 ways (Part 1 and Part 2) to create a lambda function in deno. In both cases, you need the followings:

- AWS IAM user which can create a lambda function
- AWS Role for lambda function (You need a role which has "AWSLambdaBasicExecutionRole" policy)

See [the Prerequisites section of AWS Lambda Custom Runtime tutorial](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-walkthrough.html) for more details.

# Part 1. Do everything on your own

## Build Custom Deno

The current official deno binary doesn't run on the operating system of Lambda because of the [glibc compatibility issue][issue1658]. You need to build your own deno for it. What you need to do is to build Deno in [this image](https://github.com/denoland/deno/issues/1658) which is the exact image Lambda uses. (In addition, you need to set `use_sysroot = false` flag on `.gn` file. I don't understand this flag, but anyway it works.)

If you want to avoid building deno on your own, please download the binary from [here](https://github.com/kt3k/lambda-deno-runtime-wip/blob/master/deno) which I built the recent version of deno with the above settings. I confirmed this works in the Lambda environment.

## Write Custom Runtime

You need to write a custom runtime in deno. A custom runtime is a program which is responsible for setting up the Lambda handler, fetching events from Lambda runtime API, invoking the handler, sending back the response to Lambda runtime API, etc. The entrypoint of a custom runtime have to be named `bootstrap`. The example of such program is like the below (This is Deno program wrapped by Bash script.)

```bash
#!/bin/sh
set -euo pipefail

SCRIPT_DIR=$(cd $(dirname $0); pwd)
HANDLER_NAME=$(echo "$_HANDLER" | cut -d. -f2)
HANDLER_FILE=$(echo "$_HANDLER" | cut -d. -f1)

echo "
import { $HANDLER_NAME } from '$LAMBDA_TASK_ROOT/$HANDLER_FILE.ts';
const API_ROOT =
  'http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/';
(async () => {
  while (true) {
    const next = await fetch(API_ROOT + 'next');
    const reqId = next.headers.get('Lambda-Runtime-Aws-Request-Id');
    const res = await $HANDLER_NAME(await next.json());
    await (await fetch(
      API_ROOT + reqId + '/response',
      {
        method: 'POST',
        body: JSON.stringify(res)
      }
    )).blob();
  }
})();
" > /tmp/runtime.ts
DENO_DIR=/tmp/deno_dir $SCRIPT_DIR/deno run --allow-net --allow-read /tmp/runtime.ts
```

```
import { $HANDLER_NAME } from '$LAMBDA_TASK_ROOT/$HANDLER_FILE.ts';
```
In this line, you import lambda function from the task directory. `$LAMBDA_TASK_ROOT` is given by Lambda environment. `$HANDLER_NAME` and `$HANDLER_FILE` are the first and second part of `handler` propert of your lambda which you'll set from the aws API. If you set the handler property `function.handler` then the above line `import { handler } from '$LAMBDA_TASK_ROOT/function.ts'`. So your lambda function need to be named `function.ts` and it needs to export `handler` as the handler.

```ts
(async () => {
  while (true) {
    ...
  }
})();
```

This block creates the loop for event handling of Lambda. A single event is processed on each iteration of this loop.

```ts
    const next = await fetch(API_ROOT + 'next');
    const reqId = next.headers.get('Lambda-Runtime-Aws-Request-Id');
```

These 2 lines fetches the event from Lambda runtime API and stores the request id.

```ts
    const res = await $HANDLER_NAME(await next.json());
```

This line invokes the lambda handler with the given event payload and stores the result.

```ts
    await (await fetch(
      API_ROOT + reqId + '/response',
      {
        method: 'POST',
        body: JSON.stringify(res)
      }
    )).blob();
```

This line sends back the handler's result to Lambda runtime API.

## Write Lambda function

## Deploy

## Test

# Part 2. Use the layer

## Write Lambda function

## Deploy

# Referances

Repos

[Custom Runtimes]: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html
[AMI]: https://console.aws.amazon.com/ec2/v2/home#Images:visibility=public-images;search=amzn-ami-hvm-2017.03.1.20170812-x86_64-gp2
[issue1658]: https://github.com/denoland/deno/issues/1658

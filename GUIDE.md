---
title: Write AWS Lambda function in Deno
published: true
description: The guide of writing AWS Lambda function in deno.
tags: aws, lambda, serverless, deno
---

This guide describes how to write AWS Lambda function in [deno][] at the time of this writing (deno v0.4.0). Many things could be improved later and you'll be able to skip some of these steps in future.

AWS Lambda supports [Custom Runtimes][]. You can write your own runtime in any language and use it in AWS Lambda. In this guide, I'll show you how to write a custom runtime in deno and deploy it to AWS.

# Prerequisites

This guide describes the 2 ways (Part 1 and Part 2) to create a lambda function in deno. In both cases, you need the followings:

- AWS IAM user which can create a lambda function
- AWS Role for lambda function (You need a role which has "AWSLambdaBasicExecutionRole" policy)
  - In this article, I suppose it has the name `arn:aws:iam::123456789012:role/lambda-role`. Please replace it with your own one on your side.
- AWS CLI installed

See [the Prerequisites section of AWS Lambda Custom Runtime tutorial](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-walkthrough.html) for more details.

# Part 1. Do everything on your own

## Build Custom Deno

The current official deno binary doesn't run on the operating system of Lambda because of the [glibc compatibility issue][issue1658]. You need to build your own deno for it. What you need to do is to build deno in [this image](https://console.aws.amazon.com/ec2/v2/home#Images:visibility=public-images;search=amzn-ami-hvm-2017.03.1.20170812-x86_64-gp2) which is the exact image Lambda uses. (In addition, you need to set `use_sysroot = false` flag on `.gn` file. I don't understand this flag, but anyway it works. See [the comment](https://github.com/denoland/deno/issues/1658#issuecomment-460723060) in the above issue if you're interested in details.)

If you want to avoid building deno on your own, please download the binary from [here](https://github.com/kt3k/lambda-deno-runtime-wip/blob/master/deno) which I built based on a recent version of deno with the above settings. I confirmed this works in the Lambda environment.

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

```ts
import { $HANDLER_NAME } from '$LAMBDA_TASK_ROOT/$HANDLER_FILE.ts';
```
In this line, you import lambda function from the task directory. `$LAMBDA_TASK_ROOT` is given by Lambda environment. `$HANDLER_NAME` and `$HANDLER_FILE` are the first and second part of `handler` property of your lambda which you'll set through AWS CLI. If you set the handler property `function.handler`, for example, then the above line becomes `import { handler } from '$LAMBDA_TASK_ROOT/function.ts'`. So your lambda function need to be named `function.ts` and it needs to export `handler` as the handler in that case.

```ts
(async () => {
  while (true) {
    ...
  }
})();
```

This block creates the loop of event handling of Lambda. A single event is processed on each iteration of the loop.

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

This line sends back the result to Lambda runtime API.

```bash
DENO_DIR=/tmp/deno_dir $SCRIPT_DIR/deno run --allow-net --allow-read /tmp/runtime.ts
```

This line starts the runtime script with `net` and `read` permissions. If you want to more permissions, you can add here the options you want. `DENO_DIR=/tmp/deno_dir` part is very important. Because Lambda environment doesn't allow you to write to the file system except `/tmp`, you need to set `DENO_DIR` somewhere under `/tmp`.

## Write Lambda function

Now you need to write your lambda function in deno. The example looks like the below:

```ts
export async function handler(event) {
  return {
    statusCode: 200,
    body: JSON.stringify({
      version: Deno.version,
      build: Deno.build
    })
  };
}
```

This lambda function returns a simple object which contains status code 200 and deno's version information as body.

## Deploy

Now you have 3 files `deno`, `bootstrap` (bash script), and `function.ts` (deno script). These are all files you need to run your Lambda function. You need to zip them:

```console
$ zip function.zip deno bootstrap function.ts
```

Then you can deploy it like the below:

```console
$ aws lambda create-function --function-name deno-func --zip-file fileb://function.zip --handler function.handler --runtime provided --role arn:aws:iam::123456789012:role/lambda-role
```

(Note: Replace `arn:aws:iam::123456789012:role/lambda-role` to your own role's arn.)

`--runtime provided` option means this lambda uses a custom runtime.

## Test

You can invoke the above lambda like the below:

```console
$ aws lambda invoke --function-name deno-func response.json
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
$ cat response.json
{"statusCode":200,"body":"{\"version\":{\"deno\":\"0.4.0\",...}}}
```

# Part 2. Use the shared layer

AWS Supports the Lambda Layer. A lambda layer is a ZIP archive that contains libraries, a custom runtime, or other dependencies. I published the above `deno` binary and `bootstrap` script as a public layer. You can reuse it as a custom deno runtime.

In this case, what you need to do is just to write a lambda function in deno and deploy it to AWS.

## Create Deno Lambda Function using Public Deno Runtime

An example `function.ts` looks like the below (The same as the above):

```ts
export async function handler(event) {
  return {
    statusCode: 200,
    body: JSON.stringify({
      version: Deno.version,
      build: Deno.build
    })
  };
}
```

Then zip it and deploy it:

```console
$ zip function-only.zip function.ts
$ aws lambda create-function --function-name deno-func-only --layers arn:aws:lambda:ap-northeast-1:439362156346:layer:deno-runtime:13 --zip-file fileb://function-only.zip --handler function.handler --runtime provided --role arn:aws:iam::123456789012:role/lambda-role
```

(Note: Replace `arn:aws:iam::123456789012:role/lambda-role` to your own role's arn.)

Where the arn `arn:aws:lambda:ap-northeast-1:439362156346:layer:deno-runtime:13` is a public lambda layer which implements deno runtime. The `--layers arn:aws:lambda:ap-northeast-1:439362156346:layer:deno-runtime:13` option specifies this lambda function uses it as the shared layer.

## Test it

You should be able to invoke the above lambda function like the below:

```console
$ aws lambda invoke --function-name deno-func-only response.json
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
$ cat response.json
{"statusCode":200,"body":"{\"version\":{\"deno\":\"0.4.0\",...}}}
```

That's it. Thank you for reading.

# References

All examples are available in [this repository](https://github.com/kt3k/lambda-deno-runtime-wip).

[deno]: https://deno.land/
[Custom Runtimes]: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html
[AMI]: https://console.aws.amazon.com/ec2/v2/home#Images:visibility=public-images;search=amzn-ami-hvm-2017.03.1.20170812-x86_64-gp2
[issue1658]: https://github.com/denoland/deno/issues/1658


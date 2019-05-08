(Note: This guide is not for everyone, but for someone who is very interested in running Deno in AWS Lambda at this stage.)

This guide describes how to write AWS Lambda function in deno at the time of this writing (deno v0.4.0). Many things could be improved and could be skipped in later versions.

# Prerequisites

You need the following things:

- AWS Account
- AWS IAM user which can create a lambda function
- AWS Role for lambda function (You need

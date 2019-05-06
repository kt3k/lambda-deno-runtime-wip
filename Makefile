.PHONY: function.zip
function.zip:
	zip function.zip bootstrap deno function.ts runtime.ts

.PHONY: s3
s3:
	aws s3 cp function.zip s3://blue-knife/

.PHONY: deploy
deploy:
	aws lambda create-function --function-name deno_v2 --zip-file fileb://function.zip --handler function.handler --runtime provided --role ${LAMBDA_ROLE}

.PHONY: update
update:
	aws lambda update-function-code --function-name deno_v2 --zip-file fileb://function.zip

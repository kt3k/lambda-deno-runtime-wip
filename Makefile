.PHONY: function.zip
function.zip:
	zip function.zip bootstrap deno function.ts runtime.ts

.PHONY: deploy
deploy:
	aws lambda create-function --function-name deno_v2 --zip-file fileb://function.zip --handler function.handler --runtime provided --role ${LAMBDA_ROLE}

.PHONY: update
update:
	aws lambda update-function-code --function-name deno_v2 --zip-file fileb://function.zip

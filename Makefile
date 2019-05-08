.PHONY: function.zip
function.zip:
	zip function.zip bootstrap deno function.ts runtime.ts

.PHONY: function-only.zip
function-only.zip:
	zip function-only.zip function.ts

.PHONY: runtime.zip
runtime.zip:
	zip runtime.zip bootstrap deno runtime.ts

.PHONY: create-lambda
create-lambda:
	aws lambda create-function --function-name ${LAMBDA_NAME} --zip-file fileb://function.zip --handler function.handler --runtime provided --role ${LAMBDA_ROLE}

.PHONY: update-lambda
update-lambda:
	aws lambda update-function-code --function-name ${LAMBDA_NAME} --zip-file fileb://function.zip

.PHONY: update-lambda-function-only
update-lambda-function-only:
	aws lambda update-function-code --function-name ${LAMBDA_NAME} --zip-file fileb://function-only.zip

.PHONY: update-layer
update-layer:
	aws lambda update-function-configuration --function-name ${LAMBDA_NAME} --layers ${LAMBDA_LAYER}

.PHONY: publish-layer
publish-layer:
	aws lambda publish-layer-version --layer-name deno-runtime --zip-file fileb://runtime.zip

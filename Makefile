.PHONY: function.zip
function.zip:
	zip function.zip bootstrap deno function.ts runtime.ts

.PHONY: s3
s3:
	aws s3 cp function.zip s3://blue-knife/

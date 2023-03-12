dist/libnow.a:
	ldc2 --lib \
		-oq -od=build/ \
		source/now/app.d \
		-I source \
		--O2 -of=dist/libnow.a

dist/libnow.debug.a:
	ldc2 --d-debug --lib \
		-oq -od=build/ \
		source/now/app.d \
		-I source \
		--O1 -of=dist/libnow.debug.a

clean:
	-rm -f dist/libnow.*
	-rm -f build/*

CC = ldc2
DIR = source/now
BASE_CODE = ${DIR}/*.d ${DIR}/system_command/*.d ${DIR}/task/*.d ${DIR}/nodes/*.d ${DIR}/nodes/*/*.d
SOURCE_CODE = ${BASE_CODE} ${DIR}/commands/*.d cli/now/cli.d

dist/now: ${SOURCE_CODE}
	${CC} $^ \
		--checkaction=halt \
		-od=build --oq \
		-O2 -of dist/now

release: dist/now
	strip $^
	ls -lh dist/

dist/now.debug: ${SOURCE_CODE}
	${CC} --d-debug $^ \
		-O1 -of dist/now.debug

standalone: ${SOURCE_CODE}
	gdc $^ \
		-frelease -O3 \
		-static-libphobos \
		-o dist/now-$$( \
	git describe --tags $$( \
		git rev-list --tags --max-count=1 \
	))-$$(uname -m)-$$(uname -o | sed 's:/:-:g' | tr A-Z a-z)
	strip dist/now-*

clean:
	-rm -f dist/now*

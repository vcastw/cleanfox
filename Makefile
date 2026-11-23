.PHONY: all fetch prepare build package lint clean

all: fetch prepare build package

fetch:
	scripts/fetch.sh

prepare:
	scripts/prepare.sh

build:
	scripts/build.sh

package:
	scripts/package.sh

lint:
	tests/lint.sh

clean:
	rm -rf build dist

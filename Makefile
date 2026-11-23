# Alvo: make TARGET=linux|windows|macos|android (padrão: o sistema atual)
ifdef TARGET
export CLEANFOX_TARGET := $(TARGET)
endif

.PHONY: all fetch prepare build package lint branding clean

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

branding:
	python3 tools/gen-branding.py

clean:
	rm -rf build dist

COFFEE := coffee
COFFEELINT := coffeelint
DOCCO := docco
PYTHON := python

COFFEE_SRC := $(wildcard src/*.coffee)
COFFEE_OUT := $(COFFEE_SRC:src/%.coffee=build/%.js)
COFFEE_DOC_OUT := build/doc/docco.css $(COFFEE_SRC:src/%.coffee=build/doc/%.html)
COPY_SRC := $(wildcard src/*.css) src/index.html
COPY_OUT := $(COPY_SRC:src/%=build/%)
PAGES_OUT := $(COFFEE_OUT) $(COPY_OUT) $(COFFEE_DOC_OUT)
PAGES_ROOT := $(PAGES_OUT:build/%=%)

GIT_BRANCH = $(shell git rev-parse --abbrev-ref HEAD)
GIT_SHA1 = $(shell git rev-parse HEAD)

.PHONY: all coffee misc doc clean gh-pages check serve

all: coffee misc

coffee: $(COFFEE_OUT)

build/%.js: src/%.coffee
	$(COFFEE) -c -o build $<

misc: $(COPY_OUT)

build/%: src/%
	cp $< $@

doc: $(COFFEE_SRC)
	$(DOCCO) -o build/doc $^

clean:
	rm -rf build/*

gh-pages: all doc
	git checkout gh-pages && \
	git rm -r --ignore-unmatch . && \
	mkdir -p $(sort $(dir $(PAGES_ROOT))) && \
	for f in $(PAGES_OUT); do \
		cp -a "$$f" "$${f#build/}"; \
	done && \
	git add $(PAGES_ROOT) && \
	git commit -em "$$(echo -e "Re-generate pages from branch '$(GIT_BRANCH)'\n\nSource commit: $(GIT_SHA1)")"

check: coffeelint.json $(COFFEE_SRC)
	$(COFFEELINT) -f $^

serve:
	cd build && exec python -m SimpleHTTPServer

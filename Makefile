.PHONY: test e2e helptags release-check

test:
	./test/run.sh

e2e:
	python3 test/e2e/run.py

helptags:
	vim -Nu NONE -n -es -c 'helptags doc' -c 'qa!'

release-check:
	@version="$$(cat VERSION)"; \
	for file in autoload/ditto.vim plugin/ditto.vim; do \
		current="$$(sed -n 's/^" Version:  *//p' "$$file")"; \
		if [ "$$current" != "$$version" ]; then \
			echo "$$file has version $$current, expected $$version" >&2; \
			exit 1; \
		fi; \
	done; \
	if ! grep -q "^## \[$$version\]" CHANGELOG.md; then \
		echo "CHANGELOG.md has no section for $$version" >&2; \
		exit 1; \
	fi; \
	echo "release metadata OK: $$version"

PROJECT_DIR := migrations
TOOL := $(PROJECT_DIR)/bin/migrations

.PHONY: build help inspect dry-run migrate check

build:
	cd $(PROJECT_DIR) && alr build

help: build
	./$(TOOL) --help

inspect: build
	@test -n "$(CRATE)" || (echo "Usage: make inspect CRATE=/path/to/crate"; exit 2)
	./$(TOOL) inspect "$(CRATE)"

dry-run: build
	@test -n "$(CRATE)" && test -n "$(EDITION)" || (echo "Usage: make dry-run CRATE=/path/to/crate EDITION=2024"; exit 2)
	./$(TOOL) migrate "$(CRATE)" "$(EDITION)" --dry-run

migrate: build
	@test -n "$(CRATE)" && test -n "$(EDITION)" || (echo "Usage: make migrate CRATE=/path/to/crate EDITION=2024"; exit 2)
	./$(TOOL) migrate "$(CRATE)" "$(EDITION)"

check: build
	@test -n "$(CRATE)" && test -n "$(EDITION)" || (echo "Usage: make check CRATE=/path/to/crate EDITION=2024"; exit 2)
	./$(TOOL) migrate "$(CRATE)" "$(EDITION)" --check
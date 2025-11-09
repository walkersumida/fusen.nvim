.PHONY: test test-local install-test-deps

# Install test dependencies
install-test-deps:
	@echo "Installing test dependencies..."
	@if [ ! -d "/tmp/plenary.nvim" ]; then \
		git clone --depth 1 https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim; \
	else \
		echo "plenary.nvim already installed"; \
	fi

# Run tests locally
test-local: install-test-deps
	@echo "Running tests..."
	@PLENARY_DIR=/tmp/plenary.nvim nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }"

# Run specific test file
test-file: install-test-deps
	@echo "Running test file: $(FILE)"
	@PLENARY_DIR=/tmp/plenary.nvim nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)"

# Default test command
test: test-local

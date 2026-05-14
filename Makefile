REPO_ROOT    := $(CURDIR)
DOCKER_IMAGE := se2-workshop-test

.PHONY: help lint lint-bash lint-powershell test-container test clean

help:
	@echo "Targets:"
	@echo "  make lint            shellcheck + PSScriptAnalyzer (Layer 1)"
	@echo "  make test-container  run wsl-bootstrap.sh + verify.sh --ci in a clean Ubuntu container (Layer 2)"
	@echo "  make test            lint + test-container"
	@echo "  make clean           remove the test container image"

lint: lint-bash lint-powershell

lint-bash:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed (apt install shellcheck)" >&2; exit 1; }
	shellcheck --severity=warning wsl-bootstrap.sh verify.sh

lint-powershell:
	@command -v pwsh >/dev/null 2>&1 || { echo "pwsh not installed; skipping .ps1 lint" >&2; exit 0; }
	pwsh -NoProfile -Command "if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { Install-Module PSScriptAnalyzer -Scope CurrentUser -Force }; \$$r = Invoke-ScriptAnalyzer -Path windows-bootstrap.ps1 -Severity Warning,Error -ExcludeRule PSAvoidUsingWriteHost; \$$r | Format-Table; if (\$$r) { exit 1 }"

test-container:
	@command -v docker >/dev/null 2>&1 || { echo "docker not installed" >&2; exit 1; }
	docker build -t $(DOCKER_IMAGE) test/
	docker run --rm -v "$(REPO_ROOT):/work:ro" -w /work $(DOCKER_IMAGE) \
		bash -c "bash ./wsl-bootstrap.sh && bash ./verify.sh --ci"

test: lint test-container

clean:
	-docker rmi $(DOCKER_IMAGE) 2>/dev/null || true

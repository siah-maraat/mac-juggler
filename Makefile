PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LAUNCH_AGENT_DIR = $(HOME)/Library/LaunchAgents
PLIST = com.trackpadrelay.agent.plist

.PHONY: build install uninstall clean

build:
	swift build -c release --arch arm64 --arch x86_64

install: build
	mkdir -p $(BINDIR)
	cp .build/apple/Products/Release/trackpad-relay $(BINDIR)/
	mkdir -p $(LAUNCH_AGENT_DIR)
	cp Resources/$(PLIST) $(LAUNCH_AGENT_DIR)/
	@echo "✅ Installed to $(BINDIR)/trackpad-relay"
	@echo ""
	@echo "To start the service:"
	@echo "  brew services start trackpad-relay"
	@echo ""
	@echo "Or manually:"
	@echo "  launchctl load $(LAUNCH_AGENT_DIR)/$(PLIST)"

uninstall:
	launchctl unload $(LAUNCH_AGENT_DIR)/$(PLIST) 2>/dev/null || true
	rm -f $(BINDIR)/trackpad-relay
	rm -f $(LAUNCH_AGENT_DIR)/$(PLIST)
	@echo "✅ Uninstalled"

clean:
	rm -rf .build

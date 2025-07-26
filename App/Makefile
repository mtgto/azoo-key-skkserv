
.PHONY: all clean build notarize staple

# Configuration variables
PROJECT_NAME := azoo-key-skkserv
PROJECT_FILE := $(PROJECT_NAME).xcodeproj
SCHEME := $(PROJECT_NAME)
TEAM_ID := $(TEAM_ID)
APPLE_ID := $(APPLE_ID)
APPLE_APP_PASSWORD := $(APPLE_APP_PASSWORD)

BUILD_DIR := build
DIST_DIR := dist
ARCHIVE_PATH := $(BUILD_DIR)/$(PROJECT_NAME).xcarchive
APP_PATH := $(BUILD_DIR)/$(PROJECT_NAME).app
DMG_TEMP_DIR := $(BUILD_DIR)/dmg-temp
DMG_NAME := $(PROJECT_NAME).dmg
DMG_PATH := $(DIST_DIR)/$(DMG_NAME)
EXPORT_OPTIONS_PLIST := $(BUILD_DIR)/ExportOptions.plist

all: $(DMG_PATH)

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(DIST_DIR) $(EXPORT_OPTIONS_PLIST) $(APP_PATH) $(ARCHIVE_PATH)

# Create build and dist directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

# Create ExportOptions.plist
$(EXPORT_OPTIONS_PLIST):
	@echo "Creating ExportOptions.plist..."
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $@
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $@
	@echo '<plist version="1.0">' >> $@
	@echo '<dict>' >> $@
	@echo '    <key>method</key>' >> $@
	@echo '    <string>developer-id</string>' >> $@
	@echo '    <key>destination</key>' >> $@
	@echo '    <string>export</string>' >> $@
	@echo '    <key>signingStyle</key>' >> $@
	@echo '    <string>automatic</string>' >> $@
	@echo '    <key>stripSwiftSymbols</key>' >> $@
	@echo '    <true/>' >> $@
	@echo '    <key>uploadBitcode</key>' >> $@
	@echo '    <false/>' >> $@
	@echo '    <key>uploadSymbols</key>' >> $@
	@echo '    <false/>' >> $@
	@echo '</dict>' >> $@
	@echo '</plist>' >> $@

# Archive the application
$(ARCHIVE_PATH): $(BUILD_DIR)
	@echo "Archiving $(PROJECT_NAME)..."
	xcodebuild -project $(PROJECT_FILE) -scheme $(SCHEME) -sdk macosx -configuration Release -archivePath $@ DEVELOPMENT_TEAM=$(TEAM_ID) ONLY_ACTIVE_ARCH=NO archive

# Export the application
$(APP_PATH): $(ARCHIVE_PATH) $(EXPORT_OPTIONS_PLIST)
	@echo "Exporting $(PROJECT_NAME).app..."
	xcodebuild -exportArchive -archivePath $< -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_OPTIONS_PLIST)

# Prepare DMG contents
$(DMG_TEMP_DIR): $(APP_PATH)
	@echo "Preparing DMG contents..."
	mkdir -p $@
	cp -R $(APP_PATH) $@/
	ln -s /Applications $@/Applications

# Create DMG
$(DMG_PATH): $(DMG_TEMP_DIR) $(DIST_DIR)
	@echo "Creating $(DMG_NAME)..."
	hdiutil create -volname $(PROJECT_NAME) -srcfolder $< -format ULFO -ov $@

# Notarize DMG
notarize:
	@echo "Submitting $(DMG_NAME) for notarization..."
	xcrun notarytool submit $(DMG_PATH) --apple-id $(APPLE_ID) --password $(APPLE_APP_PASSWORD) --team-id $(TEAM_ID) --wait

# Staple notarization ticket
staple:
	@echo "Stapling notarization ticket to $(DMG_NAME)..."
	xcrun stapler staple $(DMG_PATH)

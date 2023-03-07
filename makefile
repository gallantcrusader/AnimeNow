all: ios-build macos-build

ios-build:
	xcodebuild archive \
		-project App/AnimeNow.xcodeproj \
    	-destination "generic/platform=iOS" \
        -scheme "Anime Now!" \
        -archivePath "./App/Anime Now! (iOS).xcarchive" \
        -xcconfig "./App/MainConfig.xcconfig" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY= \
        CODE_SIGN_ENTITLEMENTS= \
        GCC_OPTIMIZATION_LEVEL=s \
        SWIFT_OPTIMIZATION_LEVEL=-O \
        GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
        DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
	mkdir -p "./App/Payload"
	cd App && mv "./Anime Now! (iOS).xcarchive/Products/Applications/Anime Now!.app" "./Payload/Anime Now!.app"
	cd App && zip -r "./Anime Now! (iOS).ipa" './Payload'
	cd App && tar -czf 'Anime Now! (iOS) Symbols.tar.gz' -C './Anime Now! (iOS).xcarchive' 'dSYMs'

macos-build:
	xcodebuild archive \
		-project App/AnimeNow.xcodeproj \
		-destination "generic/platform=macOS" \
		-scheme "Anime Now!" \
		-archivePath "./App/Anime Now! (macOS).xcarchive" \
		-xcconfig "./App/MainConfig.xcconfig" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY= \
		CODE_SIGN_ENTITLEMENTS= \
		GCC_OPTIMIZATION_LEVEL=s \
		SWIFT_OPTIMIZATION_LEVEL=-O \
		GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
	create-dmg \
		--volname "Anime Now!" \
		--background "./Misc/Media/dmg_background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 160 \
		--icon "Anime Now!.app" 180 170 \
		--hide-extension "Anime Now!.app" \
		--app-drop-link 480 170 \
		--no-internet-enable \
		"./App/Anime Now! (macOS).dmg" \
		"./App/Anime Now! (macOS).xcarchive/Products/Applications/"
	cd App && tar -czf 'Anime Now! (macOS) Symbols.tar.gz' -C './App/Anime Now! (macOS).xcarchive' 'dSYMs'

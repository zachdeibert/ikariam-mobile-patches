ADB=adb
APKSIGNER=apksigner
JARSIGNER=jarsigner
KEYTOOL=keytool
ZIPALIGN=zipalign

.PHONY: all
all: tmp/ikariam/dist/ikariam-signed.apk

.PHONY: clean
clean:
	rm -rf tmp

.PHONY: fullclean
fullclean: clean
	rm -rf cache

.PHONY: install
install: all
	$(ADB) uninstall com.gameforge.mobilizer.ikariam.sencha || true
	$(ADB) install tmp/ikariam/dist/ikariam-signed.apk || $(ADB) install tmp/ikariam/dist/ikariam-signed.apk

.PHONY: run
run: install
	$(ADB) shell am start -n com.gameforge.mobilizer.ikariam.sencha/com.gameforge.mobilizer.ikariam.sencha.MobilizerActivity
	sleep 1
	$(ADB) logcat --pid=`$(ADB) shell pidof com.gameforge.mobilizer.ikariam.sencha | tr -d "\r"`

.PHONY: rebuild
rebuild:
	rm -f tmp/ikariam/dist/ikariam.apk

tmp/.dir: Makefile
	rm -rf tmp
	mkdir tmp
	touch tmp/.dir

cache/.dir:
	mkdir cache
	touch cache/.dir

cache/ikariam.apk: cache/.dir
	$(ADB) pull `$(ADB) shell pm path com.gameforge.mobilizer.ikariam.sencha | sed -e "s|^package:||" | tr -d \r` $@

cache/apktool.jar: cache/.dir
	wget -O $@ https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.6.1.jar
	touch $@

cache/apktool: cache/.dir cache/apktool.jar
	wget -O $@ https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
	touch $@
	chmod +x $@

cache/keystore.keystore: cache/.dir
	$(KEYTOOL) -genkey -v -keystore $@ -alias app -keyalg RSA -keysize 2048 -validity 10000 -storepass changeit -dname CN=ikariam-mobile-patches

tmp/ikariam/apktool.yml: cache/ikariam.apk cache/apktool
	cache/apktool d -o tmp/ikariam -f $<

tmp/ikariam/dist/ikariam.apk: cache/keystore.keystore tmp/ikariam/apktool.yml cache/apktool
	cache/apktool b tmp/ikariam
	$(JARSIGNER) -sigalg SHA1withRSA -digestalg SHA1 -storepass changeit -keystore $< $@ app

tmp/ikariam/dist/ikariam-signed.apk: tmp/ikariam/dist/ikariam.apk cache/keystore.keystore
	rm -f $@
	$(ZIPALIGN) 4 $< $@
	$(APKSIGNER) sign --ks cache/keystore.keystore --ks-key-alias app --ks-pass pass:changeit $@

################################################################################
# Application Error: The connection to the server was unsuccessful.
# (file:///android_asset/www/shared/lobby/index.html)

tmp/ikariam/dist/ikariam.apk: tmp/application-error-connection.stamp
tmp/application-error-connection.stamp: tmp/ikariam/apktool.yml
	patch tmp/ikariam/res/xml/config.xml application-error-connection.patch
	touch $@

################################################################################
# Uncaught TypeError: Unable to process binding "pwdMeter: function(){return
# true }

tmp/ikariam/dist/ikariam.apk: tmp/pwdmeter-binding.stamp
tmp/pwdmeter-binding.stamp: tmp/ikariam/apktool.yml
	patch tmp/ikariam/assets/www/shared/lobby/templates/save.html pwdmeter-binding-save.patch
	patch tmp/ikariam/assets/www/shared/lobby/templates/tabs/create.html pwdmeter-binding-create.patch
	touch $@

################################################################################
# App crashes and returns to lobby directly after loading into a server

tmp/ikariam/dist/ikariam.apk: tmp/enable-https.stamp
tmp/enable-https.stamp: tmp/ikariam/apktool.yml tmp/application-error-connection.stamp
	sed -i -e "s|{|\n&\n|g" -e "s|}|\n&\n|g" tmp/ikariam/assets/www/shared/app/app.js
	patch tmp/ikariam/assets/www/shared/app/app.js enable-https-app.patch
	patch tmp/ikariam/res/xml/config.xml enable-https-config.patch
	cat tmp/ikariam/assets/www/shared/app/app.js | tr -d "\n" > tmp/ikariam/assets/www/shared/app/app.js.new
	mv tmp/ikariam/assets/www/shared/app/app.js.new tmp/ikariam/assets/www/shared/app/app.js
	touch $@

################################################################################
# Upgrade app SDK version

tmp/ikariam/dist/ikariam.apk: tmp/sdk-upgrade.stamp
tmp/sdk-upgrade.stamp: tmp/ikariam/apktool.yml
	patch tmp/ikariam/AndroidManifest.xml sdk-upgrade.patch
	touch $@

################################################################################
# Accessing the device ID from a user app in newer SDK versions is a security
# exception

tmp/ikariam/dist/ikariam.apk: tmp/no-device-id.stamp
tmp/no-device-id.stamp: tmp/ikariam/apktool.yml
	patch tmp/ikariam/smali/com/gameforge/xmobile/hostapplib/Identifikation.smali no-device-id.patch
	touch $@

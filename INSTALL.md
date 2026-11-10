# Installing Trainer Toolkit on your iPhone

The app is sideloaded with **Sideloadly** using a free Apple ID. No App Store, no Mac needed.

## 1. Get the IPA

The IPA is built by GitHub Actions (workflow **Build unsigned IPA**).

1. Open the repository on GitHub > **Actions** > **Build unsigned IPA**.
2. Click **Run workflow** (or push a tag such as `v0.0.1`).
3. When the run is green, open it and download the artifact **TrainerToolkit-ipa-N** at the bottom of the page.
   GitHub wraps artifacts in a `.zip`. Unzip it to get `TrainerToolkit.ipa`.
4. On tagged builds the IPA is also attached to the matching **Release**, with no zip around it.

The IPA is **unsigned**. Sideloadly signs it with your Apple ID in the next step.

## 2. Sign and install with Sideloadly

1. Install Sideloadly from its official site, plus the Apple components its download page says Windows needs.
   At the time of writing that is the iTunes and iCloud versions downloaded from Apple's website, not the Microsoft Store ones.
2. Connect the iPhone with a cable, unlock it and tap **Trust This Computer** if asked.
3. In Sideloadly, drag in `TrainerToolkit.ipa`, select your iPhone, enter your Apple ID and click **Start**.
   Sideloadly may ask for your Apple ID password or a 2FA code. Type these into Sideloadly yourself.
4. Leave Sideloadly's advanced options at their defaults. Above all, do not change the bundle ID (see section 4).

## 3. Allow the app on the iPhone

1. **Trust the developer profile:** Settings > General > **VPN & Device Management** > your Apple ID under *Developer App* > **Trust**.
2. **Developer Mode** (iOS 16 and later): Settings > Privacy & Security > **Developer Mode** > On. The phone restarts.
   The switch appears only after a sideloaded app has been installed.
3. Open **Trainer Toolkit**.

## 4. The 7-day limit and keeping your data

- Apps signed with a **free Apple ID expire after 7 days**. When that happens the app stops opening but **stays installed with its data**.
- **Don't delete the expired app.** Re-sign the same IPA (or a newer one) in Sideloadly and install it over the top.
- Free Apple IDs also have limits: about 3 sideloaded apps installed at once, and a weekly cap on new App IDs.

### Will my data survive a re-sign?

iOS treats an install with the **same bundle ID, signed by the same Apple ID** as an update of the existing app.
An update keeps the app's data container: SwiftData store, settings, checklists. Your data is **lost** if you:

- delete the app from the iPhone,
- install with a **different bundle ID** (iOS sees a new, separate app), or
- sign with a **different Apple ID**. iOS may refuse to install over the existing app, which forces a delete.

**Verifying it:** the app has a built-in check at More > Settings > **Install check**, showing *First launch*, *Launch count* and *Bundle ID*.
After re-signing and reinstalling over the existing app:

- *First launch* should stay the same, and *Launch count* should keep counting up. That means your data survived.
- If *First launch* reset to now, the install was treated as a new app. Compare the *Bundle ID* with the previous one.

> Status: **verified on device (2026-11-10).** Build #2 was signed with the same Apple ID and installed over build #1, and *First launch* stayed the same.

## Changing the bundle ID

The bundle ID is set in one place: `Config/Shared.xcconfig` (`APP_BUNDLE_ID`).
If Sideloadly reports that the App ID is unavailable, change it once to something unique, for example `com.yourname.trainertoolkit`, rebuild, and from then on keep it the same.

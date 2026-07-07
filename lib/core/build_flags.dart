/// True when built for App Store / Google Play, where an app must not update
/// itself (Apple guideline 2.5.2, Play equivalent) — the stores own updates.
/// Direct-distribution builds (desktop, sideloaded APK) keep the LAN update
/// system. Set with: flutter build … --dart-define=STORE_BUILD=true
const bool kStoreBuild = bool.fromEnvironment('STORE_BUILD');

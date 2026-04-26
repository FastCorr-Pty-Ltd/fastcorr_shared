/// Single source of truth for the **HTTP-side** Google Maps API key used
/// across all three FastCorr apps (user, admin, driver) for runtime calls
/// to:
///
/// * Routes / Directions API (polyline calculation)
/// * Geocoding API
/// * Places Autocomplete API
///
/// Platform-side keys (the ones that authenticate the `GoogleMap` widget
/// when it renders tiles) intentionally remain in each app's native
/// manifests:
///
/// * Android — `android/app/src/main/AndroidManifest.xml`
/// * iOS     — `ios/Runner/AppDelegate.swift`
/// * Web     — `web/index.html`
///
/// Those manifest keys may be the same value as this one or different
/// (e.g. restricted by SHA-1, bundle id, or HTTP referrer per platform).
/// Each app continues to own its own manifest configuration.
///
/// Exposure note: Google Maps client API keys are inherently public —
/// they ship inside compiled app binaries and the web bundle. Restriction
/// on the Google Cloud side (referrer / bundle / SHA / IP) is what
/// actually enforces access control, not source-code secrecy. Keeping
/// this constant in source is consistent with how the manifest keys are
/// already shipped.
const String googleMapsHttpApiKey = 'AIzaSyBejJ1uoiBstyyd7KEgyGdULCnAAcLyKGs';

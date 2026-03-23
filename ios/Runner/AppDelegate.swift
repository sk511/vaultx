import UIKit
import Flutter
import FirebaseCore

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // ── Firebase ──────────────────────────────────────────────────
        FirebaseApp.configure()

        // ── Flutter engine registration ───────────────────────────────
        GeneratedPluginRegistrant.register(with: self)

        // ── Prevent screenshot of app switcher thumbnail ──────────────
        // On iOS this is handled automatically when using the Keychain
        // (iOS blurs the app thumbnail when FLAG_SECURE equivalent is set).
        // We also hide the window on background transition.

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Blur the UI when the app enters background (app switcher protection)
    override func applicationWillResignActive(_ application: UIApplication) {
        if let window = UIApplication.shared.windows.first {
            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
            blurView.frame    = window.bounds
            blurView.tag      = 9999
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            window.addSubview(blurView)
        }
    }

    // Remove blur when app comes back to foreground
    override func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.windows.first?.viewWithTag(9999)?.removeFromSuperview()
    }
}

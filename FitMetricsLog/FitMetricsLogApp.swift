//
//  test1App.swift
//  test1
//

import SwiftUI

@main
struct test1App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear { setupKeyboardDismiss() }
        }
    }

    func setupKeyboardDismiss() {
        let tapGesture = UITapGestureRecognizer(target: nil, action: nil)
        tapGesture.requiresExclusiveTouchType = false
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = KeyboardDismissDelegate.shared
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.addGestureRecognizer(tapGesture) }
    }
}

// Global tap-to-dismiss keyboard
class KeyboardDismissDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't dismiss if tapping on a text input
        let isInput = touch.view is UITextField || touch.view is UITextView
        if !isInput {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        return false // never block the touch
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

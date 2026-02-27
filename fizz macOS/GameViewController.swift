//
//  GameViewController.swift
//  fizz macOS
//

import Cocoa
import SwiftUI

class GameViewController: NSViewController {

    override func loadView() {
        // Replace the storyboard SKView with a SwiftUI hosting view.
        // ContentView → SpriteView carries the full game scene.
        let hosting = NSHostingView(rootView: ContentView())
        hosting.frame = NSRect(x: 0, y: 0, width: 390, height: 844)
        self.view = hosting
    }
}

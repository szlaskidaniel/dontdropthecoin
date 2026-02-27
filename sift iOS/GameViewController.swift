//
//  GameViewController.swift
//  fizz iOS
//

import UIKit
import SwiftUI

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Embed the SwiftUI ContentView (which owns SpriteView + HUD + ViewModel).
        let host = UIHostingController(rootView: ContentView())
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .allButUpsideDown : .all
    }

    override var prefersStatusBarHidden: Bool { true }
}

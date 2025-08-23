//
//  GameViewController.swift
//  ProductorConsumidor iOS
//
//  Created by Diego on 23/8/25.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Asegura que la vista sea un SKView; si no, la reemplaza por una.
        let skView: SKView
        if let v = self.view as? SKView {
            skView = v
        } else {
            let v = SKView(frame: view.bounds)
            v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view = v
            skView = v
        }

        // Crea la escena con el tamaño actual del SKView
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill

        // Presenta la escena
        skView.presentScene(scene)

        // Depuración
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    // Ajusta el tamaño de la escena cuando cambie el layout (rotación, split view, etc.)
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let skView = self.view as? SKView,
           let scene = skView.scene {
            scene.size = skView.bounds.size
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
}

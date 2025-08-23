//
//  HudButton.swift
//  ProductorConsumidor
//
//  Created by Diego on 23/8/25.
//


//
//  HudButton.swift
//  PrototipoSO
//
//  Created by Diego on 20/8/25.
//


// HudButton.swift
import SpriteKit

final class HudButton {
    let node: SKNode
    let action: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.action = action
        let bg = SKShapeNode(rectOf: CGSize(width: 78, height: 30), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0.18, alpha: 1)
        bg.strokeColor = .white
        bg.lineWidth = 1.5

        let lb = SKLabelNode(fontNamed: "Menlo")
        lb.text = title
        lb.fontSize = 12
        lb.fontColor = .white
        lb.position = .zero

        bg.addChild(lb)
        self.node = bg
    }

    // helper para cambiar título (sin exponer nodos afuera)
    func setTitle(_ text: String) {
        (node as? SKShapeNode)?
            .children
            .compactMap { $0 as? SKLabelNode }
            .first?
            .text = text
    }
}

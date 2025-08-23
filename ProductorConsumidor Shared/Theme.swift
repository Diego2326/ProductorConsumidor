//
//  Theme.swift
//  ProductorConsumidor
//
//  Created by Diego on 23/8/25.
//


import SpriteKit

// === Tema & Utils ===
struct Theme {
    static let bgTop      = SKColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
    static let bgBottom   = SKColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1)
    static let panelFill  = SKColor(white: 1.0, alpha: 0.06)
    static let panelStroke = SKColor(white: 1.0, alpha: 0.15)
    static let slotEmpty  = SKColor(white: 0.28, alpha: 1)
    static let slotStroke = SKColor(white: 1.0, alpha: 0.22)
    static let text       = SKColor(white: 0.95, alpha: 1)
    static let machine    = SKColor.systemGreen
    static let itemPalette: [SKColor] = [
        .systemOrange, .systemPink, .systemTeal, .systemYellow,
        .systemPurple, .systemBlue, .systemRed, .systemGreen
    ]
}

extension SKNode {
    /// Sombra suave duplicando la forma en un SKEffectNode
    func addSoftShadow(offset: CGPoint = CGPoint(x: 0, y: -2),
                       radius: CGFloat = 3,
                       alpha: CGFloat = 0.45) {
        let effect = SKEffectNode()
        effect.shouldRasterize = true
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(radius, forKey: kCIInputRadiusKey)
            effect.filter = blur
        }
        let shadow = self.copy() as! SKNode
        shadow.alpha = alpha
        shadow.position = offset
        shadow.zPosition = (self.zPosition - 1)
        effect.addChild(shadow)
        self.parent?.addChild(effect)
    }
}

//
//  Employee.swift
//  ProductorConsumidor
//
//  Created by Diego on 23/8/25.
//


//
//  Employee.swift
//  PrototipoSO
//
//  Created by Diego on 20/8/25.
//


// Employee.swift
import SpriteKit

final class Employee {
    enum State { case idle, movingToPickup, carrying, returning }
    let node: SKShapeNode = SKShapeNode(circleOfRadius: 16)
    var state: State = .idle
    var carryingId: Int?

    init() {
        node.fillColor = .systemBlue
        node.strokeColor = .clear
    }

    func move(to: CGPoint, duration: TimeInterval) {
        node.run(SKAction.move(to: to, duration: duration))
    }
}

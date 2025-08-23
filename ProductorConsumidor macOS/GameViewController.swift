#if os(macOS)
import Cocoa
import SpriteKit

final class GameViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // La vista del VC debe ser un SKView (configúrala en Interface Builder).
        guard let skView = self.view as? SKView else {
            assertionFailure("La vista no es SKView. Marca la vista del ViewController como SKView.")
            return
        }

        // Crear la escena con el tamaño del SKView
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill

        // Presentar la escena
        skView.presentScene(scene)

        // Depuración
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    // Mantener la escena ajustada cuando cambie el tamaño de la ventana
    override func viewDidLayout() {
        super.viewDidLayout()
        if let skView = self.view as? SKView, let scene = skView.scene {
            scene.size = skView.bounds.size
        }
    }
}
#endif

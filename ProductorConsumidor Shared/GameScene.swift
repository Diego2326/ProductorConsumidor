// GameScene.swift
import SpriteKit
#if os(macOS)
import AppKit
#endif

actor Lock { func withLock<T>(_ body: () async -> T) async -> T { await body() } }

final class GameScene: SKScene {

    // MARK: - Init
    override init(size: CGSize) {
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // ======= macOS: teclado =======
    #if os(macOS)
    override var acceptsFirstResponder: Bool { true }
    #endif

    // ======= Modo =======
    private var mode: Mode = .employees

    // ======= Parámetros =======
    private var capacity = 8
    private var producerDelay: Double = 0.35   // ↓ más rápido
    private var beltTick: Double = 0.25        // ↓ más rápido
    private var employeeCount = 2

    // Límites
    private let minCapacity = 4,  maxCapacity = 30
    private let minEmployees = 1, maxEmployees = 10
    private let minDelay = 0.03,  maxDelay = 1.80
    private let minBelt  = 0.03,  maxBelt  = 1.80
    
    // ======= Game Over con temporizador =======
    private var isGameOver = false
    private var gameOverLayer: SKNode?
    private var gameOverCountdownTask: Task<Void, Never>?
    private var countdownLabel: SKLabelNode?


    // ======= Estado lógico =======
    private var belt: [Int] = []        // -1 vacío, >=0 id
    private var nextId = 0
    private var producedTotal = 0
    private var consumedTotal = 0

    // ======= Nodos =======
    private var slotNodes: [SKShapeNode] = []
    private var slotLabels: [SKLabelNode] = []
    private var machineNode = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 10)
    private var employees: [Employee] = []

    // Diseño / fondo
    private var bgNode: SKSpriteNode?
    private var hudPanel: SKShapeNode?

    // HUD Info (multi-línea)
    private var infoPanel = SKShapeNode()
    private var infoContainer = SKNode()
    private var infoLines: [SKLabelNode] = []

    // Modo manual
    private var playerNode: SKShapeNode?
    private var carryingId: Int?
    private var playerHomeOffset: CGFloat { 90 }

    // HUD (controles)
    private var hudButtons: [HudButton] = []
    private var modeButton: HudButton?
    private var leftBtn: HudButton?
    private var rightBtn: HudButton?
    private var takeBtn: HudButton?
    #if os(macOS)
    private var shortcutsButton: HudButton?
    private var shortcutsPanel: SKShapeNode?
    #endif

    // ======= Concurrencia =======
    private var running = false
    private var producerTask: Task<Void, Never>?
    private var beltTask: Task<Void, Never>?
    private var employeeTasks: [Task<Void, Never>] = []
    private let lock = Lock()

    // ======= Helpers de color para shader =======
    private func colorVec(_ c: SKColor) -> (CGFloat, CGFloat, CGFloat) {
        #if os(macOS)
        let cc = c.usingColorSpace(.deviceRGB) ?? c
        return (cc.redComponent, cc.greenComponent, cc.blueComponent)
        #else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r,g,b)
        #endif
    }
    private func startGameOverCountdown() {
        // Si ya hay un countdown activo, no reiniciarlo
        guard gameOverCountdownTask == nil, !isGameOver else { return }
        guard gameOverCountdownTask == nil else { return }

        let countdown = SKLabelNode(fontNamed: "Menlo")
        countdown.fontSize = 22
        countdown.fontColor = .systemRed
        countdown.position = CGPoint(x: 0, y: -size.height/2 + 60)
        countdown.zPosition = 1500
        addChild(countdown)
        countdownLabel = countdown

        gameOverCountdownTask = Task { [weak self] in
            guard let self else { return }
            for sec in (1...5).reversed() {
                await MainActor.run { self.countdownLabel?.text = "¡Cinta llena! Game Over en \(sec)..." }
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                // Si ya no está saturada o se reseteó, cancelar
                if !self.beltIsFull() {
                    await MainActor.run {
                        self.countdownLabel?.removeFromParent()
                        self.countdownLabel = nil
                    }
                    self.gameOverCountdownTask = nil
                    return
                }
            }
            // Se acabó el tiempo y sigue llena → Game Over
            await MainActor.run {
                self.countdownLabel?.removeFromParent()
                self.countdownLabel = nil
                self.showGameOver()
            }
            self.gameOverCountdownTask = nil
        }
    }
    private func beltIsFull() -> Bool {
        return !belt.contains(-1)
    }
    private func showGameOver() {
        guard !isGameOver else { return }
        isGameOver = true

        // Para todo
        pauseSim()

        // Capa oscura
        let layer = SKNode()
        layer.zPosition = 2000

        let dim = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: size.height + 4))
        dim.fillColor = SKColor(white: 0, alpha: 0.55)
        dim.strokeColor = .clear
        dim.zPosition = 0
        layer.addChild(dim)

        // Panel
        let panel = SKShapeNode(rectOf: CGSize(width: min(size.width - 60, 520), height: 220), cornerRadius: 18)
        panel.fillColor = Theme.panelFill
        panel.strokeColor = Theme.panelStroke
        panel.lineWidth = 1
        panel.zPosition = 1
        panel.position = .zero
        layer.addChild(panel)

        let title = SKLabelNode(fontNamed: "Menlo")
        title.text = "GAME OVER"
        title.fontSize = 28
        title.fontColor = .systemRed
        title.position = CGPoint(x: 0, y: 50)
        title.zPosition = 2
        layer.addChild(title)

        let msg = SKLabelNode(fontNamed: "Menlo")
        msg.text = "La cinta estuvo llena por demasiado tiempo."
        msg.fontSize = 14
        msg.fontColor = Theme.text
        msg.position = CGPoint(x: 0, y: 15)
        msg.zPosition = 2
        layer.addChild(msg)

        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = "Toca/clic para reiniciar"
        hint.fontSize = 13
        hint.fontColor = Theme.text.withAlphaComponent(0.9)
        hint.position = CGPoint(x: 0, y: -22)
        hint.zPosition = 2
        layer.addChild(hint)

        addChild(layer)
        gameOverLayer = layer

        // Efecto de entrada
        layer.setScale(0.92)
        layer.run(.scale(to: 1.0, duration: 0.16))
    }

    private func hideGameOver() {
        isGameOver = false
        gameOverLayer?.removeFromParent()
        gameOverLayer = nil
    }

    // ======= Layout helpers =======
    private func slotPosition(index: Int) -> CGPoint {
        let spacing: CGFloat = 46
        let totalWidth = CGFloat(capacity - 1) * spacing
        let originX = -totalWidth / 2
        return CGPoint(x: originX + CGFloat(index) * spacing, y: 40)
    }

    // Rejilla para separar empleados (3 columnas)
    private func employeeBasePosition(index: Int) -> CGPoint {
        let lastX = slotPosition(index: capacity - 1).x
        let cols = 3
        let spacingX: CGFloat = 28
        let spacingY: CGFloat = 24
        let col = index % cols
        let row = index / cols
        return CGPoint(x: lastX + 80 + CGFloat(col) * spacingX,
                       y: -40 - CGFloat(row) * spacingY)
    }

    // ======= Ciclo de vida =======
    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        addBackgroundGradient()
        addHudPanel()
        configureScene()
        configureInfoPanel()
        rebuildBelt(keepPaused: true)
        renderAll()

        #if os(macOS)
        self.view?.window?.makeFirstResponder(self)
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Reajusta fondo y HUD al redimensionar
        bgNode?.size = size
        hudPanel?.position = CGPoint(x: 0, y: size.height * 0.5 - (hudPanel?.frame.height ?? 140)/2 - 20)
        let h: CGFloat = infoPanel.frame.height
        infoPanel.position = CGPoint(x: 0, y: size.height * 0.5 - h/2 - 20)
    }

    // ======= Fondo y panel =======
    private func addBackgroundGradient() {
        bgNode?.removeFromParent()
        let node = SKSpriteNode(color: .black, size: size)
        node.zPosition = -1000
        node.position = .zero
        node.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Shader de gradiente vertical
        let (rt, gt, bt) = colorVec(Theme.bgTop)
        let (rb, gb, bb) = colorVec(Theme.bgBottom)
        let src = """
        void main() {
            vec2 uv = v_tex_coord;
            vec4 top = vec4(\(rt), \(gt), \(bt), 1.0);
            vec4 bot = vec4(\(rb), \(gb), \(bb), 1.0);
            gl_FragColor = mix(bot, top, uv.y);
        }
        """
        node.shader = SKShader(source: src)
        addChild(node)
        bgNode = node
    }

    private func addHudPanel() {
        hudPanel?.removeFromParent()
        let w = min(size.width - 40, 700)
        let h: CGFloat = 140
        let panel = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 18)
        panel.fillColor = Theme.panelFill
        panel.strokeColor = Theme.panelStroke
        panel.lineWidth = 1.0
        panel.position = CGPoint(x: 0, y: size.height * 0.5 - h/2 - 20)
        panel.zPosition = -10
        addChild(panel)
        hudPanel = panel
        panel.addSoftShadow(offset: CGPoint(x: 0, y: -4), radius: 4, alpha: 0.35)
    }

    private func configureScene() {
        // Máquina
        machineNode.fillColor = Theme.machine
        machineNode.strokeColor = .clear
        machineNode.zPosition = 20
        addChild(machineNode)

        makeHud()
        updateManualHudVisibility()
    }

    // ======= Panel de Info (4 líneas centradas) =======
    private func configureInfoPanel() {
        infoPanel.removeFromParent()
        let w: CGFloat = min(size.width - 40, 720)
        let h: CGFloat = 112
        infoPanel = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 18)
        infoPanel.fillColor = Theme.panelFill
        infoPanel.strokeColor = Theme.panelStroke
        infoPanel.lineWidth = 1
        infoPanel.position = CGPoint(x: 0, y: size.height * 0.5 - h/2 - 20)
        infoPanel.zPosition = -5
        addChild(infoPanel)
        infoPanel.addSoftShadow(offset: CGPoint(x: 0, y: -4), radius: 4, alpha: 0.35)

        // Contenedor
        infoContainer.removeAllChildren()
        infoContainer.position = .zero
        infoPanel.addChild(infoContainer)

        // Crear 4 labels Menlo centrados
        infoLines = (0..<4).map { _ in
            let l = SKLabelNode(fontNamed: "Menlo")
            l.fontSize = 13
            l.fontColor = Theme.text
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .center
            return l
        }

        // Layout vertical
        let spacing: CGFloat = 24
        let startY: CGFloat = spacing * 1.5
        for (i, l) in infoLines.enumerated() {
            l.position = CGPoint(x: 0, y: startY - CGFloat(i) * spacing)
            infoContainer.addChild(l)
        }
    }

    // ======= Construcción =======
    private func rebuildBelt(keepPaused: Bool) {
        slotNodes.forEach { $0.removeFromParent() }
        slotNodes.removeAll()
        slotLabels.removeAll()

        belt = Array(repeating: -1, count: capacity)

        for i in 0..<capacity {
            let box = SKShapeNode(rectOf: CGSize(width: 42, height: 42), cornerRadius: 10)
            box.strokeColor = Theme.slotStroke
            box.lineWidth = 1.5
            box.fillColor = Theme.slotEmpty
            box.position = slotPosition(index: i)
            box.zPosition = 10

            let lbl = SKLabelNode(fontNamed: "Menlo")
            lbl.fontSize = 12
            lbl.fontColor = Theme.text
            lbl.position = .zero
            lbl.verticalAlignmentMode = .center
            lbl.horizontalAlignmentMode = .center
            box.addChild(lbl)

            addChild(box)
            slotNodes.append(box); slotLabels.append(lbl)

            // Sombra sutil
            box.addSoftShadow(offset: CGPoint(x: 0, y: -1.5), radius: 2.5, alpha: 0.30)
        }

        machineNode.position = CGPoint(x: slotPosition(index: 0).x, y: 110)

        // limpiar consumidores
        employees.forEach { $0.node.removeFromParent() }
        employees.removeAll()
        playerNode?.removeFromParent(); playerNode = nil; carryingId = nil

        switch mode {
        case .employees:
            for i in 0..<employeeCount {
                let e = Employee()
                e.node.position = employeeBasePosition(index: i)
                addChild(e.node); employees.append(e)
            }
        case .manual:
            makePlayer()
        }

        if !keepPaused { renderAll() }
    }

    // ======= HUD (botones) =======
    private func makeHud() {
        func addButton(title: String, pos: CGPoint, store: inout HudButton?, action: @escaping () -> Void) {
            let b = HudButton(title: title, action: action)
            b.node.position = pos
            addChild(b.node)
            hudButtons.append(b)
            store = b
        }
        func addButton(title: String, pos: CGPoint, action: @escaping () -> Void) {
            var tmp: HudButton?
            addButton(title: title, pos: pos, store: &tmp, action: action)
        }

        let yTop: CGFloat = 280, yBot: CGFloat = 240, dx: CGFloat = 90

        // Fila superior
        var x: CGFloat = -225
        addButton(title: "Prod -", pos: CGPoint(x: x, y: yTop)) { [weak self] in
            guard let self else { return }
            self.producerDelay = min(self.maxDelay, self.producerDelay + 0.05)
            self.renderAll()
        }; x += dx
        addButton(title: "Prod +", pos: CGPoint(x: x, y: yTop)) { [weak self] in
            guard let self else { return }
            self.producerDelay = max(self.minDelay, self.producerDelay - 0.05)
            self.renderAll()
        }; x += dx * 1.4
        addButton(title: "Belt -", pos: CGPoint(x: x, y: yTop)) { [weak self] in
            guard let self else { return }
            self.beltTick = min(self.maxBelt, self.beltTick + 0.05)
            self.restartBeltIfRunning(); self.renderAll()
        }; x += dx
        addButton(title: "Belt +", pos: CGPoint(x: x, y: yTop)) { [weak self] in
            guard let self else { return }
            self.beltTick = max(self.minBelt, self.beltTick - 0.05)
            self.restartBeltIfRunning(); self.renderAll()
        }

        // Fila inferior
        x = -225
        addButton(title: "Emp -", pos: CGPoint(x: x, y: yBot)) { [weak self] in
            guard let self else { return }
            self.employeeCount = max(self.minEmployees, self.employeeCount - 1)
            if self.mode == .employees {
                self.rebuildBelt(keepPaused: true); self.renderAll()
                if self.running { self.restartEmployees() }
            }
        }; x += dx
        addButton(title: "Emp +", pos: CGPoint(x: x, y: yBot)) { [weak self] in
            guard let self else { return }
            self.employeeCount = min(self.maxEmployees, self.employeeCount + 1)
            if self.mode == .employees {
                self.rebuildBelt(keepPaused: true); self.renderAll()
                if self.running { self.restartEmployees() }
            }
        }; x += dx * 0.9
        addButton(title: "Cap -", pos: CGPoint(x: x, y: yBot)) { [weak self] in
            guard let self, !self.running else { return }
            let newCap = max(self.minCapacity, self.capacity - 1)
            if newCap != self.capacity { self.capacity = newCap; self.rebuildBelt(keepPaused: true); self.renderAll() }
        }; x += dx
        addButton(title: "Cap +", pos: CGPoint(x: x, y: yBot)) { [weak self] in
            guard let self, !self.running else { return }
            let newCap = min(self.maxCapacity, self.capacity + 1)
            if newCap != self.capacity { self.capacity = newCap; self.rebuildBelt(keepPaused: true); self.renderAll() }
        }; x += dx * 0.9
        addButton(title: "Modo: \(mode.text)", pos: CGPoint(x: x, y: yBot), store: &modeButton) { [weak self] in
            self?.toggleMode()
        }

        // Controles manuales (solo visibles en .manual)
        addButton(title: "◀︎", pos: CGPoint(x: x + 90, y: yBot), store: &leftBtn) { [weak self] in
            guard let self = self, self.mode == .manual else { return }
            self.movePlayer(dx: -20)
        }
        addButton(title: "▶︎", pos: CGPoint(x: x + 130, y: yBot), store: &rightBtn) { [weak self] in
            guard let self = self, self.mode == .manual else { return }
            self.movePlayer(dx: 20)
        }
        addButton(title: "Tomar", pos: CGPoint(x: x + 200, y: yBot), store: &takeBtn) { [weak self] in
            guard let self = self, self.mode == .manual else { return }
            self.playerTakeIfPossible()
        }

        #if os(macOS)
        let help = HudButton(title: "Atajos ⌘/", action: { [weak self] in self?.toggleShortcutsPanel() })
        help.node.position = CGPoint(x: 300, y: yTop)
        addChild(help.node); hudButtons.append(help); self.shortcutsButton = help
        #endif
    }

    private func updateManualHudVisibility() {
        let manual = (mode == .manual)
        leftBtn?.node.isHidden = !manual
        rightBtn?.node.isHidden = !manual
        takeBtn?.node.isHidden = !manual
    }

    private func updateModeButtonTitle() {
        modeButton?.setTitle("Modo: \(mode.text)")
    }

    private func makePlayer() {
        let node = SKShapeNode(circleOfRadius: 18)
        node.fillColor = .systemTeal
        node.strokeColor = .white
        node.lineWidth = 2
        node.position = CGPoint(x: slotPosition(index: capacity - 1).x + playerHomeOffset, y: -40)
        addChild(node); playerNode = node
    }

    // ======= Input =======
    #if os(iOS)
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let loc = t.location(in: self)
        for b in hudButtons where b.node.contains(loc) { b.action(); return }
        if t.tapCount == 2 { resetAll() } else { toggleRun() }
    }
    #elseif os(macOS)
    override func mouseUp(with event: NSEvent) {
        let loc = event.location(in: self)
        for b in hudButtons where b.node.contains(loc) { b.action(); return }
        if event.clickCount == 2 { resetAll() } else { toggleRun() }
    }
    #endif

    // ======= Render (con color por ID y efecto “pop”) =======
    private func renderAll() {
        // Colorea slots
        for i in 0..<capacity {
            let wasEmpty = (slotLabels[i].text ?? "").isEmpty
            let filled = belt[i] >= 0

            if filled {
                let id = belt[i]
                let color = Theme.itemPalette[(max(0, id)) % Theme.itemPalette.count]
                slotNodes[i].fillColor = color.withAlphaComponent(0.92)
                slotLabels[i].text = "\(id)"

                if wasEmpty {
                    let pop = SKAction.sequence([
                        .scale(to: 1.06, duration: 0.08),
                        .scale(to: 1.00, duration: 0.10)
                    ])
                    slotNodes[i].run(pop)
                }
            } else {
                slotNodes[i].fillColor = Theme.slotEmpty
                slotLabels[i].text = ""
            }
        }

        // Texto del panel
        let rate = String(format: "%.2f", 1.0 / max(producerDelay, 0.001))
        let beltStr = String(format: "%.2fs", beltTick)

        let l1 = "Modo: \(mode.text)   ·   Capacidad: \(capacity)   ·   Empleados: \(employeeCount)"
        let l2 = "Máquina: \(rate) it/s   ·   Cinta: \(beltStr)"
        let l3 = "Producidos: \(producedTotal)   ·   Consumidos: \(consumedTotal)"
        let l4 = "Tap/clic: iniciar/pausar   ·   Doble tap/clic: reset   ·   Capacidad solo en pausa"

        if infoLines.count >= 4 {
            infoLines[0].text = l1
            infoLines[1].text = l2
            infoLines[2].text = l3
            infoLines[3].text = l4
        }
    }

    // ======= Simulación =======
    @objc private func toggleRun() { running ? pauseSim() : startSim() }

    @objc private func resetAll() {
        pauseSim()
        nextId = 0; producedTotal = 0; consumedTotal = 0
        hideGameOver()
        gameOverCountdownTask?.cancel()
        gameOverCountdownTask = nil
        countdownLabel?.removeFromParent()
        countdownLabel = nil

        rebuildBelt(keepPaused: true); renderAll()
    }

    private func startSim() {
        guard !running else { return }
        running = true
        startProducer(); startBelt()
        if mode == .employees { startEmployees() }
    }

    private func pauseSim() {
        running = false
        producerTask?.cancel(); producerTask = nil
        beltTask?.cancel(); beltTask = nil
        employeeTasks.forEach { $0.cancel() }; employeeTasks.removeAll()
        employees.forEach { $0.state = .idle }
    }

    // Avance de cinta 1 paso (se llama dentro del lock)
    private func advanceBeltOneStepUnsafe() {
        var moved = false
        for i in stride(from: capacity - 2, through: 0, by: -1) {
            if belt[i] >= 0 && belt[i + 1] == -1 {
                belt[i + 1] = belt[i]; belt[i] = -1
                let box = slotNodes[i + 1]
                box.run(SKAction.sequence([.scale(to: 1.04, duration: 0.06),
                                           .scale(to: 1.0, duration: 0.06)]))
                moved = true
            }
        }
        if moved { renderAll() }
        if !beltIsFull() {
            // Si se liberó espacio cancela countdown
            gameOverCountdownTask?.cancel()
            gameOverCountdownTask = nil
            countdownLabel?.removeFromParent()
            countdownLabel = nil
        }
        if !beltIsFull() {
            gameOverCountdownTask?.cancel()
            gameOverCountdownTask = nil
            countdownLabel?.removeFromParent()
            countdownLabel = nil
        }

    }

    private func startProducer() {
        producerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.producerDelay * 1_000_000_000))
                await self.lock.withLock {
                    // Avance previo de cinta
                    self.advanceBeltOneStepUnsafe()

                    // Si está en Game Over, no hacer nada más
                    guard !self.isGameOver else { return }

                    // Si la cinta quedó llena, arranca countdown (si no existe)
                    if self.beltIsFull() {
                        self.startGameOverCountdown()
                        return
                    }

                    // Producir si hay hueco en la cabeza
                    if self.belt[0] == -1 {
                        let id = self.nextId; self.nextId += 1
                        self.belt[0] = id
                        self.producedTotal += 1
                        self.machineBlink()
                        self.renderAll()
                    }
                }
            }
        }
    }


    private func machineBlink() {
        let s = SKAction.sequence([
            .group([ .scale(to: 1.08, duration: 0.06), .fadeAlpha(to: 1.0, duration: 0.06) ]),
            .scale(to: 1.0, duration: 0.10)
        ])
        machineNode.run(s)
    }

    private func startBelt() {
        beltTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.beltTick * 1_000_000_000))
                await self.lock.withLock { self.advanceBeltOneStepUnsafe() }
            }
        }
    }

    private func restartBeltIfRunning() {
        if running { beltTask?.cancel(); startBelt() }
    }

    // ======= Empleados =======
    private func restartEmployees() {
        guard mode == .employees, running else { return }
        startEmployees()
    }

    private func startEmployees() {
        employeeTasks.forEach { $0.cancel() }; employeeTasks.removeAll()

        for (i, e) in employees.enumerated() {
            e.state = .idle; e.node.removeAllActions()
            e.node.position = employeeBasePosition(index: i)
        }

        for idx in 0..<employees.count {
            let task = Task { [weak self] in
                guard let self else { return }
                let me = self.employees[idx]
                while !Task.isCancelled && self.mode == .employees {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    await self.lock.withLock {
                        switch me.state {
                        case .idle:
                            if self.belt[self.capacity - 1] >= 0 {
                                me.state = .movingToPickup
                                me.move(to: self.slotNodes[self.capacity - 1].position, duration: 0.16)
                            }
                        case .movingToPickup:
                            if self.belt[self.capacity - 1] >= 0 {
                                let id = self.belt[self.capacity - 1]; self.belt[self.capacity - 1] = -1
                                me.carryingId = id; me.state = .carrying
                                me.move(to: CGPoint(x: self.slotPosition(index: self.capacity - 1).x + 120, y: -40), duration: 0.20)
                                self.consumedTotal += 1; self.renderAll()
                            } else {
                                me.state = .idle
                            }
                        case .carrying:
                            me.carryingId = nil; me.state = .returning
                            me.move(to: self.employeeBasePosition(index: idx), duration: 0.18)
                        case .returning:
                            me.state = .idle
                        }
                    }
                }
            }
            employeeTasks.append(task)
        }
    }

    // ======= Modo Manual =======
    private func movePlayer(dx: CGFloat) {
        guard let player = playerNode else { return }
        let minX = slotPosition(index: capacity - 1).x + playerHomeOffset - 120
        let maxX = slotPosition(index: capacity - 1).x + playerHomeOffset + 120
        let nx = max(minX, min(maxX, player.position.x + dx))
        player.run(SKAction.move(to: CGPoint(x: nx, y: player.position.y), duration: 0.08))
    }

    private func playerTakeIfPossible() {
        if belt[capacity - 1] >= 0 {
            let id = belt[capacity - 1]; belt[capacity - 1] = -1
            carryingId = id; consumedTotal += 1; renderAll()
            if let player = playerNode {
                let out = CGPoint(x: player.position.x + 60, y: player.position.y)
                let move = SKAction.move(to: out, duration: 0.2)
                let back = SKAction.move(to: CGPoint(x: slotPosition(index: capacity - 1).x + playerHomeOffset, y: -40), duration: 0.2)
                player.run(SKAction.sequence([move, back]))
            }
            carryingId = nil
        }
    }

    private func toggleMode() {
        employeeTasks.forEach { $0.cancel() }; employeeTasks.removeAll()
        switch mode {
        case .employees:
            mode = .manual
            employees.forEach { $0.node.removeFromParent() }; employees.removeAll()
            makePlayer()
        case .manual:
            mode = .employees
            playerNode?.removeFromParent(); playerNode = nil; carryingId = nil
            for i in 0..<employeeCount {
                let e = Employee(); e.node.position = employeeBasePosition(index: i)
                addChild(e.node); employees.append(e)
            }
            if running { restartEmployees() }
        }
        updateModeButtonTitle(); updateManualHudVisibility(); renderAll()
    }

    // ======= Atajos macOS =======
    #if os(macOS)
    private func toggleShortcutsPanel() {
        if let panel = shortcutsPanel { panel.removeFromParent(); shortcutsPanel = nil; return }
        let w: CGFloat = 460, h: CGFloat = 280
        let panel = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 12)
        panel.zPosition = 999
        panel.fillColor = SKColor(white: 0.12, alpha: 0.95)
        panel.strokeColor = .white; panel.lineWidth = 1.5; panel.position = .zero

        let title = SKLabelNode(fontNamed: "Menlo")
        title.text = "Atajos (macOS)"; title.fontSize = 16; title.fontColor = .white
        title.position = CGPoint(x: 0, y: h/2 - 32); panel.addChild(title)

        let lines = [
            "Espacio: Iniciar/Pausar     ·     R: Reset     ·     M: Cambiar modo",
            "Q/E o Q/W: Prod – / Prod + (velocidad productor)",
            "A/S: Belt – / Belt + (velocidad cinta)",
            "Z/X: Empleados – / +",
            "[ / ]: Capacidad – / +  (solo en pausa)",
            "Modo Manual: A/D mover, Espacio tomar del final",
            "⌘/: Mostrar/Ocultar este panel"
        ]
        var y = title.position.y - 28
        for line in lines {
            let l = SKLabelNode(fontNamed: "Menlo"); l.text = line; l.fontSize = 13; l.fontColor = .white
            l.horizontalAlignmentMode = .center; l.position = CGPoint(x: 0, y: y); panel.addChild(l); y -= 22
        }
        addChild(panel); shortcutsPanel = panel
    }

    override func keyDown(with event: NSEvent) {
        guard let raw = event.charactersIgnoringModifiers, raw.count > 0 else { return }
        let ch = raw.lowercased()

        // Manual first
        if mode == .manual {
            switch ch {
            case "a": movePlayer(dx: -20)
            case "d": movePlayer(dx: 20)
            case " ": playerTakeIfPossible()
            case "m": toggleMode()
            default: break
            }
            return
        }

        switch ch {
        case " ": toggleRun()
        case "r": resetAll()
        case "m": toggleMode()
        case "q": producerDelay = min(maxDelay, producerDelay + 0.05); renderAll()
        case "e", "w": producerDelay = max(minDelay, producerDelay - 0.05); renderAll()
        case "a": beltTick = min(maxBelt, beltTick + 0.05); restartBeltIfRunning(); renderAll()
        case "s": beltTick = max(minBelt, beltTick - 0.05); restartBeltIfRunning(); renderAll()
        case "z":
            employeeCount = max(minEmployees, employeeCount - 1)
            if mode == .employees { rebuildBelt(keepPaused: true); renderAll(); if running { restartEmployees() } }
        case "x":
            employeeCount = min(maxEmployees, employeeCount + 1)
            if mode == .employees { rebuildBelt(keepPaused: true); renderAll(); if running { restartEmployees() } }
        case "[": guard !running else { break }
            let nL = max(minCapacity, capacity - 1); if nL != capacity { capacity = nL; rebuildBelt(keepPaused: true); renderAll() }
        case "]": guard !running else { break }
            let nR = min(maxCapacity, capacity + 1); if nR != capacity { capacity = nR; rebuildBelt(keepPaused: true); renderAll() }
        case "/": if event.modifierFlags.contains(.command) { toggleShortcutsPanel() }
        default: break
        }
    }
    #endif
}

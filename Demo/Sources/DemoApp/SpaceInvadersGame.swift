import Foundation
import SwiftGodot
import SwiftGodotPatterns

@Godot
final class SpaceInvadersGame: Node2D {
  override func _ready() {
    let rootNode = SpaceInvadersGameView().toNode()
    addChild(node: rootNode)
  }
}

struct SpaceInvadersThemes {
  let score = Theme([
    "Label": [
      "fontSizes": ["fontSize": 20],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let message = Theme([
    "Label": [
      "fontSizes": ["fontSize": 24],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let gameOver = Theme([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color.red],
    ],
  ])

  let victory = Theme([
    "Label": [
      "fontSizes": ["fontSize": 36],
      "colors": ["fontColor": Color.green],
    ],
  ])
}

enum EnemyType {
  case squid
  case crab
  case octopus

  var sprite: String {
    switch self {
    case .squid: return "squid.png"
    case .crab: return "crab.png"
    case .octopus: return "octopus.png"
    }
  }

  var points: Int {
    switch self {
    case .squid: return 30
    case .crab: return 20
    case .octopus: return 10
    }
  }
}

struct Enemy: Identifiable, Equatable {
  let id: Int
  var position: Vector2
  let type: EnemyType
  var alive: Bool = true
}

struct Bullet: Identifiable, Equatable {
  let id: UUID = .init()
  var position: Vector2
  var velocity: Vector2
  var isPlayerBullet: Bool
}

struct Barrier: Identifiable, Equatable {
  let id: Int
  var position: Vector2
  var health: Int
  var maxHealth: Int = 4
}

struct SpaceInvadersGameView: GView {
  let screenWidth: Float = 800
  let screenHeight: Float = 600
  let playerWidth: Float = 40
  let playerHeight: Float = 30
  let playerSpeed: Float = 400
  let bulletSpeed: Float = 500
  let enemyWidth: Float = 32
  let enemyHeight: Float = 24
  let enemyRows = 5
  let enemyCols = 11
  let enemySpacingX: Float = 48
  let enemySpacingY: Float = 40
  let barrierWidth: Float = 60
  let barrierHeight: Float = 40
  let themes = SpaceInvadersThemes()

  @State var playerX: Float = 380
  @State var bullets: [Bullet] = []
  @State var enemies: [Enemy] = []
  @State var barriers: [Barrier] = []
  @State var score = 0
  @State var lives = 3
  @State var gameStarted = false
  @State var gameOver = false
  @State var victory = false
  @State var wave = 1
  @State var enemyDirection: Float = 1
  @State var enemySpeed: Float = 30
  @State var enemyMoveTimer: Double = 0
  @State var enemyShootTimer: Double = 0
  @State var canShoot = true

  var body: some GView {
    Node2D$ {
      // Background
      CanvasLayer$ {
        ColorRect$()
          .color(Color(r: 0.0, g: 0.0, b: 0.1))
          .customMinimumSize([screenWidth, screenHeight])
      }
      .layer(-1)

      // Player ship
      Area2D$ {
        Sprite2D$()
          .res(\.texture, "player.png")

        CollisionShape2D$()
          .shape(RectangleShape2D(size: [playerWidth, playerHeight]))
      }
      .bind(\.position, to: $playerX) { x in
        [x, screenHeight - 60]
      }
      .collisionLayer(.alpha)
      .collisionMask(.delta)
      .onSignal(\.areaEntered) { _, area in
        guard let area = area else { return }
        // Hit by enemy bullet
        lives -= 1
        if lives <= 0 {
          gameOver = true
        }
        // Remove the bullet from array
        if let bulletId = UUID(uuidString: String(area.name)) {
          bullets.removeAll { $0.id == bulletId }
        }
      }

      // Enemies
      ForEach($enemies, mode: .deferred) { enemy in
        Area2D$ {
          Sprite2D$()
            .res(\.texture, enemy.wrappedValue.type.sprite)

          CollisionShape2D$()
            .shape(RectangleShape2D(size: [enemyWidth, enemyHeight]))
        }
        .bind(\.position, to: enemy, \.position)
        .bind(\.visible, to: enemy, \.alive)
        .collisionLayer(.beta)
        .collisionMask(.gamma)
        .onSignal(\.areaEntered) { _, area in
          guard let area = area else { return }
          guard enemy.wrappedValue.alive else { return }

          // Hit by player bullet
          let enemyId = enemy.wrappedValue.id
          if let index = enemies.firstIndex(where: { $0.id == enemyId }) {
            enemies[index].alive = false
            score += enemies[index].type.points
          }

          // Remove the bullet from array
          if let bulletId = UUID(uuidString: String(area.name)) {
            bullets.removeAll { $0.id == bulletId }
          }

          // Check victory
          if !enemies.contains(where: { $0.alive }) {
            victory = true
          }
        }
      }

      // Bullets
      ForEach($bullets, mode: .deferred) { bullet in
        Area2D$(bullet.wrappedValue.id.uuidString) {
          Sprite2D$()
            .res(\.texture, bullet.wrappedValue.isPlayerBullet ? "bullet.png" : "enemy_bullet.png")

          CollisionShape2D$()
            .shape(RectangleShape2D(size: [4, 12]))
        }
        .bind(\.position, to: bullet, \.position)
        .collisionLayer(bullet.wrappedValue.isPlayerBullet ? .gamma : .delta)
        .collisionMask(bullet.wrappedValue.isPlayerBullet ? [.beta, .epsilon] : [.alpha, .epsilon])
      }

      // Barriers
      ForEach($barriers, mode: .deferred) { barrier in
        Area2D$ {
          Polygon2D$()
            .bind(\.modulate, to: barrier) { b in
              Color(
                r: 0.2,
                g: 0.8,
                b: 0.2,
                a: Float(b.health) / Float(b.maxHealth)
              )
            }
            .polygon([
              [-barrierWidth / 2, -barrierHeight / 2],
              [barrierWidth / 2, -barrierHeight / 2],
              [barrierWidth / 2, barrierHeight / 2],
              [-barrierWidth / 2, barrierHeight / 2],
            ])

          CollisionShape2D$()
            .shape(RectangleShape2D(size: [barrierWidth, barrierHeight]))
        }
        .bind(\.position, to: barrier, \.position)
        .bind(\.visible, to: barrier) { $0.health > 0 }
        .collisionLayer(.epsilon)
        .collisionMask([.gamma, .delta])
        .onSignal(\.areaEntered) { _, area in
          guard let area = area else { return }

          // Hit by a bullet
          let barrierId = barrier.wrappedValue.id
          if let index = barriers.firstIndex(where: { $0.id == barrierId }) {
            barriers[index].health -= 1
            if barriers[index].health == 0 {
              // Barrier destroyed
              barriers.removeAll { $0.id == barrierId }
            }
          }

          // Remove the bullet from array
          if let bulletId = UUID(uuidString: String(area.name)) {
            bullets.removeAll { $0.id == bulletId }
          }
        }
      }

      // UI Overlay
      CanvasLayer$ {
        // Score
        Label$()
          .bind(\.text, to: $score) { "SCORE: \($0)" }
          .offsetLeft(20)
          .offsetTop(10)
          .theme(themes.score)

        // Lives
        Label$()
          .bind(\.text, to: $lives) { "LIVES: \($0)" }
          .offsetLeft(Double(screenWidth - 120))
          .offsetTop(10)
          .theme(themes.score)

        // Wave
        Label$()
          .bind(\.text, to: $wave) { "WAVE: \($0)" }
          .offsetLeft(Double(screenWidth / 2 - 40))
          .offsetTop(10)
          .theme(themes.score)

        // Start message
        Control$ {
          Label$()
            .text("SPACE INVADERS\n\nPress SPACE to start\nMove: A/D or Arrow Keys\nShoot: SPACE")
            .anchorsAndOffsets(.center)
            .horizontalAlignment(.center)
            .theme(themes.message)
        }
        .anchorsAndOffsets(.fullRect)
        .bind(\.visible, to: $gameStarted) { !$0 }

        // Game Over
        Control$ {
          Label$()
            .bind(\.text, to: $score) { "GAME OVER\n\nFinal Score: \($0)\n\nPress SPACE to restart" }
            .anchorsAndOffsets(.center)
            .horizontalAlignment(.center)
            .theme(themes.gameOver)
        }
        .anchorsAndOffsets(.fullRect)
        .visible($gameOver)

        // Victory
        Control$ {
          Label$()
            .text("WAVE CLEARED!\n\nPress SPACE for next wave")
            .anchorsAndOffsets(.center)
            .horizontalAlignment(.center)
            .theme(themes.victory)
        }
        .anchorsAndOffsets(.fullRect)
        .visible($victory)
      }
    }
    .onReady { _ in
      Actions {
        Action("move_left") {
          Key(.a)
          Key(.left)
        }

        Action("move_right") {
          Key(.d)
          Key(.right)
        }

        Action("shoot") {
          Key(.space)
        }
      }.install()

      initializeGame()
    }
    .onProcess { _, delta in
      handleInput(delta)

      if !gameStarted || gameOver || victory { return }

      updateBullets(delta)
      updateEnemies(delta)
      enemyShoot(delta)
    }
  }

  // MARK: - Initialization

  func initializeGame() {
    spawnEnemies()
    spawnBarriers()
  }

  func spawnEnemies() {
    enemies = []
    let startX = (screenWidth - Float(enemyCols) * enemySpacingX + enemySpacingX) / 2
    let startY: Float = 80

    var id = 0
    for row in 0 ..< enemyRows {
      let type: EnemyType = switch row {
      case 0: .squid
      case 1 ... 2: .crab
      default: .octopus
      }

      for col in 0 ..< enemyCols {
        let x = startX + Float(col) * enemySpacingX
        let y = startY + Float(row) * enemySpacingY

        enemies.append(Enemy(
          id: id,
          position: [x, y],
          type: type
        ))
        id += 1
      }
    }
  }

  func spawnBarriers() {
    barriers = []
    let spacing = screenWidth / 5
    for i in 0 ..< 4 {
      barriers.append(Barrier(
        id: i,
        position: [spacing * Float(i + 1) - barrierWidth / 2, screenHeight - 150],
        health: 4
      ))
    }
  }

  // MARK: - Input Handling

  func handleInput(_ delta: Double) {
    if Action("shoot").isJustPressed {
      if !gameStarted {
        gameStarted = true
      } else if gameOver {
        resetGame()
      } else if victory {
        nextWave()
      } else if canShoot {
        shootPlayerBullet()
      }
    }

    if !gameStarted || gameOver || victory { return }

    let moveSpeed = playerSpeed * Float(delta)

    if Action("move_left").isPressed {
      playerX = max(0, playerX - moveSpeed)
    }
    if Action("move_right").isPressed {
      playerX = min(screenWidth - playerWidth, playerX + moveSpeed)
    }
  }

  func shootPlayerBullet() {
    bullets.append(Bullet(
      position: [playerX + playerWidth / 2 - 2, screenHeight - 65],
      velocity: [0, -bulletSpeed],
      isPlayerBullet: true
    ))
    canShoot = false

    // Reset after short delay
    Engine.onNextFrame {
      Engine.onNextFrame {
        Engine.onNextFrame {
          canShoot = true
        }
      }
    }
  }

  // MARK: - Bullet Updates

  func updateBullets(_ delta: Double) {
    for i in stride(from: bullets.count - 1, through: 0, by: -1) {
      bullets[i].position = bullets[i].position + bullets[i].velocity * Float(delta)

      // Remove off-screen bullets
      if bullets[i].position.y < 0 || bullets[i].position.y > screenHeight {
        bullets.remove(at: i)
      }
    }
  }

  // MARK: - Enemy Updates

  func updateEnemies(_ delta: Double) {
    enemyMoveTimer += delta

    let moveInterval = max(0.3, 1.0 - Double(wave) * 0.1)

    if enemyMoveTimer >= moveInterval {
      enemyMoveTimer = 0
      moveEnemyFormation()
    }
  }

  func moveEnemyFormation() {
    var shouldDescend = false

    // Check if any enemy hit the edge
    for enemy in enemies where enemy.alive {
      let newX = enemy.position.x + enemySpeed * enemyDirection
      if newX < 0 || newX > screenWidth - enemyWidth {
        shouldDescend = true
        break
      }
    }

    if shouldDescend {
      // Reverse direction and move down
      enemyDirection *= -1
      for i in enemies.indices where enemies[i].alive {
        enemies[i].position.y += 20
      }
    } else {
      // Move horizontally
      for i in enemies.indices where enemies[i].alive {
        enemies[i].position.x += enemySpeed * enemyDirection
      }
    }

    // Check if enemies reached player
    for enemy in enemies where enemy.alive {
      if enemy.position.y + enemyHeight >= screenHeight - 60 {
        lives = 0
        gameOver = true
        return
      }
    }
  }

  func enemyShoot(_ delta: Double) {
    enemyShootTimer += delta

    let shootInterval = max(0.8, 2.0 - Double(wave) * 0.2)

    if enemyShootTimer >= shootInterval {
      enemyShootTimer = 0

      // Find bottom-most enemies in each column
      let aliveEnemies = enemies.filter { $0.alive }
      guard !aliveEnemies.isEmpty else { return }

      // Pick a random alive enemy
      if let shooter = aliveEnemies.randomElement() {
        bullets.append(Bullet(
          position: [shooter.position.x + enemyWidth / 2 - 2, shooter.position.y + enemyHeight],
          velocity: [0, bulletSpeed * 0.6],
          isPlayerBullet: false
        ))
      }
    }
  }

  // MARK: - Game State

  func resetGame() {
    score = 0
    lives = 3
    wave = 1
    gameOver = false
    victory = false
    gameStarted = false
    playerX = screenWidth / 2 - playerWidth / 2
    bullets = []
    enemyDirection = 1
    enemySpeed = 30
    spawnEnemies()
    spawnBarriers()
  }

  func nextWave() {
    wave += 1
    victory = false
    bullets = []
    enemyDirection = 1
    enemySpeed = min(50, 30 + Float(wave) * 5)
    spawnEnemies()
    spawnBarriers()
  }
}

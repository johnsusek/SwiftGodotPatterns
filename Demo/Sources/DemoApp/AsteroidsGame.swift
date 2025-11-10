import Foundation
import SwiftGodot
import SwiftGodotPatterns

@Godot
final class AsteroidsGame: Node2D {
  override func _ready() {
    let rootNode = AsteroidsGameView().toNode()
    addChild(node: rootNode)
  }
}

struct AsteroidsThemes {
  let score = Theme([
    "Label": [
      "fontSizes": ["fontSize": 24],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let message = Theme([
    "Label": [
      "fontSizes": ["fontSize": 28],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let gameOver = Theme([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color.red],
    ],
  ])
}

enum AsteroidSize {
  case large
  case medium
  case small

  var radius: Float {
    switch self {
    case .large: return 40
    case .medium: return 25
    case .small: return 15
    }
  }

  var points: Int {
    switch self {
    case .large: return 20
    case .medium: return 50
    case .small: return 100
    }
  }

  var health: Int {
    switch self {
    case .large: return 3
    case .medium: return 2
    case .small: return 1
    }
  }
}

struct Asteroid: Identifiable, Equatable {
  let id: UUID = .init()
  var position: Vector2
  var velocity: Vector2
  var rotation: Float
  var rotationSpeed: Float
  let size: AsteroidSize
  let color: Color = .init(r: 0.6, g: 0.6, b: 0.7)
}

struct AsteroidsBullet: Identifiable, Equatable {
  let id: UUID = .init()
  var position: Vector2
  var velocity: Vector2
  var lifetime: Double = 0
}

struct AsteroidsGameView: GView {
  let screenWidth: Float = 800
  let screenHeight: Float = 600
  let shipSize: Float = 20
  let thrustPower: Float = 400
  let rotationSpeed: Float = 4.5
  let maxSpeed: Float = 500
  let bulletSpeed: Float = 600
  let bulletLifetime: Double = 1.5
  let friction: Float = 0.99
  let themes = AsteroidsThemes()

  @State var shipPos: Vector2 = [400, 300]
  @State var shipVel: Vector2 = [0, 0]
  @State var shipRotation: Float = 0
  @State var bullets: [AsteroidsBullet] = []
  @State var asteroids: [Asteroid] = []
  @State var score = 0
  @State var lives = 3
  @State var gameStarted = false
  @State var gameOver = false
  @State var level = 1
  @State var canShoot = true
  @State var isThrusting = false
  @State var invulnerable = false
  @State var invulnerableTimer: Double = 0

  var body: some GView {
    Node2D$ {
      // Background
      CanvasLayer$ {
        ColorRect$()
          .color(Color(r: 0.0, g: 0.0, b: 0.05))
          .customMinimumSize([screenWidth, screenHeight])
      }
      .layer(-1)

      // Ship
      Area2D$ {
        // Ship body (triangle)
        Polygon2D$()
          .bind(\.modulate, to: $invulnerable) { invuln in
            invuln ? Color(r: 1.0, g: 1.0, b: 1.0, a: 0.5) : Color.white
          }
          .polygon([
            [0, -shipSize],
            [-shipSize / 2, shipSize / 2],
            [shipSize / 2, shipSize / 2],
          ])

        // Thrust flame
        Polygon2D$()
          .visible($isThrusting)
          .color(Color(r: 1.0, g: 0.5, b: 0.0))
          .polygon([
            [-shipSize / 4, shipSize / 2],
            [shipSize / 4, shipSize / 2],
            [0, shipSize * 1.2],
          ])

        CollisionShape2D$()
          .shape(CircleShape2D(radius: Double(shipSize / 2)))
      }
      .position($shipPos)
      .bind(\.rotation, to: $shipRotation) { Double($0) }
      .collisionLayer(.alpha)
      .collisionMask(.beta)
      .onSignal(\.areaEntered) { _, area in
        guard let area = area else { return }
        guard !invulnerable else { return }

        // Hit by asteroid
        if UUID(uuidString: String(area.name)) != nil {
          lives -= 1
          if lives <= 0 {
            gameOver = true
          } else {
            respawnShip()
          }
        }
      }

      // Asteroids
      ForEach($asteroids, mode: .deferred) { asteroid in
        Area2D$(asteroid.wrappedValue.id.uuidString) {
          // Draw asteroid as irregular polygon
          Polygon2D$()
            .onReady { node in
              let shape = generateAsteroidShape(
                radius: asteroid.wrappedValue.size.radius,
                seed: UInt(bitPattern: asteroid.wrappedValue.id.hashValue)
              )
              node.polygon = PackedVector2Array(shape)
              node.color = asteroid.wrappedValue.color
            }

          CollisionShape2D$()
            .shape(CircleShape2D(radius: Double(asteroid.wrappedValue.size.radius)))
        }
        .bind(\.position, to: asteroid, \.position)
        .bind(\.rotation, to: asteroid) { Double($0.rotation) }
        .collisionLayer(.beta)
        .collisionMask(.gamma)
        .onSignal(\.areaEntered) { _, area in
          guard let area = area else { return }

          // Hit by bullet
          if let bulletId = UUID(uuidString: String(area.name)) {
            handleAsteroidHit(asteroidId: asteroid.wrappedValue.id)
            bullets.removeAll { $0.id == bulletId }
          }
        }
      }

      // Bullets
      ForEach($bullets, mode: .deferred) { bullet in
        Area2D$(bullet.wrappedValue.id.uuidString) {
          Polygon2D$()
            .color(Color(r: 1.0, g: 1.0, b: 0.0))
            .polygon([
              [-2, -2],
              [2, -2],
              [2, 2],
              [-2, 2],
            ])

          CollisionShape2D$()
            .shape(CircleShape2D(radius: 2))
        }
        .bind(\.position, to: bullet, \.position)
        .collisionLayer(.gamma)
        .collisionMask(.beta)
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
          .offsetLeft(Double(screenWidth - 150))
          .offsetTop(10)
          .theme(themes.score)

        // Level
        Label$()
          .bind(\.text, to: $level) { "LEVEL: \($0)" }
          .offsetLeft(Double(screenWidth / 2 - 50))
          .offsetTop(10)
          .theme(themes.score)

        // Start message
        CenterContainer$ {
          Label$()
            .text("ASTEROIDS\n\nPress SPACE to start\nA/D or Arrows: Rotate\nW/UP: Thrust\nSPACE: Shoot")
            .horizontalAlignment(.center)
            .theme(themes.message)
        }
        .anchorsAndOffsets(.fullRect)
        .bind(\.visible, to: $gameStarted) { !$0 }

        // Game Over
        CenterContainer$ {
          Label$()
            .bind(\.text, to: $score) { "GAME OVER\n\nFinal Score: \($0)\n\nPress SPACE to restart" }
            .horizontalAlignment(.center)
            .theme(themes.gameOver)
        }
        .anchorsAndOffsets(.fullRect)
        .visible($gameOver)
      }
    }
    .onReady { _ in
      Actions {
        Action("rotate_left") {
          Key(.a)
          Key(.left)
        }

        Action("rotate_right") {
          Key(.d)
          Key(.right)
        }

        Action("thrust") {
          Key(.w)
          Key(.up)
        }

        Action("shoot") {
          Key(.space)
        }
      }.install()

      spawnAsteroids()
    }
    .onProcess { _, delta in
      handleInput(delta)

      if !gameStarted || gameOver { return }

      updateShip(delta)
      updateBullets(delta)
      updateAsteroids(delta)
      updateInvulnerability(delta)
      checkLevelComplete()
    }
  }

  // MARK: - Initialization

  func spawnAsteroids() {
    asteroids = []
    let count = 3 + level

    for _ in 0 ..< count {
      let edge = Int.random(in: 0 ..< 4)
      var pos: Vector2
      var vel: Vector2

      switch edge {
      case 0: // Top
        pos = [Float.random(in: 0 ... screenWidth), 0]
        vel = [Float.random(in: -100 ... 100), Float.random(in: 50 ... 150)]
      case 1: // Right
        pos = [screenWidth, Float.random(in: 0 ... screenHeight)]
        vel = [Float.random(in: -150 ... -50), Float.random(in: -100 ... 100)]
      case 2: // Bottom
        pos = [Float.random(in: 0 ... screenWidth), screenHeight]
        vel = [Float.random(in: -100 ... 100), Float.random(in: -150 ... -50)]
      default: // Left
        pos = [0, Float.random(in: 0 ... screenHeight)]
        vel = [Float.random(in: 50 ... 150), Float.random(in: -100 ... 100)]
      }

      asteroids.append(Asteroid(
        position: pos,
        velocity: vel,
        rotation: Float.random(in: 0 ... .pi * 2),
        rotationSpeed: Float.random(in: -2 ... 2),
        size: .large
      ))
    }
  }

  func respawnShip() {
    shipPos = [screenWidth / 2, screenHeight / 2]
    shipVel = [0, 0]
    shipRotation = 0
    invulnerable = true
    invulnerableTimer = 0
  }

  // MARK: - Input Handling

  func handleInput(_ delta: Double) {
    if Action("shoot").isJustPressed {
      if !gameStarted {
        gameStarted = true
      } else if gameOver {
        resetGame()
      } else if canShoot {
        shoot()
      }
    }

    if !gameStarted || gameOver { return }

    if Action("rotate_left").isPressed {
      shipRotation -= rotationSpeed * Float(delta)
    }
    if Action("rotate_right").isPressed {
      shipRotation += rotationSpeed * Float(delta)
    }

    isThrusting = Action("thrust").isPressed
  }

  func shoot() {
    let bulletVel = Vector2(
      x: cos(shipRotation - .pi / 2) * bulletSpeed,
      y: sin(shipRotation - .pi / 2) * bulletSpeed
    )

    bullets.append(AsteroidsBullet(
      position: shipPos + bulletVel.normalized() * shipSize,
      velocity: bulletVel + shipVel
    ))

    canShoot = false
    Engine.onNextFrame {
      Engine.onNextFrame {
        canShoot = true
      }
    }
  }

  // MARK: - Updates

  func updateShip(_ delta: Double) {
    // Apply thrust
    if isThrusting {
      let thrustVel = Vector2(
        x: cos(shipRotation - .pi / 2) * thrustPower * Float(delta),
        y: sin(shipRotation - .pi / 2) * thrustPower * Float(delta)
      )
      shipVel += thrustVel
    }

    // Apply friction
    shipVel *= friction

    // Limit max speed
    let speed = sqrt(shipVel.x * shipVel.x + shipVel.y * shipVel.y)
    if speed > maxSpeed {
      shipVel = shipVel.normalized() * maxSpeed
    }

    // Update position
    shipPos += shipVel * Float(delta)

    // Wrap around screen
    shipPos = wrapPosition(shipPos)
  }

  func updateBullets(_ delta: Double) {
    for i in stride(from: bullets.count - 1, through: 0, by: -1) {
      bullets[i].position += bullets[i].velocity * Float(delta)
      bullets[i].position = wrapPosition(bullets[i].position)
      bullets[i].lifetime += delta

      if bullets[i].lifetime > bulletLifetime {
        bullets.remove(at: i)
      }
    }
  }

  func updateAsteroids(_ delta: Double) {
    for i in asteroids.indices {
      asteroids[i].position += asteroids[i].velocity * Float(delta)
      asteroids[i].position = wrapPosition(asteroids[i].position)
      asteroids[i].rotation += asteroids[i].rotationSpeed * Float(delta)
    }
  }

  func updateInvulnerability(_ delta: Double) {
    if invulnerable {
      invulnerableTimer += delta
      if invulnerableTimer > 2.0 {
        invulnerable = false
        invulnerableTimer = 0
      }
    }
  }

  // MARK: - Collision & Game Logic

  func handleAsteroidHit(asteroidId: UUID) {
    guard let index = asteroids.firstIndex(where: { $0.id == asteroidId }) else { return }

    let asteroid = asteroids[index]
    score += asteroid.size.points

    // Remove the asteroid
    asteroids.remove(at: index)

    // Spawn smaller asteroids
    switch asteroid.size {
    case .large:
      spawnFragments(at: asteroid.position, velocity: asteroid.velocity, size: .medium)
    case .medium:
      spawnFragments(at: asteroid.position, velocity: asteroid.velocity, size: .small)
    case .small:
      break
    }
  }

  func spawnFragments(at position: Vector2, velocity: Vector2, size: AsteroidSize) {
    for _ in 0 ..< 2 {
      let angle = Float.random(in: 0 ... .pi * 2)
      let speed: Float = 150
      let newVel = Vector2(
        x: cos(angle) * speed + velocity.x * 0.5,
        y: sin(angle) * speed + velocity.y * 0.5
      )

      asteroids.append(Asteroid(
        position: position,
        velocity: newVel,
        rotation: Float.random(in: 0 ... .pi * 2),
        rotationSpeed: Float.random(in: -3 ... 3),
        size: size
      ))
    }
  }

  func checkLevelComplete() {
    if asteroids.isEmpty {
      level += 1
      spawnAsteroids()
      respawnShip()
    }
  }

  // MARK: - Utility

  func wrapPosition(_ pos: Vector2) -> Vector2 {
    var wrapped = pos

    if wrapped.x < -50 {
      wrapped.x = screenWidth + 50
    } else if wrapped.x > screenWidth + 50 {
      wrapped.x = -50
    }

    if wrapped.y < -50 {
      wrapped.y = screenHeight + 50
    } else if wrapped.y > screenHeight + 50 {
      wrapped.y = -50
    }

    return wrapped
  }

  func generateAsteroidShape(radius: Float, seed: UInt) -> [Vector2] {
    let rng = RandomNumberGenerator()
    rng.seed = seed
    let points = 8
    var shape: [Vector2] = []

    for i in 0 ..< points {
      let angle = Float(i) / Float(points) * .pi * 2
      let variation = Float(rng.randfRange(from: 0.6, to: 1.0))
      let r = radius * variation

      shape.append([
        cos(angle) * r,
        sin(angle) * r,
      ])
    }

    return shape
  }

  // MARK: - Game State

  func resetGame() {
    score = 0
    lives = 3
    level = 1
    gameOver = false
    gameStarted = false
    bullets = []
    shipPos = [screenWidth / 2, screenHeight / 2]
    shipVel = [0, 0]
    shipRotation = 0
    spawnAsteroids()
  }
}

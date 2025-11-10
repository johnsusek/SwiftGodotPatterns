import Foundation
import SwiftGodot
import SwiftGodotPatterns

@Godot
final class BreakoutGame: Node2D {
  override func _ready() {
    let rootNode = BreakoutGameView().toNode()
    addChild(node: rootNode)
  }
}

struct BreakoutThemes {
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

  let victory = Theme([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color.green],
    ],
  ])
}

struct Brick: Identifiable, Equatable {
  let id: Int
  var position: Vector2
  var color: Color
  var points: Int
  var hits: Int
}

struct BreakoutGameView: GView {
  let screenWidth: Float = 800
  let screenHeight: Float = 600
  let paddleWidth: Float = 100
  let paddleHeight: Float = 20
  let ballSize: Float = 12
  let ballSpeed: Float = 350
  let paddleSpeed: Float = 600
  let brickWidth: Float = 70
  let brickHeight: Float = 25
  let brickRows = 6
  let brickCols = 10
  let brickSpacing: Float = 5
  let themes = BreakoutThemes()

  @State var ballPos: Vector2 = [400, 300]
  @State var ballVel: Vector2 = [300, -300]
  @State var paddleX: Float = 350
  @State var score = 0
  @State var lives = 3
  @State var gameStarted = false
  @State var gameOver = false
  @State var victory = false
  @State var level = 1
  @State var bricks: [Brick] = []

  var body: some GView {
    Node2D$ {
      // Background
      CanvasLayer$ {
        ColorRect$()
          .color(Color(r: 0.05, g: 0.05, b: 0.1))
          .customMinimumSize([screenWidth, screenHeight])
      }
      .layer(-1)

      // Paddle
      StaticBody2D$ {
        Polygon2D$()
          .color(Color(r: 0.2, g: 0.6, b: 1.0))
          .polygon([
            [0, 0],
            [paddleWidth, 0],
            [paddleWidth, paddleHeight],
            [0, paddleHeight],
          ])

        CollisionShape2D$()
          .shape(RectangleShape2D(size: [paddleWidth, paddleHeight]))
          .position([paddleWidth / 2, paddleHeight / 2])
      }
      .bind(\.position, to: $paddleX) { x in
        [x, screenHeight - 50]
      }

      // Ball
      CharacterBody2D$ {
        Polygon2D$()
          .color(Color.white)
          .polygon([
            [0, 0],
            [ballSize, 0],
            [ballSize, ballSize],
            [0, ballSize],
          ])

        CollisionShape2D$()
          .shape(RectangleShape2D(size: [ballSize, ballSize]))
          .position([ballSize / 2, ballSize / 2])
      }
      .bind(\.position, to: $ballPos)
      .bind(\.velocity, to: $ballVel)

      // Bricks
      ForEach($bricks, mode: .deferred) { brick in
        Area2D$ {
          Polygon2D$()
            .color(brick.wrappedValue.color)
            .polygon([
              [0, 0],
              [brickWidth, 0],
              [brickWidth, brickHeight],
              [0, brickHeight],
            ])

          CollisionShape2D$()
            .shape(RectangleShape2D(size: [brickWidth, brickHeight]))
            .position([brickWidth / 2, brickHeight / 2])
        }
        .position(brick.wrappedValue.position)
        .onSignal(\.bodyEntered) { area, body in
          if body is CharacterBody2D {
            handleBrickCollision(brickId: brick.wrappedValue.id)
          }
        }
      }

      // UI Overlay
      CanvasLayer$ {
        // Score
        Label$()
          .bind(\.text, to: $score) { "Score: \($0)" }
          .offsetLeft(20)
          .offsetTop(10)
          .theme(themes.score)

        // Lives
        Label$()
          .bind(\.text, to: $lives) { "Lives: \($0)" }
          .offsetLeft(Double(screenWidth - 120))
          .offsetTop(10)
          .theme(themes.score)

        // Level
        Label$()
          .bind(\.text, to: $level) { "Level: \($0)" }
          .offsetLeft(Double(screenWidth / 2 - 40))
          .offsetTop(10)
          .theme(themes.score)

        // Start message
        Control$ {
          Label$()
            .text("Press SPACE to start\nMove paddle with A/D or Arrow Keys")
            .offsetLeft(Double(screenWidth / 2 - 250))
            .offsetTop(Double(screenHeight / 2 - 30))
            .horizontalAlignment(.center)
            .theme(themes.message)
        }
        .bind(\.visible, to: $gameStarted) { !$0 }

        // Game Over
        Control$ {
          Label$()
            .text("GAME OVER\nPress SPACE to restart")
            .offsetLeft(Double(screenWidth / 2 - 270))
            .offsetTop(Double(screenHeight / 2 - 50))
            .horizontalAlignment(.center)
            .theme(themes.gameOver)
        }
        .bind(\.visible, to: $gameOver)

        // Victory
        Control$ {
          Label$()
            .text("LEVEL COMPLETE!\nPress SPACE to continue")
            .offsetLeft(Double(screenWidth / 2 - 220))
            .offsetTop(Double(screenHeight / 2 - 50))
            .horizontalAlignment(.center)
            .theme(themes.victory)
        }
        .bind(\.visible, to: $victory)
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

        Action("start") {
          Key(.space)
        }
      }.install()

      initializeBricks()
    }
    .onProcess { node, delta in
      handleInput(delta)

      if !gameStarted || gameOver || victory { return }

      updateBall(node, delta)
    }
  }

  // MARK: - Initialization

  func initializeBricks() {
    bricks = []
    let startX = (screenWidth - Float(brickCols) * (brickWidth + brickSpacing) + brickSpacing) / 2
    let startY: Float = 80

    let colors: [(Color, Int)] = [
      (Color(r: 1.0, g: 0.2, b: 0.2), 60),
      (Color(r: 1.0, g: 0.6, b: 0.2), 50),
      (Color(r: 1.0, g: 1.0, b: 0.2), 40),
      (Color(r: 0.2, g: 1.0, b: 0.2), 30),
      (Color(r: 0.2, g: 0.6, b: 1.0), 20),
      (Color(r: 0.6, g: 0.2, b: 1.0), 10),
    ]

    var id = 0
    for row in 0 ..< brickRows {
      for col in 0 ..< brickCols {
        let x = startX + Float(col) * (brickWidth + brickSpacing)
        let y = startY + Float(row) * (brickHeight + brickSpacing)
        let (color, points) = colors[min(row, colors.count - 1)]

        bricks.append(Brick(
          id: id,
          position: [x, y],
          color: color,
          points: points,
          hits: 1
        ))
        id += 1
      }
    }
  }

  // MARK: - Input Handling

  func handleInput(_ delta: Double) {
    if Action("start").isJustPressed {
      if !gameStarted {
        gameStarted = true
      } else if gameOver {
        resetGame()
      } else if victory {
        nextLevel()
      }
    }

    if !gameStarted || gameOver || victory { return }

    let moveSpeed = paddleSpeed * Float(delta)

    if Action("move_left").isPressed {
      paddleX = max(0, paddleX - moveSpeed)
    }
    if Action("move_right").isPressed {
      paddleX = min(screenWidth - paddleWidth, paddleX + moveSpeed)
    }
  }

  // MARK: - Ball Physics

  func updateBall(_ node: Node, _ delta: Double) {
    // Find the ball CharacterBody2D
    guard let ball: CharacterBody2D = node.getChild() else {
      return
    }

    // Use move_and_collide for physics-based movement
    let motion = ballVel * Float(delta)
    let collision = ball.moveAndCollide(motion: motion)

    if let collision = collision {
      // Handle collision with Godot's built-in collision response
      let normal = collision.getNormal()

      // Reflect velocity
      ballVel = ballVel.bounce(n: normal)

      // Add angle variation if hitting a paddle
      if let _ = collision.getCollider() as? StaticBody2D {
        // Calculate hit position for angle variation
        let hitPos = (ball.position.x + ballSize / 2 - paddleX) / paddleWidth
        let angle = (hitPos - 0.5) * 2 // -1 to 1

        // Update velocity with angle
        let speed = sqrt(ballVel.x * ballVel.x + ballVel.y * ballVel.y)
        ballVel = [
          angle * speed * 0.7,
          -abs(ballVel.y),
        ]
      }
    }

    // Wall collisions
    if ball.position.x <= 0 {
      ball.position = [0, ball.position.y]
      ballVel = [abs(ballVel.x), ballVel.y]
    } else if ball.position.x >= screenWidth - ballSize {
      ball.position = [screenWidth - ballSize, ball.position.y]
      ballVel = [-abs(ballVel.x), ballVel.y]
    }

    // Top wall
    if ball.position.y <= 0 {
      ball.position = [ball.position.x, 0]
      ballVel = [ballVel.x, abs(ballVel.y)]
    }

    // Bottom - lose a life
    if ball.position.y >= screenHeight {
      lives -= 1
      if lives <= 0 {
        gameOver = true
      } else {
        resetBall()
      }
      return
    }

    ballPos = ball.position
  }

  // MARK: - Collision Handlers

  func handleBrickCollision(brickId: Int) {
    // Find and remove the brick
    if let index = bricks.firstIndex(where: { $0.id == brickId }) {
      score += bricks[index].points
      bricks.remove(at: index)

      // Check for level complete
      if bricks.isEmpty {
        victory = true
      }
    }
  }

  // MARK: - Game State

  func resetBall() {
    ballPos = [screenWidth / 2 - ballSize / 2, screenHeight / 2]
    let angle = Float.random(in: -0.5 ... 0.5)
    ballVel = [ballSpeed * angle, -ballSpeed]
  }

  func resetGame() {
    score = 0
    lives = 3
    level = 1
    gameOver = false
    victory = false
    gameStarted = false
    initializeBricks()
    resetBall()
  }

  func nextLevel() {
    level += 1
    victory = false
    initializeBricks()
    resetBall()

    // Increases difficulty slightly
    ballVel = ballVel * 1.1
  }
}

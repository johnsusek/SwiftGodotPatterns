import SwiftGodot
import SwiftGodotPatterns

@Godot
final class PongGame: Node2D {
  override func _ready() {
    let rootNode = PongGameView().toNode()
    addChild(node: rootNode)
  }
}

struct Themes {
  let scoreLeft = Theme([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color(r: 0.3, g: 0.7, b: 1.0, a: 0.8)],
    ],
  ])

  let scoreRight = Theme([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color(r: 1.0, g: 0.3, b: 0.5, a: 0.8)],
    ],
  ])

  let message = Theme([
    "Label": [
      "fontSizes": ["fontSize": 20],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let pause = Theme([
    "Label": [
      "fontSizes": ["fontSize": 32],
      "colors": ["fontColor": Color.yellow],
    ],
  ])
}

struct PongGameView: GView {
  let screenWidth: Float = 800
  let screenHeight: Float = 600
  let paddleWidth: Float = 15
  let paddleHeight: Float = 80
  let ballSize: Float = 15
  let paddleSpeed: Float = 400
  let initialBallSpeed: Float = 300
  let paddleMargin: Float = 30
  let themes = Themes()

  @State var ballPos: Vector2 = [400, 300]
  @State var ballVel: Vector2 = [300, 210]
  @State var leftPaddleY: Float = (600 - 80) / 2
  @State var rightPaddleY: Float = (600 - 80) / 2
  @State var leftScore = 0
  @State var rightScore = 0
  @State var isPaused = false
  @State var gameStarted = false

  var body: some GView {
    Node2D$ {
      // Background
      CanvasLayer$ {
        ColorRect$()
          .color(Color(r: 0.1, g: 0.1, b: 0.15))
          .customMinimumSize([screenWidth, screenHeight])
      }
      .layer(-1)

      // Center line
      Polygon2D$()
        .color(Color(r: 0.3, g: 0.3, b: 0.35))
        .polygon([
          [screenWidth / 2 - 2, 0],
          [screenWidth / 2 + 2, 0],
          [screenWidth / 2 + 2, screenHeight],
          [screenWidth / 2 - 2, screenHeight],
        ])

      // Left paddle
      StaticBody2D$ {
        Polygon2D$()
          .color(Color(r: 0.3, g: 0.7, b: 1.0))
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
      .bind(\.position, to: $leftPaddleY) { y in
        [paddleMargin, y]
      }

      // Right paddle
      StaticBody2D$ {
        Polygon2D$()
          .color(Color(r: 1.0, g: 0.3, b: 0.5))
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
      .bind(\.position, to: $rightPaddleY) { y in
        [screenWidth - paddleMargin - paddleWidth, y]
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
      .position($ballPos)
      .velocity($ballVel)

      // Score UI overlay
      CanvasLayer$ {
        // Left score
        Label$()
          .bind(\.text, to: $leftScore) { String($0) }
          .offsetLeft(Double(screenWidth / 4 - 20))
          .offsetTop(30)
          .theme(themes.scoreLeft)

        // Right score
        Label$()
          .bind(\.text, to: $rightScore) { String($0) }
          .offsetLeft(Double(screenWidth * 3 / 4 - 20))
          .offsetTop(30)
          .theme(themes.scoreRight)

        // Start message
        CenterContainer$ {
          Label$()
            .text("Press SPACE to start\nW/S and UP/DOWN to move paddles")
            .horizontalAlignment(.center)
            .theme(themes.message)
        }
        .anchorsAndOffsets(.fullRect)
        .bind(\.visible, to: $gameStarted) { !$0 }

        // Pause indicator
        CenterContainer$ {
          Label$()
            .text("PAUSED")
            .horizontalAlignment(.center)
            .theme(themes.pause)
        }
        .anchorsAndOffsets(.fullRect)
        .visible($isPaused)
      }
    }
    .onReady { _ in
      Actions {
        Action("p1_up") { Key(.w) }
        Action("p1_down") { Key(.s) }
        Action("p2_up") { Key(.up) }
        Action("p2_down") { Key(.down) }
        Action("pause") { Key(.p) }
        Action("start") { Key(.space) }
      }.install()
    }
    .onProcess { node, delta in
      handleInput(delta)

      if !gameStarted || isPaused { return }

      updateBall(node, delta)
      checkScoring()
    }
  }

  // MARK: - Game Logic

  func handleInput(_ delta: Double) {
    if Action("start").isJustPressed && !gameStarted {
      gameStarted = true
    }

    if Action("pause").isJustPressed && gameStarted {
      isPaused.toggle()
    }

    if !gameStarted || isPaused { return }

    let paddleSpeed = paddleSpeed * Float(delta)

    if Action("p1_up").isPressed {
      leftPaddleY = max(0, leftPaddleY - paddleSpeed)
    }
    if Action("p1_down").isPressed {
      leftPaddleY = min(screenHeight - paddleHeight, leftPaddleY + paddleSpeed)
    }

    if Action("p2_up").isPressed {
      rightPaddleY = max(0, rightPaddleY - paddleSpeed)
    }
    if Action("p2_down").isPressed {
      rightPaddleY = min(screenHeight - paddleHeight, rightPaddleY + paddleSpeed)
    }
  }

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

      // Add spin if hitting a paddle
      if let collider = collision.getCollider() as? StaticBody2D {
        // Calculate where on paddle we hit (0 to 1)
        let paddlePos = collider.position
        let hitY = ball.position.y + ballSize / 2
        let hitPos = (hitY - paddlePos.y) / paddleHeight
        let spinFactor = (hitPos - 0.5) * 2 // -1 to 1

        // Add spin and speed up slightly
        ballVel = [
          ballVel.x * 1.05,
          ballVel.y + spinFactor * 100,
        ]
      }
    }

    // Top/bottom wall collision (simple bounds check)
    if ball.position.y <= 0 {
      ball.position = [ball.position.x, 0]
      ballVel = [ballVel.x, abs(ballVel.y)]
    } else if ball.position.y >= screenHeight - ballSize {
      ball.position = [ball.position.x, screenHeight - ballSize]
      ballVel = [ballVel.x, -abs(ballVel.y)]
    }

    ballPos = ball.position
  }

  func checkScoring() {
    // Ball went past left edge
    if ballPos.x < 0 {
      rightScore += 1
      resetBall()
    }

    // Ball went past right edge
    if ballPos.x > screenWidth {
      leftScore += 1
      resetBall()
    }
  }

  func resetBall() {
    ballPos = [
      screenWidth / 2 - ballSize / 2,
      screenHeight / 2 - ballSize / 2,
    ]

    // Random direction
    let angle = Float.random(in: -0.5 ... 0.5)
    let direction: Float = Bool.random() ? 1 : -1
    ballVel = [
      initialBallSpeed * direction,
      initialBallSpeed * angle,
    ]
  }
}

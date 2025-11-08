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
  let scoreLeft = Theme.build([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color(r: 0.3, g: 0.7, b: 1.0, a: 0.8)],
    ],
  ])

  let scoreRight = Theme.build([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color(r: 1.0, g: 0.3, b: 0.5, a: 0.8)],
    ],
  ])

  let message = Theme.build([
    "Label": [
      "fontSizes": ["fontSize": 20],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let pause = Theme.build([
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
      Polygon2D$()
        .color(Color(r: 0.3, g: 0.7, b: 1.0))
        .bind(\.position, to: $leftPaddleY) { y in
          [paddleMargin, y]
        }
        .polygon([
          [0, 0],
          [paddleWidth, 0],
          [paddleWidth, paddleHeight],
          [0, paddleHeight],
        ])

      // Right paddle
      Polygon2D$()
        .color(Color(r: 1.0, g: 0.3, b: 0.5))
        .bind(\.position, to: $rightPaddleY) { y in
          [screenWidth - paddleMargin - paddleWidth, y]
        }
        .polygon([
          [0, 0],
          [paddleWidth, 0],
          [paddleWidth, paddleHeight],
          [0, paddleHeight],
        ])

      // Ball
      Polygon2D$()
        .color(Color.white)
        .bind(\.position, to: $ballPos)
        .polygon([
          [0, 0],
          [ballSize, 0],
          [ballSize, ballSize],
          [0, ballSize],
        ])

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
        Control$ {
          Label$()
            .text("Press SPACE to start\nW/S and UP/DOWN to move paddles")
            .offsetLeft(Double(screenWidth / 2 - 150))
            .offsetTop(Double(screenHeight / 2 - 30))
            .horizontalAlignment(.center)
            .theme(themes.message)
        }
        .bind(\.visible, to: $gameStarted) { !$0 }

        // Pause indicator
        Control$ {
          Label$()
            .text("PAUSED")
            .offsetLeft(Double(screenWidth / 2 - 50))
            .offsetTop(Double(screenHeight / 2 + 50))
            .theme(themes.pause)
        }
        .bind(\.visible, to: $isPaused)
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
    .onProcess { _, delta in
      handleInput(delta)

      if !gameStarted || isPaused { return }

      updateBall(delta)
      checkCollisions()
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

  func updateBall(_ delta: Double) {
    ballPos = ballPos + ballVel * Float(delta)
  }

  func checkCollisions() {
    // Top/bottom wall collision
    if ballPos.y <= 0 {
      ballPos = [ballPos.x, 0]
      ballVel = [ballVel.x, abs(ballVel.y)]
    } else if ballPos.y >= screenHeight - ballSize {
      ballPos = [ballPos.x, screenHeight - ballSize]
      ballVel = [ballVel.x, -abs(ballVel.y)]
    }

    // Paddle collisions
    let leftPaddleX = paddleMargin
    let rightPaddleX = screenWidth - paddleMargin - paddleWidth

    checkPaddleCollision(
      paddleX: leftPaddleX,
      paddleY: leftPaddleY,
      isLeftPaddle: true
    )

    checkPaddleCollision(
      paddleX: rightPaddleX,
      paddleY: rightPaddleY,
      isLeftPaddle: false
    )
  }

  func checkPaddleCollision(paddleX: Float, paddleY: Float, isLeftPaddle: Bool) {
    let ballRight = ballPos.x + ballSize
    let ballBottom = ballPos.y + ballSize

    // Check if ball overlaps with paddle
    let overlapsHorizontally = isLeftPaddle
      ? (ballPos.x <= paddleX + paddleWidth && ballRight >= paddleX)
      : (ballRight >= paddleX && ballPos.x <= paddleX + paddleWidth)

    let overlapsVertically = ballBottom >= paddleY && ballPos.y <= paddleY + paddleHeight

    guard overlapsHorizontally && overlapsVertically else { return }

    // Calculate hit position and spin
    let hitPos = (ballPos.y + ballSize / 2 - paddleY) / paddleHeight
    let spinFactor = (hitPos - 0.5) * 2 // -1 to 1

    // Update velocity with reflection and spin
    let xVelocity = isLeftPaddle
      ? abs(ballVel.x) * 1.05
      : -abs(ballVel.x) * 1.05

    ballVel = [
      xVelocity,
      ballVel.y + spinFactor * 100,
    ]

    // Reposition ball to prevent getting stuck in paddle
    ballPos = [
      isLeftPaddle ? paddleX + paddleWidth : paddleX - ballSize,
      ballPos.y,
    ]
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

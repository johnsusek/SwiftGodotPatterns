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
  let score = Theme.build([
    "Label": [
      "fontSizes": ["fontSize": 24],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let message = Theme.build([
    "Label": [
      "fontSizes": ["fontSize": 28],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let gameOver = Theme.build([
    "Label": [
      "fontSizes": ["fontSize": 48],
      "colors": ["fontColor": Color.red],
    ],
  ])

  let victory = Theme.build([
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
      Polygon2D$()
        .color(Color(r: 0.2, g: 0.6, b: 1.0))
        .bind(\.position, to: $paddleX) { x in
          [x, screenHeight - 50]
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

      // Bricks
      ForEach($bricks, mode: .deferred) { brick in
        Polygon2D$()
          .position(brick.wrappedValue.position)
          .color(brick.wrappedValue.color)
          .polygon([
            [0, 0],
            [brickWidth, 0],
            [brickWidth, brickHeight],
            [0, brickHeight],
          ])
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
    .onProcess { _, delta in
      handleInput(delta)

      if !gameStarted || gameOver || victory { return }

      updateBall(delta)
      checkCollisions()
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

  func updateBall(_ delta: Double) {
    ballPos = ballPos + ballVel * Float(delta)
  }

  // MARK: - Collision Detection

  func checkCollisions() {
    // Wall collisions
    if ballPos.x <= 0 {
      ballPos = [0, ballPos.y]
      ballVel = [abs(ballVel.x), ballVel.y]
    } else if ballPos.x >= screenWidth - ballSize {
      ballPos = [screenWidth - ballSize, ballPos.y]
      ballVel = [-abs(ballVel.x), ballVel.y]
    }

    // Top wall
    if ballPos.y <= 0 {
      ballPos = [ballPos.x, 0]
      ballVel = [ballVel.x, abs(ballVel.y)]
    }

    // Bottom - lose a life
    if ballPos.y >= screenHeight {
      lives -= 1
      if lives <= 0 {
        gameOver = true
      } else {
        resetBall()
      }
      return
    }

    // Paddle collision
    checkPaddleCollision()

    // Brick collisions
    checkBrickCollisions()
  }

  func checkPaddleCollision() {
    let paddleY = screenHeight - 50
    let ballRight = ballPos.x + ballSize
    let ballBottom = ballPos.y + ballSize

    let overlapsHorizontally = ballRight >= paddleX && ballPos.x <= paddleX + paddleWidth
    let overlapsVertically = ballBottom >= paddleY && ballPos.y <= paddleY + paddleHeight

    guard overlapsHorizontally && overlapsVertically && ballVel.y > 0 else { return }

    // Calculate hit position for angle variation
    let hitPos = (ballPos.x + ballSize / 2 - paddleX) / paddleWidth
    let angle = (hitPos - 0.5) * 2 // -1 to 1

    // Update velocity
    let speed = sqrt(ballVel.x * ballVel.x + ballVel.y * ballVel.y)
    ballVel = [
      angle * speed * 0.7,
      -abs(ballVel.y),
    ]

    // Reposition ball above paddle
    ballPos = [ballPos.x, paddleY - ballSize]
  }

  func checkBrickCollisions() {
    let ballRight = ballPos.x + ballSize
    let ballBottom = ballPos.y + ballSize

    for (index, brick) in bricks.enumerated() {
      let brickRight = brick.position.x + brickWidth
      let brickBottom = brick.position.y + brickHeight

      // Check overlap
      let overlapsHorizontally = ballRight >= brick.position.x && ballPos.x <= brickRight
      let overlapsVertically = ballBottom >= brick.position.y && ballPos.y <= brickBottom

      guard overlapsHorizontally && overlapsVertically else { continue }

      // Determine collision side
      let fromLeft = ballRight - brick.position.x
      let fromRight = brickRight - ballPos.x
      let fromTop = ballBottom - brick.position.y
      let fromBottom = brickBottom - ballPos.y

      let minDist = min(fromLeft, fromRight, fromTop, fromBottom)

      if minDist == fromTop || minDist == fromBottom {
        ballVel = [ballVel.x, -ballVel.y]
      } else {
        ballVel = [-ballVel.x, ballVel.y]
      }

      // Remove brick and update score
      score += brick.points
      bricks.remove(at: index)

      // Check for level complete
      if bricks.isEmpty {
        victory = true
      }

      break // Only handle one collision per frame
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

import Foundation
import SwiftGodot
import SwiftGodotPatterns

@Godot
final class PlatformerGame: Node2D {
  override func _ready() {
    let rootNode = PlatformerGameView().toNode()
    addChild(node: rootNode)
  }
}

struct PlatformerGameView: GView {
  let screenWidth: Float = 800
  let screenHeight: Float = 600
  let playerWidth: Float = 32
  let playerHeight: Float = 32
  let gravity: Float = 980
  let jumpSpeed: Float = 450
  let moveSpeed: Float = 200
  let coinSize: Float = 16
  let themes = PlatformerThemes()

  @State var playerPos: Vector2 = [400, 200]
  @State var playerVel: Vector2 = [0, 0]
  @State var score = 0
  @State var totalCoins = 0
  @State var gameState: GameState = .menu
  @State var coins: [Coin] = []

  @State var rootNode: Node2D?

  var body: some GView {
    Node2D$ {
      // This is a TileMapLayer built in the Godot editor
      Node2D$().fromScene("platformer_level.tscn")

      // Player
      CharacterBody2D$ {
        Sprite2D$()
          .res(\.texture, "platformer_player.png")
          .centered(false)

        CollisionShape2D$()
          .shape(RectangleShape2D(w: playerWidth, h: playerHeight))
          .position([playerWidth / 2, playerHeight / 2])
      }
      .collisionMask(1) // Terrain tiles are set to layer 1 in the Godot editor
      .position($playerPos)
      .velocity($playerVel)

      // Coins
      ForEach($coins, mode: .deferred) { coin in
        Area2D$ {
          Sprite2D$()
            .res(\.texture, "coin.png")
            .centered(true)

          CollisionShape2D$()
            .shape(CircleShape2D(radius: Double(coinSize / 2)))
        }
        .position(coin.wrappedValue.position)
        .onSignal(\.bodyEntered) { _, body in
          if gameState == .playing, body is CharacterBody2D {
            collectCoin(coinId: coin.wrappedValue.id)
          }
        }
      }

      // UI Overlay
      CanvasLayer$ {
        // Score
        Label$()
          .bind(\.text, to: $score, $totalCoins) { collected, total in
            "Coins: \(collected) / \(total)"
          }
          .offsetLeft(20)
          .offsetTop(10)
          .theme(themes.score)

        // Start message
        CenterContainer$ {
          VBoxContainer$ {
            Label$()
              .text("PLATFORMER")
              .horizontalAlignment(.center)
              .theme(themes.score)

            Control$().customMinimumSize([0, 20])

            Label$()
              .text("Press SPACE to start\nA/D or Arrow Keys to move\nSPACE/W/UP to jump\n\nCollect all the coins!")
              .horizontalAlignment(.center)
              .theme(themes.message)
          }
          .offsetLeft(Double(screenWidth / 2 - 150))
          .offsetTop(Double(screenHeight / 2 - 100))
        }
        .anchorsAndOffsets(.fullRect)
        .bind(\.visible, to: $gameState) { $0 == .menu }

        // Victory message
        CenterContainer$ {
          Label$()
            .text("YOU WIN!\nPress SPACE to restart")
            .offsetLeft(Double(screenWidth / 2 - 180))
            .offsetTop(Double(screenHeight / 2 - 50))
            .horizontalAlignment(.center)
            .theme(themes.gameOver)
        }
        .anchorsAndOffsets(.fullRect)
        .bind(\.visible, to: $gameState) { $0 == .victory }
      }
    }
    .ref($rootNode)
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

        Action("jump") {
          Key(.space)
          Key(.w)
          Key(.up)
        }

        Action("start") {
          Key(.space)
        }
      }.install()

      initializeCoins()

      positionPlayer()
    }
    .onProcess { node, delta in
      handleInput()

      guard gameState == .playing else {
        return
      }

      if let player: CharacterBody2D = node.getChild() {
        updatePlayer(player, delta)
      }

      checkVictory()
    }
  }
}

extension PlatformerGameView {
  // MARK: - Initialization

  func positionPlayer() {
    guard let rootNode else { return }

    // These are marker nodes placed in the Godot editor
    let playerSpawns: [Marker2D] = rootNode.getNodes(inGroup: "player_spawns")

    playerPos = playerSpawns.randomElement()?.position ?? [100, 200]
  }

  func initializeCoins() {
    guard let rootNode else { return }

    // These are marker nodes placed in the Godot editor
    let coinNodes: [Marker2D] = rootNode.getNodes(inGroup: "coin_spawns")

    coins = coinNodes.enumerated().map { index, node in
      Coin(id: index, position: node.position, collected: false)
    }

    totalCoins = coins.count
  }

  // MARK: - Input Handling

  func handleInput() {
    if Action("start").isJustPressed {
      switch gameState {
      case .menu:
        // We wait until the next frame to avoid input carry-over
        // which would cause the player to jump immediately
        Engine.onNextFrame { gameState = .playing }
      case .victory:
        resetGame()
      case .playing:
        break
      }
    }
  }

  // MARK: - Player Physics

  func updatePlayer(_ player: CharacterBody2D, _ delta: Double) {
    var velocity = playerVel

    // Apply gravity
    velocity.y += gravity * Float(delta)

    // Horizontal movement
    var input: Float = 0
    if Action("move_left").isPressed {
      input -= 1
    }
    if Action("move_right").isPressed {
      input += 1
    }
    let horizontalInput = input * moveSpeed
    velocity.x = horizontalInput

    // Jump
    if Action("jump").isJustPressed, player.isOnFloor() {
      velocity.y = -jumpSpeed
    }

    // Move the player
    player.velocity = velocity
    player.moveAndSlide()

    // Update state
    playerVel = player.velocity
    playerPos = player.position

    // Keep player in bounds horizontally
    let playerMaxX = screenWidth - playerWidth

    if playerPos.x < 0 {
      playerPos.x = 0
      player.position = playerPos
    } else if playerPos.x > playerMaxX {
      playerPos.x = playerMaxX
      player.position = playerPos
    }

    // Fall off screen = reset
    if playerPos.y > screenHeight + 100 {
      resetPlayer()
    }
  }

  // MARK: - Game Logic

  func collectCoin(coinId: Int) {
    if let index = coins.firstIndex(where: { $0.id == coinId }) {
      coins.remove(at: index)
      score += 1
    }
  }

  func checkVictory() {
    if gameState == .playing, score >= totalCoins {
      gameState = .victory
    }
  }

  func resetPlayer() {
    positionPlayer()
    playerVel = [0, 0]
  }

  func resetGame() {
    score = 0
    gameState = .menu
    resetPlayer()
    initializeCoins()
  }
}

// MARK: - UI Themes

struct PlatformerThemes {
  let score = Theme([
    "Label": [
      "fontSizes": ["fontSize": 28],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let message = Theme([
    "Label": [
      "fontSizes": ["fontSize": 20],
      "colors": ["fontColor": Color.white],
    ],
  ])

  let gameOver = Theme([
    "Label": [
      "fontSizes": ["fontSize": 42],
      "colors": ["fontColor": Color(r: 0.3, g: 1.0, b: 0.3)],
    ],
  ])
}

// MARK: - Models

struct Coin: Identifiable, Equatable {
  let id: Int
  var position: Vector2
  var collected: Bool = false
}

enum GameState {
  case menu
  case playing
  case victory
}

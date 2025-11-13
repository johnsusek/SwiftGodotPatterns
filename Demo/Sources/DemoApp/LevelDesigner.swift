import Foundation
import SwiftGodot
import SwiftGodotPatterns

@Godot
final class LevelDesigner: Node2D {
  override func _ready() {
    let projectPath = "res://Typical_2D_platformer_example.ldtk"
    if let project = try? LDProject.load(path: projectPath) {
      let rootNode = LevelDesignerView(project: project).toNode()
      addChild(node: rootNode)
    }
  }
}

struct InventoryHUD: GView {
  let items: State<[Item]>
  let health: State<Int>

  var body: some GView {
    CanvasLayer$ {
      VBoxContainer$ {
        Label$()
          .bind(\.text, to: health) { health in
            "Health: \(String(repeating: "♥", count: max(0, health)))"
          }

        Label$()
          .bind(\.text, to: items) { items in
            "Inventory: \(items.map(\.displayName).joined(separator: ", "))"
          }
      }
      .offset(top: 4, left: 4)
    }
  }
}

struct PlayerView: GView {
  let gravity: Float = 980
  let jumpSpeed: Float = 300
  let moveSpeed: Float = 200
  let levelWidth: Int32
  let levelHeight: Int32
  let terrainLayer: UInt32
  @State var playerPos: Vector2 = [100, 100]
  @State var playerVel: Vector2 = [0, 0]
  @State var player: CharacterBody2D?

  init(from entity: LDEntity, in level: LDLevel, _ project: LDProject) {
    playerPos = entity.position
    levelWidth = Int32(level.pxWid)
    levelHeight = Int32(level.pxHei)
    terrainLayer = project.collisionLayer(for: "walls", in: level)
  }

  var body: some GView {
    CharacterBody2D$("Player") {
      Sprite2D$().res(\.texture, "player_16x22.png")
      CollisionShape2D$().shape(RectangleShape2D(w: 16, h: 22))

      Camera2D$()
        .enabled(true)
        .limitLeft(0)
        .limitTop(0)
        .limitRight(levelWidth)
        .limitBottom(levelHeight)
        .limitSmoothed(true)
    }
    .collisionMask(terrainLayer | CollisionLayers.mob | CollisionLayers.door)
    .collisionLayer(CollisionLayers.player)
    .position($playerPos)
    .velocity($playerVel)
    .zIndex(12)
    .ref($player)
    .onProcess { _, delta in
      updatePlayer(delta)
    }
  }

  func updatePlayer(_ delta: Double) {
    guard let player else { return }

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
  }
}

struct DoorView: GView {
  let frame: Vector2
  let position: Vector2
  @State var isLocked: Bool

  init(from entity: LDEntity) {
    frame = entity.size
    position = entity.position
    isLocked = entity.field("locked")?.asBool() ?? true
  }

  var body: some GView {
    Area2D$ {
      Sprite2D$()
        .res(\.texture, isLocked ? "door_locked_12x32.png" : "door_open_12x32.png")
        .anchor([12, 32], within: frame)
      CollisionShape2D$().shape(RectangleShape2D(w: 12, h: 32))
    }
    .collisionLayer(CollisionLayers.door)
    .collisionMask(CollisionLayers.player)
    .position(position)
    .onSignal(\.bodyEntered) { _, body in
      guard isLocked, let body, body.name == "Player" else { return }
      isLocked = false
    }
  }
}

struct ChestView: GView {
  let frame: Vector2
  let position: Vector2
  var contents: [Item] = []
  @State var isOpen = false

  init(from entity: LDEntity) {
    frame = entity.size
    position = entity.position
    contents = entity.field("content")?.asEnumArray() ?? []
  }

  var body: some GView {
    Area2D$ {
      Sprite2D$()
        .res(\.texture, "chest_16x17.png")
        .anchor([16, 17], within: frame)
      CollisionShape2D$()
        .shape(RectangleShape2D(w: 16, h: 17))
    }
    .position(position)
    .onSignal(\.bodyEntered) { [contents] _, body in
      guard !isOpen else { return }
      if body?.name == "Player" {
        isOpen = true
        GameEvent.looted(items: contents).emit()
      }
    }
  }
}

struct MobView: GView {
  let startPos: Vector2
  let frame: Vector2
  let patrolPoints: [Vector2]
  let patrolSpeed: Float = 50.0
  let loot: [Item]

  @State var mobPos: Vector2
  @State var currentTargetIndex = 0
  @State var movingForward = true
  @State var health: Int = 1
  @State var mob: Node2D?

  init(from entity: LDEntity, in level: LDLevel) {
    startPos = entity.position
    frame = entity.size
    mobPos = startPos

    let patrolField = entity.field("patrol")?.asArray() ?? []
    let gridSize = level.entityLayers.first?.gridSize ?? 16
    patrolPoints = Self.buildPatrolPoints(from: patrolField, gridSize: gridSize, starting: startPos)

    loot = entity.field("loot")?.asEnumArray() ?? []
  }

  var body: some GView {
    Node2D$ {
      Sprite2D$()
        .res(\.texture, "mob_12x11.png")
        .anchor([12, 11], within: frame)

      Area2D$ {
        CollisionShape2D$()
          .shape(RectangleShape2D(w: 12, h: 11))
      }
      .collisionLayer(CollisionLayers.mob)
      .collisionMask(CollisionLayers.player)
      .onSignal(\.bodyEntered) { [loot] _, body in
        guard health > 0, let body, body.name == "Player" else { return }

        // Damage player and kill mob
        GameEvent.damaged(target: body).emit()
        health = 0
        GameEvent.dropped(items: loot).emit()
        mob?.queueFree()
      }
    }
    .position($mobPos)
    .ref($mob)
    .onProcess { _, delta in
      guard health > 0 else { return }
      updatePatrol(delta)
    }
  }

  static func buildPatrolPoints(from patrolArray: [LDFieldValue], gridSize: Int, starting startPos: Vector2) -> [Vector2] {
    // Convert grid coordinates to centered world coordinates
    let halfGrid = Float(gridSize) / 2.0

    var points = patrolArray.compactMap { fieldValue -> Vector2? in
      guard let point = fieldValue.asVector2(gridSize: gridSize) else { return nil }
      // 2.0 offset to fix strange drifting issue
      return Vector2(x: point.x + halfGrid, y: point.y + halfGrid - 2.0)
    }

    // Add starting position for full patrol loop
    if !points.isEmpty {
      points.insert(startPos, at: 0)
    }

    return points
  }

  func updatePatrol(_ delta: Double) {
    guard !patrolPoints.isEmpty else { return }
    let targetPoint = patrolPoints[currentTargetIndex]
    let direction = (targetPoint - mobPos).normalized()
    let distanceToTarget = Float(mobPos.distanceTo(targetPoint))
    let moveDistance = patrolSpeed * Float(delta)

    if distanceToTarget <= moveDistance {
      // Reached the target, move to it exactly
      mobPos = targetPoint

      if patrolPoints.count == 1 { return }

      // Check if we need to reverse direction
      if movingForward && currentTargetIndex >= patrolPoints.count - 1 {
        movingForward = false
      } else if !movingForward && currentTargetIndex <= 0 {
        movingForward = true
      }

      // Move to next target in current direction
      if movingForward {
        currentTargetIndex = min(currentTargetIndex + 1, patrolPoints.count - 1)
      } else {
        currentTargetIndex = max(currentTargetIndex - 1, 0)
      }
    } else {
      // Continue moving toward target
      mobPos = mobPos + (direction * moveDistance)
    }
  }
}

struct LevelDesignerView: GView {
  @State var playerInventory: [Item] = []
  @State var playerHealth: Int = 3
  let project: LDProject

  var body: some GView {
    Node2D$ {
      LDLevelView(project, level: "Your_typical_2D_platformer")
        .onSpawn("Player") { entity, level, project in
          let startingItems: [Item] = entity.field("items")?.asEnumArray() ?? []
          playerInventory.append(contentsOf: startingItems)

          return PlayerView(from: entity, in: level, project)
        }
        .onSpawn("Chest") { entity, _, _ in
          ChestView(from: entity)
        }
        .onSpawn("Mob") { entity, level, _ in
          MobView(from: entity, in: level)
        }
        .onSpawn("Door") { entity, _, _ in
          DoorView(from: entity)
        }
        .onSpawned { node, entity in
          // Add debugging labels to all entities
          let label = Label$().text(entity.identifier)
          node.addChild(node: label.toNode())
        }

      InventoryHUD(items: $playerInventory, health: $playerHealth)
    }
    .onEvent(GameEvent.self) { _, event in
      switch event {
      case let .looted(items):
        playerInventory.append(contentsOf: items)
      case .damaged:
        playerHealth -= 1
      case let .dropped(items):
        playerInventory.append(contentsOf: items)
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

        Action("jump") {
          Key(.space)
          Key(.w)
          Key(.up)
        }

        Action("start") {
          Key(.space)
        }
      }.install()
    }
  }
}

enum CollisionLayers {
  static let player: UInt32 = 1
  static let mob: UInt32 = 2
  static let door: UInt32 = 4
}

enum Item: String, LDExported {
  case knife = "Knife"
  case healingPlant = "Healing_Plant"
  case meat = "Meat"
  case boots = "Boots"
  case water = "Water"
  case gem = "Gem"
  case gloves = "Gloves"

  var displayName: String {
    switch self {
    case .knife: return "Knife"
    case .healingPlant: return "Healing Plant"
    case .meat: return "Meat"
    case .boots: return "Boots"
    case .water: return "Water"
    case .gem: return "Gem"
    case .gloves: return "Gloves"
    }
  }

  var description: String {
    switch self {
    case .knife: return "A sharp blade for combat"
    case .healingPlant: return "Restores health when consumed"
    case .meat: return "Provides sustenance"
    case .boots: return "Increases movement speed"
    case .water: return "Quenches thirst"
    case .gem: return "A valuable treasure"
    case .gloves: return "Provides protection for hands"
    }
  }
}

enum GameEvent: EmittableEvent {
  case looted(items: [Item])
  case damaged(target: Node)
  case dropped(items: [Item])
}

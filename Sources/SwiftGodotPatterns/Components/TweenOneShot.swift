import SwiftGodot

/// A one-shot tween helper that cleans itself up by default.
///
/// `TweenOneShot` creates a `Tween`, configures one or more steps, and queues
/// itself for deletion when the tween finishes.
/// This lets you drop a temporary node in the scene, kick off an effect,
/// and not worry about lifetime management.
///
/// ### Usage
/// ```swift
/// // Spawn and run a quick fade:
/// let fx = TweenOneShot.new()
/// addChild(node: fx)
/// fx.fadeOut(sprite, duration: 0.25)
///
/// // Or a punch-scale:
/// let punch = TweenOneShot.new()
/// addChild(node: punch)
/// punch.punchScale(enemy, amount: Vector2(0.25, 0.25), duration: 0.2)
/// ```
@Godot
public final class TweenOneShot: Node {
  /// When `true`, this node calls `queueFree()` after the created tween finishes.
  public var autoFree: Bool = true

  /// Fades a `CanvasItem`'s alpha from its current value to `0`.
  ///
  /// This animates the `modulate:a` property, preserving RGB.
  @discardableResult
  public func fadeOut(_ node: CanvasItem, duration: Double) -> Tween {
    guard let tween = createTween() else {
      if autoFree { queueFree() }
      return Tween()
    }
    _ = tween.tweenProperty(object: node, property: "modulate:a", finalVal: Variant(0.0), duration: duration)
    if autoFree { _ = tween.finished.connect { [weak self] in self?.queueFree() } }
    return tween
  }

  /// Performs a two-phase "punch" scale (out, then back) on a `Node2D`.
  @discardableResult
  public func punchScale(_ node: Node2D, amount: Vector2, duration: Double) -> Tween {
    let start = node.scale
    guard let tween = createTween() else {
      if autoFree { queueFree() }
      return Tween()
    }
    _ = tween.tweenProperty(object: node, property: "scale", finalVal: Variant(start + amount), duration: duration * 0.45)
    _ = tween.tweenProperty(object: node, property: "scale", finalVal: Variant(start), duration: duration * 0.55)
    if autoFree { _ = tween.finished.connect { [weak self] in self?.queueFree() } }
    return tween
  }
}

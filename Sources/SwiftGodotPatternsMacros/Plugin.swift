import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct SwiftGodotPatternsMacros: CompilerPlugin {
  let providingMacros: [Macro.Type] = [OnSignalMacro.self]
}

/// Implements the `@OnSignal` macro, which generates a backing `_SignalBinderN` property
/// to connect the annotated method to a signal.
public struct OnSignalMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf decl: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let fn = decl.as(FunctionDeclSyntax.self) else { return [] }
    guard let tuple = node.arguments?.as(LabeledExprListSyntax.self) else { return [] }
    let args = Array(tuple)
    if args.count < 2 { return [] }

    let pathExpr = args[0].expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
    let kpExpr = args[1].expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
    let flagsExpr = (args.count >= 3 && args[2].label?.text == "flags")
      ? args[2].expression.description : "[]"

    // Parameters
    let params = Array(fn.signature.parameterClause.parameters)
    if params.isEmpty { return [] }

    // Be resilient if type annotation is missing.
    let senderType = (params.first?.type.description ?? "Object").trimmingCharacters(in: .whitespacesAndNewlines)
    let arity = max(0, params.count - 1)

    let fnName = fn.name.text
    let storageName = "__sig_\(fnName)"

    func binder(_ generic: String, connectArgs: String, callArgs: String) -> String {
      """
      private let \(storageName) = \(generic)(path: \(pathExpr), keyPath: \(kpExpr), flags: \(flagsExpr)) { [weak self] sender\(arity > 0 ? ", \(connectArgs)" : "") in
        self?.\(fnName)(\(callArgs))
      }
      """
    }

    let decl: String
    switch arity {
    case 0:
      decl = binder("_SignalBinder0<\(senderType)>",
                    connectArgs: "",
                    callArgs: "sender")
    case 1:
      let a0T = params[1].type.desc
      decl = binder("_SignalBinder1<\(senderType), \(a0T)>",
                    connectArgs: "a0",
                    callArgs: "sender, a0")
    case 2:
      let a0T = params[1].type.desc
      let a1T = params[2].type.desc
      decl = binder("_SignalBinder2<\(senderType), \(a0T), \(a1T)>",
                    connectArgs: "a0, a1",
                    callArgs: "sender, a0, a1")
    case 3:
      let a0T = params[1].type.desc
      let a1T = params[2].type.desc
      let a2T = params[3].type.desc
      decl = binder("_SignalBinder3<\(senderType), \(a0T), \(a1T), \(a2T)>",
                    connectArgs: "a0, a1, a2",
                    callArgs: "sender, a0, a1, a2")
    case 4:
      let a0T = params[1].type.desc
      let a1T = params[2].type.desc
      let a2T = params[3].type.desc
      let a3T = params[4].type.desc
      decl = binder("_SignalBinder4<\(senderType), \(a0T), \(a1T), \(a2T), \(a3T)>",
                    connectArgs: "a0, a1, a2, a3",
                    callArgs: "sender, a0, a1, a2, a3")
    case 5:
      let a0T = params[1].type.desc
      let a1T = params[2].type.desc
      let a2T = params[3].type.desc
      let a3T = params[4].type.desc
      let a4T = params[5].type.desc
      decl = binder("_SignalBinder5<\(senderType), \(a0T), \(a1T), \(a2T), \(a3T), \(a4T)>",
                    connectArgs: "a0, a1, a2, a3, a4",
                    callArgs: "sender, a0, a1, a2, a3, a4")
    case 6:
      let a0T = params[1].type.desc
      let a1T = params[2].type.desc
      let a2T = params[3].type.desc
      let a3T = params[4].type.desc
      let a4T = params[5].type.desc
      let a5T = params[6].type.desc
      decl = binder("_SignalBinder6<\(senderType), \(a0T), \(a1T), \(a2T), \(a3T), \(a4T), \(a5T)>",
                    connectArgs: "a0, a1, a2, a3, a4, a5",
                    callArgs: "sender, a0, a1, a2, a3, a4, a5")
    case 7:
      let a0T = params[1].type.desc
      let a1T = params[2].type.desc
      let a2T = params[3].type.desc
      let a3T = params[4].type.desc
      let a4T = params[5].type.desc
      let a5T = params[6].type.desc
      let a6T = params[7].type.desc
      decl = binder("_SignalBinder7<\(senderType), \(a0T), \(a1T), \(a2T), \(a3T), \(a4T), \(a5T), \(a6T)>",
                    connectArgs: "a0, a1, a2, a3, a4, a5, a6",
                    callArgs: "sender, a0, a1, a2, a3, a4, a5, a6")
    default:
      return []
    }

    return [DeclSyntax(stringLiteral: decl)]
  }
}

private extension TypeSyntax {
  var desc: String {
    description.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

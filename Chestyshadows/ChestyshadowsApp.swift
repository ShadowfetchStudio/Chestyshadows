import AppKit
import SwiftUI

@main
struct ChestyshadowsApp: App {
    @StateObject private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup("Chestyshadows") {
            MainGameView(viewModel: viewModel)
                .frame(minWidth: 960, minHeight: 680)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1100, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    viewModel.startNewGame()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandMenu("Match") {
                Button("Hint Best Move") {
                    viewModel.requestHint()
                }
                .keyboardShortcut("y", modifiers: [.command])
                .disabled(!viewModel.isHumanTurn || viewModel.isAIThinking)

                Button("Undo Move") {
                    viewModel.undoMove()
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(viewModel.moveHistory.isEmpty)

                Button("Redo Move") {
                    viewModel.redoMove()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(viewModel.redoStack.isEmpty)

                Divider()

                Button("Flip Board Orientation") {
                    viewModel.isFlipped.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Toggle Shadow Threat Map") {
                    viewModel.showShadowThreatMap.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button(viewModel.soundMuted ? "Unmute Sound Effects" : "Mute Sound Effects") {
                    viewModel.soundMuted.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Divider()

                Button("Copy Match PGN") {
                    let pgn = viewModel.exportPGN()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pgn, forType: .string)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}

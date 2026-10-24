import AppKit
import SwiftUI

public struct MainGameView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var showFENInputSheet: Bool = false
    @State private var customFENInput: String = ""
    @State private var copiedStatusMessage: String? = nil

    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }

    private var topColor: PieceColor {
        viewModel.isFlipped ? .white : .black
    }

    private var bottomColor: PieceColor {
        viewModel.isFlipped ? .black : .white
    }

    public var body: some View {
        ZStack {
            // Deep atmospheric background gradient
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(srgbRed: 0.05, green: 0.06, blue: 0.09, alpha: 1.0)),
                    Color(nsColor: NSColor(srgbRed: 0.08, green: 0.10, blue: 0.15, alpha: 1.0)),
                    Color(nsColor: NSColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topToolbar
                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack(spacing: 20) {
                    // Left: Vertical Evaluation Bar + Board Stage
                    HStack(spacing: 14) {
                        evaluationBar
                            .padding(.vertical, 52)

                        VStack(spacing: 10) {
                            playerStrip(for: topColor)
                            BoardCanvasView(viewModel: viewModel)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            playerStrip(for: bottomColor)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Right: Inspector Sidebar
                    inspectorSidebar
                        .frame(width: 320)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
        }
        .sheet(isPresented: $showFENInputSheet) {
            fenLoaderSheet
        }
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack(spacing: 14) {
            // Brand title & Opening pill
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(viewModel.theme.accentColor.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(viewModel.theme.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("CHESTYSHADOWS")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.95))
                    Text(viewModel.currentOpeningName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(viewModel.theme.accentColor.opacity(0.9))
                        .lineLimit(1)
                }
            }

            Spacer()

            if let copied = copiedStatusMessage {
                Text(copied)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.green.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.14)))
            }

            // Action Toolbar Buttons
            HStack(spacing: 8) {
                toolbarButton(title: "New Game", icon: "plus.circle.fill", prominent: true) {
                    viewModel.startNewGame()
                }

                toolbarButton(
                    title: "Hint",
                    icon: "sparkles",
                    disabled: !viewModel.isHumanTurn || viewModel.isAIThinking
                ) {
                    viewModel.requestHint()
                }

                toolbarButton(
                    title: "Undo",
                    icon: "arrow.uturn.backward",
                    disabled: viewModel.moveHistory.isEmpty
                ) {
                    viewModel.undoMove()
                }

                toolbarButton(
                    title: "Redo",
                    icon: "arrow.uturn.forward",
                    disabled: viewModel.redoStack.isEmpty
                ) {
                    viewModel.redoMove()
                }

                toolbarButton(title: "Flip", icon: "arrow.up.arrow.down") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        viewModel.isFlipped.toggle()
                    }
                }

                toolbarButton(
                    title: "Shadows",
                    icon: viewModel.showShadowThreatMap ? "eye.fill" : "eye",
                    active: viewModel.showShadowThreatMap
                ) {
                    viewModel.showShadowThreatMap.toggle()
                }

                toolbarButton(
                    title: viewModel.soundMuted ? "Muted" : "Sound",
                    icon: viewModel.soundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
                ) {
                    viewModel.soundMuted.toggle()
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .background(Color.black.opacity(0.28))
    }

    private func toolbarButton(
        title: String,
        icon: String,
        prominent: Bool = false,
        active: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(
                disabled
                    ? Color.white.opacity(0.30)
                    : (prominent ? Color.black : (active ? viewModel.theme.accentColor : Color.white.opacity(0.88)))
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        prominent
                            ? viewModel.theme.accentColor
                            : (active ? viewModel.theme.accentColor.opacity(0.18) : Color.white.opacity(0.07))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        active ? viewModel.theme.accentColor.opacity(0.55) : Color.white.opacity(0.09),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Evaluation Bar

    private var evaluationBar: some View {
        GeometryReader { geo in
            let clampedCP = Double(max(-1200, min(1200, viewModel.evaluationCentipawns)))
            // Sigmoid-like mapping of centipawns into [0.05, 0.95]
            let whiteRatio = 0.5 + 0.45 * tanh(clampedCP / 420.0)
            let topIsWhite = viewModel.isFlipped
            let topFillRatio = topIsWhite ? whiteRatio : (1.0 - whiteRatio)

            let evalText: String = {
                let pawns = Double(viewModel.evaluationCentipawns) / 100.0
                if abs(pawns) >= 90.0 {
                    return pawns > 0 ? "+M" : "-M"
                }
                return String(format: "%+.1f", pawns)
            }()

            ZStack(alignment: .top) {
                // Bottom color base
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        topIsWhite
                            ? Color(nsColor: NSColor(srgbRed: 0.12, green: 0.14, blue: 0.20, alpha: 1.0))
                            : Color(nsColor: NSColor(srgbRed: 0.90, green: 0.87, blue: 0.80, alpha: 1.0))
                    )

                // Top color fill
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        topIsWhite
                            ? Color(nsColor: NSColor(srgbRed: 0.90, green: 0.87, blue: 0.80, alpha: 1.0))
                            : Color(nsColor: NSColor(srgbRed: 0.12, green: 0.14, blue: 0.20, alpha: 1.0))
                    )
                    .frame(height: max(8, geo.size.height * CGFloat(topFillRatio)))
                    .animation(.easeInOut(duration: 0.28), value: viewModel.evaluationCentipawns)

                // Center tick line
                Rectangle()
                    .fill(viewModel.theme.accentColor.opacity(0.65))
                    .frame(height: 1.5)
                    .offset(y: geo.size.height * 0.5)

                VStack {
                    Spacer()
                    Text(evalText)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            viewModel.evaluationCentipawns >= 0
                                ? Color.black.opacity(0.82)
                                : Color.white.opacity(0.88)
                        )
                        .padding(.bottom, 5)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .frame(width: 28)
    }

    // MARK: - Player Strip (Top & Bottom)

    private func playerStrip(for color: PieceColor) -> some View {
        let isAI = viewModel.aiDifficulty != .passAndPlay && color != viewModel.humanColor
        let isActiveTurn = viewModel.displayedBoard.sideToMove == color && viewModel.activeTermination == nil
        let playerTitle = isAI
            ? "Chestyshadows • \(viewModel.aiDifficulty.rawValue)"
            : (viewModel.aiDifficulty == .passAndPlay ? "\(color.displayName) Player" : "You (\(color.displayName))")
        let subtitle = isAI
            ? "\(viewModel.aiDifficulty.subtitle) • ~\(viewModel.aiDifficulty.estimatedELO) ELO"
            : "Human Commander"

        let captured = viewModel.displayedBoard.capturedPieces(by: color)
        let rawDiff = viewModel.displayedBoard.materialDiff
        let advantage = color == .white ? max(0, rawDiff) : max(0, -rawDiff)
        let clockSeconds = (color == .white) ? viewModel.whiteTimeRemaining : viewModel.blackTimeRemaining

        return HStack(spacing: 12) {
            // Emblem
            ZStack {
                Circle()
                    .fill(
                        color == .white
                            ? Color(nsColor: NSColor(srgbRed: 0.92, green: 0.89, blue: 0.82, alpha: 1.0))
                            : Color(nsColor: NSColor(srgbRed: 0.14, green: 0.16, blue: 0.22, alpha: 1.0))
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isActiveTurn ? viewModel.theme.accentColor : Color.white.opacity(0.18),
                                lineWidth: isActiveTurn ? 2.0 : 1.0
                            )
                    )

                Image(systemName: isAI ? "cpu" : "person.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color == .white ? Color.black.opacity(0.82) : Color.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(playerTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.95))

                    if isActiveTurn {
                        if isAI && viewModel.isAIThinking {
                            Text("THINKING…")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(viewModel.theme.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(viewModel.theme.accentColor.opacity(0.16)))
                        } else {
                            Circle()
                                .fill(viewModel.theme.accentColor)
                                .frame(width: 7, height: 7)
                        }
                    }
                }

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            // Captured Pieces & Material Advantage Badge
            HStack(spacing: 2) {
                ForEach(Array(captured.enumerated()), id: \.offset) { _, kind in
                    Text(Piece(color.opposite, kind).unicodeSymbol)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
                if advantage > 0 {
                    Text("+\(advantage)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.theme.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(viewModel.theme.accentColor.opacity(0.15)))
                        .padding(.leading, 4)
                }
            }

            // Digital Chess Clock
            if let secs = clockSeconds {
                Text(formatClock(secs))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        secs < 30.0
                            ? Color.red.opacity(0.95)
                            : (isActiveTurn ? viewModel.theme.accentColor : Color.white.opacity(0.70))
                    )
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isActiveTurn ? viewModel.theme.accentColor.opacity(0.55) : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isActiveTurn ? viewModel.theme.accentColor.opacity(0.35) : Color.white.opacity(0.07),
                    lineWidth: 1
                )
        )
    }

    private func formatClock(_ seconds: TimeInterval) -> String {
        let clamped = max(0, Int(ceil(seconds)))
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Right Inspector Sidebar

    private var inspectorSidebar: some View {
        VStack(spacing: 12) {
            statusCard
            matchSettingsCard
            visualStudioCard
            moveHistoryCard
        }
    }

    private var statusCard: some View {
        let term = viewModel.activeTermination
        let inCheck = viewModel.displayedBoard.isInCheck(viewModel.displayedBoard.sideToMove)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let term {
                    Image(systemName: "flag.checkered.2.crossed")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(viewModel.theme.accentColor)
                    Text(term.title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.white)
                } else if inCheck {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.95))
                    Text("\(viewModel.displayedBoard.sideToMove.displayName) is in Check!")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.95))
                } else {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.theme.accentColor)
                    Text("\(viewModel.displayedBoard.sideToMove.displayName) to Move")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.95))
                }

                Spacer()

                if term != nil {
                    Button("Rematch") {
                        viewModel.startNewGame()
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(viewModel.theme.accentColor))
                    .buttonStyle(.plain)
                } else if !viewModel.moveHistory.isEmpty {
                    Button("Resign") {
                        viewModel.resignCurrentGame()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.14)))
                    .buttonStyle(.plain)
                }
            }

            if let term {
                Text(term.subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.70))
            } else if viewModel.isViewingHistory {
                HStack {
                    Text("Inspecting historical move")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(viewModel.theme.accentColor)
                    Spacer()
                    Button("Return to Live") {
                        viewModel.viewingHistoryIndex = nil
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(viewModel.theme.accentColor)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(13)
        .background(cardBackground)
    }

    private var matchSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "MATCH CONFIGURATION", icon: "slider.horizontal.3")

            // Mode / AI Difficulty
            HStack {
                Text("Opponent")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer()
                Picker("", selection: $viewModel.aiDifficulty) {
                    ForEach(AIDifficulty.allCases) { diff in
                        Text(diff.rawValue).tag(diff)
                    }
                }
                .labelsHidden()
                .frame(width: 175)
            }

            // Play As
            if viewModel.aiDifficulty != .passAndPlay {
                HStack {
                    Text("Play As")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Spacer()
                    Picker("", selection: $viewModel.humanColor) {
                        Text("White").tag(PieceColor.white)
                        Text("Black").tag(PieceColor.black)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 175)
                }
            }

            // Time Control
            HStack {
                Text("Clock")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer()
                Picker("", selection: $viewModel.timeControl) {
                    ForEach(TimeControl.allCases) { tc in
                        Text(tc.rawValue).tag(tc)
                    }
                }
                .labelsHidden()
                .frame(width: 175)
                .onChange(of: viewModel.timeControl) { _, newValue in
                    viewModel.startNewGame(time: newValue)
                }
            }
        }
        .padding(13)
        .background(cardBackground)
    }

    private var visualStudioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "SHADOW & BOARD STUDIO", icon: "sparkles.rectangle.stack")

            // Board Theme Picker
            HStack {
                Text("Theme")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer()
                Picker("", selection: $viewModel.theme) {
                    ForEach(BoardTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .labelsHidden()
                .frame(width: 175)
            }

            // Shadow Depth Slider
            HStack(spacing: 10) {
                Text("Shadow Depth")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                Slider(value: $viewModel.shadowIntensity, in: 0.0...1.0)
                    .tint(viewModel.theme.accentColor)
                Text("\(Int(round(viewModel.shadowIntensity * 100)))%")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .frame(width: 34, alignment: .trailing)
            }

            // Shadow Threat Map Toggle
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shadow Threat Overlay")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                    Text("Gold: White • Violet: Black • Crimson: Contested")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.50))
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.showShadowThreatMap.toggle()
                    }
                } label: {
                    ZStack(alignment: viewModel.showShadowThreatMap ? .trailing : .leading) {
                        Capsule()
                            .fill(
                                viewModel.showShadowThreatMap
                                    ? viewModel.theme.accentColor
                                    : Color.white.opacity(0.14)
                            )
                            .frame(width: 40, height: 22)
                        Circle()
                            .fill(viewModel.showShadowThreatMap ? Color.black : Color.white.opacity(0.88))
                            .frame(width: 18, height: 18)
                            .padding(.horizontal, 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .background(cardBackground)
    }

    private var moveHistoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader(title: "MOVE LOG (\(viewModel.moveHistory.count) PLIES)", icon: "list.number")
                Spacer()
                if viewModel.isViewingHistory {
                    Button("Live") {
                        viewModel.viewingHistoryIndex = nil
                    }
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(viewModel.theme.accentColor)
                    .buttonStyle(.plain)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.movePairs.isEmpty {
                        VStack(spacing: 6) {
                            Text("No moves played yet")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.42))
                            Text("Click or drag any \(viewModel.board.sideToMove.displayName.lowercased()) piece to begin.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.white.opacity(0.30))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    } else {
                        VStack(spacing: 3) {
                            ForEach(viewModel.movePairs, id: \.moveNumber) { pair in
                                HStack(spacing: 6) {
                                    Text("\(pair.moveNumber).")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.42))
                                        .frame(width: 28, alignment: .leading)

                                    movePill(for: pair.white)

                                    if let black = pair.black {
                                        movePill(for: black)
                                    } else {
                                        Spacer()
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(pair.moveNumber.isMultiple(of: 2) ? Color.white.opacity(0.025) : Color.clear)
                                )
                                .id(pair.moveNumber)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.moveHistory.count) { _, _ in
                    if let lastNum = viewModel.movePairs.last?.moveNumber {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(lastNum, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
                .overlay(Color.white.opacity(0.08))

            // PGN / FEN Footer Buttons
            HStack(spacing: 8) {
                Button {
                    let pgn = viewModel.exportPGN()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pgn, forType: .string)
                    showCopiedToast("Copied PGN")
                } label: {
                    Label("Copy PGN", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryInspectorButtonStyle())

                Button {
                    let fen = viewModel.currentFEN()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(fen, forType: .string)
                    showCopiedToast("Copied FEN")
                } label: {
                    Label("Copy FEN", systemImage: "number")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryInspectorButtonStyle())

                Button {
                    customFENInput = viewModel.currentFEN()
                    showFENInputSheet = true
                } label: {
                    Label("Load FEN", systemImage: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryInspectorButtonStyle())
            }
        }
        .padding(13)
        .frame(maxHeight: .infinity)
        .background(cardBackground)
    }

    private func movePill(for entry: MoveHistoryEntry) -> some View {
        let isSelected = (viewModel.viewingHistoryIndex == entry.plyIndex) ||
            (viewModel.viewingHistoryIndex == nil && entry.plyIndex == viewModel.moveHistory.count - 1)

        return Button {
            if entry.plyIndex == viewModel.moveHistory.count - 1 {
                viewModel.viewingHistoryIndex = nil
            } else {
                viewModel.viewingHistoryIndex = entry.plyIndex
            }
        } label: {
            Text(entry.san)
                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isSelected ? viewModel.theme.accentColor : Color.white.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? viewModel.theme.accentColor.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(viewModel.theme.accentColor)
            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.65))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func showCopiedToast(_ text: String) {
        copiedStatusMessage = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if copiedStatusMessage == text {
                copiedStatusMessage = nil
            }
        }
    }

    // MARK: - FEN Loader Sheet

    private var fenLoaderSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Load Custom FEN Position")
                .font(.system(size: 15, weight: .bold))

            Text("Paste any valid Forsyth-Edwards Notation (FEN) string below:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", text: $customFENInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 460)

            HStack {
                Button("Reset to Starting FEN") {
                    customFENInput = BoardState.initialFEN
                }
                Spacer()
                Button("Cancel") {
                    showFENInputSheet = false
                }
                Button("Load Position") {
                    if viewModel.loadFEN(customFENInput) {
                        showFENInputSheet = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }
}

private struct SecondaryInspectorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.65 : 0.85))
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            )
    }
}

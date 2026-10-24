import AppKit
import Combine
import Foundation
import SwiftUI

public struct MoveHistoryEntry: Identifiable, Equatable {
    public let id = UUID()
    public let plyIndex: Int
    public let move: Move
    public let san: String
    public let boardAfter: BoardState
    public let uci: String
}

public struct PieceFlightAnimation: Equatable {
    public let piece: Piece
    public let from: Square
    public let to: Square
    public let secondaryPiece: Piece?
    public let secondaryFrom: Square?
    public let secondaryTo: Square?
    public let startTime: TimeInterval
    public let duration: TimeInterval

    public func progress(at now: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 1.0 }
        let raw = CGFloat((now - startTime) / duration)
        let t = max(0.0, min(1.0, raw))
        // Smooth ease-out cubic curve
        return 1.0 - pow(1.0 - t, 3.0)
    }
}

@MainActor
public final class GameViewModel: ObservableObject {
    // MARK: - Published Game State

    @Published public private(set) var board: BoardState = .initial
    @Published public private(set) var moveHistory: [MoveHistoryEntry] = []
    @Published public private(set) var redoStack: [MoveHistoryEntry] = []
    @Published public var viewingHistoryIndex: Int? = nil // nil = live board

    @Published public var aiDifficulty: AIDifficulty = .shadowKnight {
        didSet {
            triggerAIMoveIfNeeded()
        }
    }
    @Published public var humanColor: PieceColor = .white {
        didSet {
            if humanColor == .black && !isFlipped {
                isFlipped = true
            } else if humanColor == .white && isFlipped {
                isFlipped = false
            }
            triggerAIMoveIfNeeded()
        }
    }
    @Published public var timeControl: TimeControl = .rapid10m

    // MARK: - Visual & Shadow Settings

    @Published public var theme: BoardTheme = .shadowNocturne
    @Published public var isFlipped: Bool = false
    @Published public var showShadowThreatMap: Bool = false
    @Published public var showCoordinates: Bool = true
    @Published public var shadowIntensity: Double = 0.85
    @Published public var soundMuted: Bool = false {
        didSet {
            SoundEffects.shared.isMuted = soundMuted
        }
    }

    // MARK: - Selection, Dragging & Animation

    @Published public var selectedSquare: Square? = nil
    @Published public private(set) var legalMovesForSelected: [Move] = []
    @Published public var pendingPromotionMoves: [Move]? = nil

    @Published public var draggedSquare: Square? = nil
    @Published public var dragCurrentPoint: CGPoint? = nil
    @Published public var activeAnimation: PieceFlightAnimation? = nil

    @Published public private(set) var hintMove: Move? = nil
    @Published public private(set) var isAIThinking: Bool = false
    @Published public private(set) var evaluationCentipawns: Int = 0
    @Published public private(set) var currentOpeningName: String = "Starting Position"

    // MARK: - Clocks

    @Published public private(set) var whiteTimeRemaining: TimeInterval? = 600
    @Published public private(set) var blackTimeRemaining: TimeInterval? = 600
    @Published public private(set) var timeoutTermination: GameTermination? = nil

    private var positionCounts: [String: Int] = [:]
    private var aiTask: Task<Void, Never>? = nil
    private var clockTimer: Timer? = nil
    private var lastClockTick: Date? = nil

    public init() {
        resetPositionCounts(for: .initial)
        configureClocks()
        startClockTimer()
    }

    // MARK: - Computed Properties

    public var displayedBoard: BoardState {
        if let idx = viewingHistoryIndex, idx >= 0, idx < moveHistory.count {
            return moveHistory[idx].boardAfter
        }
        return board
    }

    public var isViewingHistory: Bool {
        viewingHistoryIndex != nil
    }

    public var activeTermination: GameTermination? {
        if let timeoutTermination {
            return timeoutTermination
        }
        return board.termination(positionCounts: positionCounts)
    }

    public var isHumanTurn: Bool {
        guard activeTermination == nil, !isViewingHistory else { return false }
        if aiDifficulty == .passAndPlay {
            return true
        }
        return board.sideToMove == humanColor
    }

    public var movePairs: [(moveNumber: Int, white: MoveHistoryEntry, black: MoveHistoryEntry?)] {
        var result: [(Int, MoveHistoryEntry, MoveHistoryEntry?)] = []
        var i = 0
        while i < moveHistory.count {
            let whiteEntry = moveHistory[i]
            let blackEntry = (i + 1 < moveHistory.count) ? moveHistory[i + 1] : nil
            result.append((i / 2 + 1, whiteEntry, blackEntry))
            i += 2
        }
        return result
    }

    // MARK: - Game Lifecycle

    public func startNewGame(playAs: PieceColor? = nil, difficulty: AIDifficulty? = nil, time: TimeControl? = nil) {
        aiTask?.cancel()
        isAIThinking = false
        if let playAs { humanColor = playAs }
        if let difficulty { aiDifficulty = difficulty }
        if let time { timeControl = time }

        board = .initial
        moveHistory.removeAll()
        redoStack.removeAll()
        viewingHistoryIndex = nil
        selectedSquare = nil
        legalMovesForSelected = []
        pendingPromotionMoves = nil
        draggedSquare = nil
        dragCurrentPoint = nil
        activeAnimation = nil
        hintMove = nil
        timeoutTermination = nil
        evaluationCentipawns = 0
        currentOpeningName = "Starting Position"

        resetPositionCounts(for: board)
        configureClocks()
        isFlipped = (aiDifficulty != .passAndPlay && humanColor == .black)
        triggerAIMoveIfNeeded()
    }

    public func resignCurrentGame() {
        guard activeTermination == nil else { return }
        aiTask?.cancel()
        isAIThinking = false
        let resigningColor = (aiDifficulty == .passAndPlay) ? board.sideToMove : humanColor
        timeoutTermination = .resignation(winner: resigningColor.opposite)
        SoundEffects.shared.play(.defeat)
    }

    // MARK: - Board Interaction (Click & Drag)

    public func handleSquareTap(_ square: Square) {
        if isViewingHistory {
            viewingHistoryIndex = nil
        }
        guard isHumanTurn, pendingPromotionMoves == nil else { return }

        // Check if tapping a legal destination for the currently selected piece
        if let selected = selectedSquare {
            let matchingMoves = legalMovesForSelected.filter { $0.from == selected && $0.to == square }
            if !matchingMoves.isEmpty {
                executeOrPromote(candidates: matchingMoves, animate: true)
                return
            }
        }

        // Otherwise select own piece on `square`
        if let piece = board[square], piece.color == board.sideToMove {
            selectedSquare = square
            legalMovesForSelected = board.legalMoves(from: square)
            hintMove = nil
        } else {
            selectedSquare = nil
            legalMovesForSelected = []
        }
    }

    public func beginDrag(from square: Square, at point: CGPoint) {
        if isViewingHistory {
            viewingHistoryIndex = nil
        }
        guard isHumanTurn, pendingPromotionMoves == nil else { return }
        guard let piece = board[square], piece.color == board.sideToMove else { return }

        selectedSquare = square
        legalMovesForSelected = board.legalMoves(from: square)
        draggedSquare = square
        dragCurrentPoint = point
        hintMove = nil
    }

    public func updateDrag(to point: CGPoint) {
        guard draggedSquare != nil else { return }
        dragCurrentPoint = point
    }

    public func endDrag(on targetSquare: Square?) {
        guard let from = draggedSquare else { return }
        draggedSquare = nil
        dragCurrentPoint = nil

        guard let to = targetSquare, to != from else { return }
        let matchingMoves = legalMovesForSelected.filter { $0.from == from && $0.to == to }
        if !matchingMoves.isEmpty {
            executeOrPromote(candidates: matchingMoves, animate: false)
        }
    }

    public func completePromotion(with pieceKind: PieceKind) {
        guard let candidates = pendingPromotionMoves else { return }
        pendingPromotionMoves = nil
        if let chosen = candidates.first(where: { $0.promotion == pieceKind }) ?? candidates.first {
            commitMove(chosen, animate: false)
        }
    }

    public func cancelPromotion() {
        pendingPromotionMoves = nil
    }

    private func executeOrPromote(candidates: [Move], animate: Bool) {
        if candidates.count > 1 && candidates.first?.promotion != nil {
            pendingPromotionMoves = candidates
            return
        }
        if let move = candidates.first {
            commitMove(move, animate: animate)
        }
    }

    // MARK: - Move Execution & Animation

    public func commitMove(_ move: Move, animate: Bool) {
        let sanString = board.san(for: move)
        let movingPiece = board[move.from]
        let wasCapture = board.capturedPiece(for: move) != nil
        let nextBoard = board.applying(move)

        // Increment clock for side that just moved
        if let inc = timeControl.incrementSeconds, inc > 0, moveHistory.count >= 2 {
            if board.sideToMove == .white, let w = whiteTimeRemaining {
                whiteTimeRemaining = w + inc
            } else if board.sideToMove == .black, let b = blackTimeRemaining {
                blackTimeRemaining = b + inc
            }
        }

        // Setup smooth flight animation if requested
        if animate, let piece = movingPiece {
            var secPiece: Piece? = nil
            var secFrom: Square? = nil
            var secTo: Square? = nil
            if move.isKingsideCastle {
                secPiece = Piece(board.sideToMove, .rook)
                secFrom = Square(file: 7, rank: move.from.rank)
                secTo = Square(file: 5, rank: move.from.rank)
            } else if move.isQueensideCastle {
                secPiece = Piece(board.sideToMove, .rook)
                secFrom = Square(file: 0, rank: move.from.rank)
                secTo = Square(file: 3, rank: move.from.rank)
            }

            let now = CACurrentMediaTime()
            let duration: TimeInterval = 0.21
            activeAnimation = PieceFlightAnimation(
                piece: piece,
                from: move.from,
                to: move.to,
                secondaryPiece: secPiece,
                secondaryFrom: secFrom,
                secondaryTo: secTo,
                startTime: now,
                duration: duration
            )

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((duration + 0.02) * 1_000_000_000))
                if let self, self.activeAnimation?.startTime == now {
                    self.activeAnimation = nil
                }
            }
        } else {
            activeAnimation = nil
        }

        let entry = MoveHistoryEntry(
            plyIndex: moveHistory.count,
            move: move,
            san: sanString,
            boardAfter: nextBoard,
            uci: move.uciNotation
        )

        board = nextBoard
        moveHistory.append(entry)
        redoStack.removeAll()
        viewingHistoryIndex = nil
        selectedSquare = nil
        legalMovesForSelected = []
        hintMove = nil

        let repKey = nextBoard.repetitionKey
        positionCounts[repKey, default: 0] += 1

        // Update opening name if recognized
        let uciList = moveHistory.map(\.uci)
        if let opening = OpeningBook.openingName(for: uciList) {
            currentOpeningName = opening
        } else if moveHistory.isEmpty {
            currentOpeningName = "Starting Position"
        }

        // Update static evaluation
        evaluationCentipawns = ChessAI.evaluate(nextBoard)

        // Play acoustic feedback
        playMoveSound(for: move, wasCapture: wasCapture, resultingBoard: nextBoard)

        // Trigger AI reply if needed
        triggerAIMoveIfNeeded()
    }

    private func playMoveSound(for move: Move, wasCapture: Bool, resultingBoard: BoardState) {
        if let term = resultingBoard.termination(positionCounts: positionCounts) {
            switch term {
            case .checkmate(let winner), .timeOut(let winner), .resignation(let winner):
                if aiDifficulty == .passAndPlay || winner == humanColor {
                    SoundEffects.shared.play(.victory)
                } else {
                    SoundEffects.shared.play(.defeat)
                }
            default:
                SoundEffects.shared.play(.move)
            }
            return
        }

        if resultingBoard.isInCheck(resultingBoard.sideToMove) {
            SoundEffects.shared.play(.check)
        } else if move.isCastle {
            SoundEffects.shared.play(.castle)
        } else if wasCapture {
            SoundEffects.shared.play(.capture)
        } else {
            SoundEffects.shared.play(.move)
        }
    }

    // MARK: - AI Execution & Hint

    private func triggerAIMoveIfNeeded() {
        aiTask?.cancel()
        guard activeTermination == nil else {
            isAIThinking = false
            return
        }
        guard aiDifficulty != .passAndPlay, board.sideToMove != humanColor else {
            isAIThinking = false
            return
        }

        isAIThinking = true
        let snapshotBoard = board
        let difficulty = aiDifficulty
        let historyUCI = moveHistory.map(\.uci)

        aiTask = Task { @MainActor [weak self] in
            // Brief natural pause so the human's move animation settles smoothly
            try? await Task.sleep(nanoseconds: 230_000_000)
            guard !Task.isCancelled else { return }

            let result = await Task.detached(priority: .userInitiated) {
                ChessAI.chooseMove(for: snapshotBoard, difficulty: difficulty, moveHistoryUCI: historyUCI)
            }.value

            guard !Task.isCancelled, let self else { return }
            self.isAIThinking = false
            if let chosenMove = result.move {
                self.commitMove(chosenMove, animate: true)
            }
        }
    }

    public func requestHint() {
        guard isHumanTurn, !isAIThinking else { return }
        let snapshotBoard = board
        let historyUCI = moveHistory.map(\.uci)

        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                ChessAI.chooseMove(for: snapshotBoard, difficulty: .shadowMaster, moveHistoryUCI: historyUCI)
            }.value
            guard let self else { return }
            self.hintMove = result.move
            if let from = result.move?.from {
                self.selectedSquare = from
                self.legalMovesForSelected = self.board.legalMoves(from: from)
            }
        }
    }

    // MARK: - Undo / Redo / History Scrubbing

    public func undoMove() {
        guard !moveHistory.isEmpty else { return }
        aiTask?.cancel()
        isAIThinking = false
        viewingHistoryIndex = nil
        selectedSquare = nil
        legalMovesForSelected = []
        hintMove = nil

        // If playing vs AI and it's human's turn, undo both AI's reply and human's last move
        let pliesToUndo = (aiDifficulty != .passAndPlay && board.sideToMove == humanColor && moveHistory.count >= 2) ? 2 : 1

        for _ in 0..<pliesToUndo {
            guard let popped = moveHistory.popLast() else { break }
            redoStack.append(popped)
        }

        board = moveHistory.last?.boardAfter ?? .initial
        rebuildPositionCounts()
        let rawEval = ChessAI.evaluate(board)
        evaluationCentipawns = board.sideToMove == .white ? rawEval : -rawEval
        SoundEffects.shared.play(.move)
    }

    public func redoMove() {
        guard !redoStack.isEmpty else { return }
        aiTask?.cancel()
        isAIThinking = false
        viewingHistoryIndex = nil

        let pliesToRedo = (aiDifficulty != .passAndPlay && redoStack.count >= 2) ? 2 : 1
        for _ in 0..<pliesToRedo {
            guard let entry = redoStack.popLast() else { break }
            moveHistory.append(entry)
            board = entry.boardAfter
        }

        rebuildPositionCounts()
        let rawEval = ChessAI.evaluate(board)
        evaluationCentipawns = board.sideToMove == .white ? rawEval : -rawEval
        SoundEffects.shared.play(.move)
        triggerAIMoveIfNeeded()
    }

    private func resetPositionCounts(for initialBoard: BoardState) {
        positionCounts = [initialBoard.repetitionKey: 1]
    }

    private func rebuildPositionCounts() {
        positionCounts = [BoardState.initial.repetitionKey: 1]
        for entry in moveHistory {
            positionCounts[entry.boardAfter.repetitionKey, default: 0] += 1
        }
    }

    // MARK: - Chess Clocks

    private func configureClocks() {
        if let initial = timeControl.initialSeconds {
            whiteTimeRemaining = initial
            blackTimeRemaining = initial
        } else {
            whiteTimeRemaining = nil
            blackTimeRemaining = nil
        }
        lastClockTick = Date()
    }

    private func startClockTimer() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickClocks()
            }
        }
    }

    private func tickClocks() {
        let now = Date()
        defer { lastClockTick = now }

        guard activeTermination == nil, !moveHistory.isEmpty else { return }
        guard let prev = lastClockTick else { return }
        let dt = now.timeIntervalSince(prev)
        guard dt > 0 && dt < 2.0 else { return }

        if board.sideToMove == .white, let w = whiteTimeRemaining {
            let nextW = max(0.0, w - dt)
            whiteTimeRemaining = nextW
            if nextW <= 0.0 {
                timeoutTermination = .timeout(winner: .black)
                aiTask?.cancel()
                SoundEffects.shared.play(.defeat)
            }
        } else if board.sideToMove == .black, let b = blackTimeRemaining {
            let nextB = max(0.0, b - dt)
            blackTimeRemaining = nextB
            if nextB <= 0.0 {
                timeoutTermination = .timeout(winner: .white)
                aiTask?.cancel()
                SoundEffects.shared.play(.victory)
            }
        }
    }

    // MARK: - PGN & FEN Utilities

    public func currentFEN() -> String {
        displayedBoard.toFEN()
    }

    @discardableResult
    public func loadFEN(_ fenString: String) -> Bool {
        guard let parsed = BoardState(fen: fenString) else { return false }
        aiTask?.cancel()
        isAIThinking = false
        board = parsed
        moveHistory.removeAll()
        redoStack.removeAll()
        viewingHistoryIndex = nil
        selectedSquare = nil
        legalMovesForSelected = []
        pendingPromotionMoves = nil
        timeoutTermination = nil
        resetPositionCounts(for: parsed)
        currentOpeningName = "Custom FEN Position"
        let rawEval = ChessAI.evaluate(parsed)
        evaluationCentipawns = parsed.sideToMove == .white ? rawEval : -rawEval
        triggerAIMoveIfNeeded()
        return true
    }

    public func exportPGN() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd"
        let dateStr = dateFormatter.string(from: Date())

        let whiteName = (aiDifficulty == .passAndPlay || humanColor == .white) ? "Player" : "Chestyshadows (\(aiDifficulty.rawValue))"
        let blackName = (aiDifficulty == .passAndPlay || humanColor == .black) ? "Player" : "Chestyshadows (\(aiDifficulty.rawValue))"

        let resultStr: String
        if let term = activeTermination {
            resultStr = term.pgnResult
        } else {
            resultStr = "*"
        }

        var lines: [String] = [
            "[Event \"Chestyshadows Match\"]",
            "[Site \"Chestyshadows for macOS\"]",
            "[Date \"\(dateStr)\"]",
            "[White \"\(whiteName)\"]",
            "[Black \"\(blackName)\"]",
            "[Result \"\(resultStr)\"]",
            "[Opening \"\(currentOpeningName)\"]",
            ""
        ]

        var moveTokens: [String] = []
        for pair in movePairs {
            if let black = pair.black {
                moveTokens.append("\(pair.moveNumber). \(pair.white.san) \(black.san)")
            } else {
                moveTokens.append("\(pair.moveNumber). \(pair.white.san)")
            }
        }
        if resultStr != "*" {
            moveTokens.append(resultStr)
        }
        lines.append(moveTokens.joined(separator: " "))
        return lines.joined(separator: "\n")
    }
}

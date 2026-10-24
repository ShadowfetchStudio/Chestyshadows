import Foundation

public enum OpeningBook {
    private static let openings: [(moves: [String], name: String)] = [
        (["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"], "Ruy Lopez · Morphy Defense"),
        (["e4", "e5", "Nf3", "Nc6", "Bb5"], "Ruy Lopez (Spanish Game)"),
        (["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"], "Italian Game · Giuoco Piano"),
        (["e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6"], "Italian Game · Two Knights Defense"),
        (["e4", "e5", "Nf3", "Nc6", "Bc4"], "Italian Game"),
        (["e4", "e5", "Nf3", "Nc6", "d4"], "Scotch Game"),
        (["e4", "e5", "Nf3", "Nf6"], "Petrov's Defense"),
        (["e4", "e5", "f4"], "King's Gambit"),
        (["e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6"], "Sicilian Defense · Najdorf Variation"),
        (["e4", "c5", "Nf3", "Nc6"], "Sicilian Defense · Open"),
        (["e4", "c5"], "Sicilian Defense"),
        (["e4", "e6", "d4", "d5"], "French Defense"),
        (["e4", "c6", "d4", "d5"], "Caro-Kann Defense"),
        (["e4", "d5"], "Scandinavian Defense"),
        (["d4", "d5", "c4", "e6"], "Queen's Gambit Declined"),
        (["d4", "d5", "c4", "dxc4"], "Queen's Gambit Accepted"),
        (["d4", "d5", "c4", "c6"], "Slav Defense"),
        (["d4", "d5", "c4"], "Queen's Gambit"),
        (["d4", "Nf6", "c4", "g6", "Nc3", "Bg7"], "King's Indian Defense"),
        (["d4", "Nf6", "c4", "e6", "Nc3", "Bb4"], "Nimzo-Indian Defense"),
        (["d4", "Nf6", "c4"], "Indian Defense"),
        (["c4", "e5"], "English Opening · Reversed Sicilian"),
        (["c4"], "English Opening"),
        (["Nf3", "d5", "g3"], "King's Indian Attack"),
        (["e4", "e5"], "Open Game"),
        (["d4", "d5"], "Closed Game")
    ]

    public static func detectOpening(sanMoves: [String]) -> String {
        guard !sanMoves.isEmpty else { return "Standard Starting Position" }
        for entry in openings {
            if sanMoves.count >= entry.moves.count &&
               Array(sanMoves.prefix(entry.moves.count)) == entry.moves {
                return entry.name
            }
        }
        return "Custom / Middle Game"
    }

    public static func openingName(for uciMoves: [String]) -> String? {
        guard !uciMoves.isEmpty else { return "Starting Position" }
        var board = BoardState.initial
        var sanMoves: [String] = []
        for uci in uciMoves {
            guard let m = board.legalMoves().first(where: { $0.uci == uci }) else { break }
            sanMoves.append(board.san(for: m))
            board = board.applying(m)
        }
        for entry in openings {
            if sanMoves.count >= entry.moves.count &&
               Array(sanMoves.prefix(entry.moves.count)) == entry.moves {
                return entry.name
            }
        }
        return nil
    }

    /// Lightweight curated book replies keyed by prefix of UCI moves.
    private static let bookLines: [[String]] = [
        ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "c2c3", "g8f6"],
        ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6"],
        ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3", "a7a6"],
        ["e2e4", "e7e6", "d2d4", "d7d5", "b1c3", "g8f6"],
        ["e2e4", "c7c6", "d2d4", "d7d5", "b1c3", "d5e4", "c3e4", "c8f5"],
        ["d2d4", "d7d5", "c2c4", "e7e6", "b1c3", "g8f6", "c1g5", "f8e7"],
        ["d2d4", "g8f6", "c2c4", "g7g6", "b1c3", "f8g7", "e2e4", "d7d6"],
        ["c2c4", "e7e5", "b1c3", "g8f6", "g2g3", "d7d5"]
    ]

    public static func bookMove(for state: BoardState, uciHistory: [String]) -> Move? {
        guard uciHistory.count < 8 else { return nil }
        if uciHistory.isEmpty && state.repetitionKey != BoardState.standard.repetitionKey {
            return nil
        }
        let legal = state.legalMoves()
        var candidates: [Move] = []
        for line in bookLines {
            if line.count > uciHistory.count &&
               Array(line.prefix(uciHistory.count)) == uciHistory {
                let nextUCI = line[uciHistory.count]
                if let match = legal.first(where: { $0.uci == nextUCI }) {
                    candidates.append(match)
                }
            }
        }
        return candidates.randomElement()
    }
}

public enum ChessAI {
    // Piece-Square Tables (from White's perspective, rank 1 at index 0..7, rank 8 at 56..63)
    private static let pawnPST: [Int] = [
         0,  0,  0,  0,  0,  0,  0,  0,
         5, 10, 10,-20,-20, 10, 10,  5,
         5, -5,-10,  0,  0,-10, -5,  5,
         0,  0,  0, 22, 22,  0,  0,  0,
         5,  5, 10, 26, 26, 10,  5,  5,
        12, 12, 20, 32, 32, 20, 12, 12,
        50, 50, 50, 50, 50, 50, 50, 50,
         0,  0,  0,  0,  0,  0,  0,  0
    ]

    private static let knightPST: [Int] = [
        -50,-40,-30,-30,-30,-30,-40,-50,
        -40,-20,  0,  5,  5,  0,-20,-40,
        -30,  5, 12, 16, 16, 12,  5,-30,
        -30,  0, 16, 22, 22, 16,  0,-30,
        -30,  5, 16, 22, 22, 16,  5,-30,
        -30,  0, 12, 16, 16, 12,  0,-30,
        -40,-20,  0,  0,  0,  0,-20,-40,
        -50,-40,-30,-30,-30,-30,-40,-50
    ]

    private static let bishopPST: [Int] = [
        -20,-10,-10,-10,-10,-10,-10,-20,
        -10,  5,  0,  0,  0,  0,  5,-10,
        -10, 10, 10, 10, 10, 10, 10,-10,
        -10,  0, 12, 12, 12, 12,  0,-10,
        -10,  5,  6, 12, 12,  6,  5,-10,
        -10,  0,  6, 10, 10,  6,  0,-10,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -20,-10,-10,-10,-10,-10,-10,-20
    ]

    private static let rookPST: [Int] = [
          0,  0,  4,  8,  8,  4,  0,  0,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         -5,  0,  0,  0,  0,  0,  0, -5,
         10, 15, 15, 15, 15, 15, 15, 10,
          0,  0,  0,  0,  0,  0,  0,  0
    ]

    private static let queenPST: [Int] = [
        -20,-10,-10, -5, -5,-10,-10,-20,
        -10,  0,  5,  0,  0,  0,  0,-10,
        -10,  5,  5,  5,  5,  5,  0,-10,
          0,  0,  5,  5,  5,  5,  0, -5,
         -5,  0,  5,  5,  5,  5,  0, -5,
        -10,  0,  5,  5,  5,  5,  0,-10,
        -10,  0,  0,  0,  0,  0,  0,-10,
        -20,-10,-10, -5, -5,-10,-10,-20
    ]

    private static let kingMidPST: [Int] = [
         20, 30, 10,  0,  0, 10, 30, 20,
         20, 20,  0,  0,  0,  0, 20, 20,
        -10,-20,-20,-20,-20,-20,-20,-10,
        -20,-30,-30,-40,-40,-30,-30,-20,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30,
        -30,-40,-40,-50,-50,-40,-40,-30
    ]

    private static let kingEndPST: [Int] = [
        -50,-30,-30,-30,-30,-30,-30,-50,
        -30,-10,  0,  0,  0,  0,-10,-30,
        -30,  0, 20, 25, 25, 20,  0,-30,
        -30,  0, 25, 35, 35, 25,  0,-30,
        -30,  0, 25, 35, 35, 25,  0,-30,
        -30,  0, 20, 25, 25, 20,  0,-30,
        -30,-10,  0,  0,  0,  0,-10,-30,
        -50,-30,-30,-30,-30,-30,-30,-50
    ]

    /// Static evaluation in centipawns from White's perspective (+ favors White, - favors Black).
    public static func evaluate(_ state: BoardState) -> Int {
        var whiteScore = 0
        var blackScore = 0
        var whiteBishops = 0
        var blackBishops = 0
        var nonPawnMaterial = 0

        for idx in 0..<64 {
            guard let piece = state.squares[idx], piece.kind != .king else { continue }
            if piece.kind != .pawn {
                nonPawnMaterial += piece.kind.materialValue
            }
        }
        let isEndgame = nonPawnMaterial <= 2600

        for idx in 0..<64 {
            guard let piece = state.squares[idx] else { continue }
            let sq = Square(index: idx)
            let tableIndex = piece.color == .white
                ? idx
                : ((7 - sq.rank) << 3) | sq.file

            let positional: Int
            switch piece.kind {
            case .pawn: positional = pawnPST[tableIndex]
            case .knight: positional = knightPST[tableIndex]
            case .bishop:
                positional = bishopPST[tableIndex]
                if piece.color == .white { whiteBishops += 1 } else { blackBishops += 1 }
            case .rook: positional = rookPST[tableIndex]
            case .queen: positional = queenPST[tableIndex]
            case .king: positional = isEndgame ? kingEndPST[tableIndex] : kingMidPST[tableIndex]
            }

            let total = piece.kind.materialValue + positional
            if piece.color == .white {
                whiteScore += total
            } else {
                blackScore += total
            }
        }

        if whiteBishops >= 2 { whiteScore += 35 }
        if blackBishops >= 2 { blackScore += 35 }

        return whiteScore - blackScore
    }

    public static func chooseBestMove(
        for state: BoardState,
        difficulty: AIDifficulty,
        uciHistory: [String] = []
    ) -> (move: Move?, scoreWhitePerspective: Int) {
        let legal = state.legalMoves()
        guard !legal.isEmpty else {
            return (nil, evaluate(state))
        }

        // Check opening book for Club / Master / Grandmaster
        if difficulty != .novice,
           let book = OpeningBook.bookMove(for: state, uciHistory: uciHistory) {
            let afterEval = evaluate(state.applying(book))
            return (book, afterEval)
        }

        let maxDepth = difficulty.searchDepth
        let ordered = orderMoves(legal, in: state)

        if difficulty == .novice {
            // Novice plays top 3 moves with slight tactical noise
            var scored: [(Move, Int)] = []
            for m in ordered {
                let next = state.applying(m)
                let val = -negamax(next, depth: 1, alpha: -99_999, beta: 99_999)
                let perspective = state.sideToMove == .white ? val : -val
                scored.append((m, perspective + Int.random(in: -45...45)))
            }
            scored.sort { state.sideToMove == .white ? $0.1 > $1.1 : $0.1 < $1.1 }
            let chosen = scored.first!
            return (chosen.0, chosen.1)
        }

        var bestMove = ordered[0]
        var bestValue = -100_000

        for depth in 1...maxDepth {
            var alpha = -100_000
            let beta = 100_000
            var currentBest = bestMove
            var currentBestScore = -100_000

            // Put previous iteration's best move first
            var iterMoves = ordered
            if let idx = iterMoves.firstIndex(of: bestMove) {
                iterMoves.remove(at: idx)
                iterMoves.insert(bestMove, at: 0)
            }

            for move in iterMoves {
                let next = state.applying(move)
                let score = -negamax(next, depth: depth - 1, alpha: -beta, beta: -alpha)
                if score > currentBestScore {
                    currentBestScore = score
                    currentBest = move
                }
                if score > alpha {
                    alpha = score
                }
            }
            bestMove = currentBest
            bestValue = currentBestScore
        }

        let whitePerspective = state.sideToMove == .white ? bestValue : -bestValue
        return (bestMove, whitePerspective)
    }

    public static func chooseMove(
        for state: BoardState,
        difficulty: AIDifficulty,
        moveHistoryUCI: [String] = []
    ) -> (move: Move?, scoreWhitePerspective: Int) {
        chooseBestMove(for: state, difficulty: difficulty, uciHistory: moveHistoryUCI)
    }

    private static func negamax(_ state: BoardState, depth: Int, alpha: Int, beta: Int) -> Int {
        if state.halfmoveClock >= 100 || state.isInsufficientMaterial {
            return 0
        }

        let legal = state.legalMoves()
        if legal.isEmpty {
            if state.isInCheck(state.sideToMove) {
                return -30_000 - depth * 10
            }
            return 0
        }

        if depth <= 0 {
            return quiescence(state, alpha: alpha, beta: beta, qDepth: 3)
        }

        var a = alpha
        let ordered = orderMoves(legal, in: state)
        for move in ordered {
            let next = state.applying(move)
            let score = -negamax(next, depth: depth - 1, alpha: -beta, beta: -a)
            if score >= beta {
                return beta
            }
            if score > a {
                a = score
            }
        }
        return a
    }

    private static func quiescence(_ state: BoardState, alpha: Int, beta: Int, qDepth: Int) -> Int {
        let standPat = evaluateForSideToMove(state)
        if standPat >= beta {
            return beta
        }
        var a = max(alpha, standPat)
        if qDepth <= 0 {
            return a
        }

        let tacticalMoves = state.legalMoves().filter { move in
            state[move.to] != nil || move.isEnPassant || move.promotion != nil
        }
        guard !tacticalMoves.isEmpty else { return a }

        for move in orderMoves(tacticalMoves, in: state) {
            let next = state.applying(move)
            let score = -quiescence(next, alpha: -beta, beta: -a, qDepth: qDepth - 1)
            if score >= beta {
                return beta
            }
            if score > a {
                a = score
            }
        }
        return a
    }

    private static func evaluateForSideToMove(_ state: BoardState) -> Int {
        let raw = evaluate(state)
        return state.sideToMove == .white ? raw : -raw
    }

    private static func orderMoves(_ moves: [Move], in state: BoardState) -> [Move] {
        moves.sorted { lhs, rhs in
            movePriority(lhs, in: state) > movePriority(rhs, in: state)
        }
    }

    private static func movePriority(_ move: Move, in state: BoardState) -> Int {
        var score = 0
        if let promo = move.promotion {
            score += promo.materialValue * 10
        }
        if let victim = state.capturedPiece(for: move) {
            let attackerValue = state[move.from]?.kind.materialValue ?? 100
            score += victim.kind.materialValue * 12 - attackerValue
        }
        if move.isCastleKingside || move.isCastleQueenside {
            score += 250
        }
        // Center control preference
        if (2...5).contains(move.to.file) && (2...5).contains(move.to.rank) {
            score += 25
        }
        return score
    }
}

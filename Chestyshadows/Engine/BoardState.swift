import Foundation

public struct BoardState: Equatable, Hashable, Codable, Sendable {
    public var squares: [Piece?]
    public var sideToMove: PieceColor
    public var castlingRights: CastlingRights
    public var enPassantTarget: Square?
    public var halfmoveClock: Int
    public var fullmoveNumber: Int
    public var lastMove: Move?

    public static let startingFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    public static let initialFEN = startingFEN

    public init(
        squares: [Piece?],
        sideToMove: PieceColor = .white,
        castlingRights: CastlingRights = .all,
        enPassantTarget: Square? = nil,
        halfmoveClock: Int = 0,
        fullmoveNumber: Int = 1,
        lastMove: Move? = nil
    ) {
        precondition(squares.count == 64)
        self.squares = squares
        self.sideToMove = sideToMove
        self.castlingRights = castlingRights
        self.enPassantTarget = enPassantTarget
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
        self.lastMove = lastMove
    }

    public static var standard: BoardState {
        BoardState(fen: startingFEN)!
    }

    public static var initial: BoardState {
        standard
    }

    public init?(fen: String) {
        let parts = fen.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard parts.count >= 1 else { return nil }

        let ranks = parts[0].split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else { return nil }

        var board = [Piece?](repeating: nil, count: 64)
        for (rankIdxFromTop, rankStr) in ranks.enumerated() {
            let rank = 7 - rankIdxFromTop
            var file = 0
            for ch in rankStr {
                if let digit = ch.wholeNumberValue {
                    guard digit >= 1, digit <= 8, file + digit <= 8 else { return nil }
                    file += digit
                } else if let piece = Piece.fromFEN(ch) {
                    guard file < 8 else { return nil }
                    board[(rank << 3) | file] = piece
                    file += 1
                } else {
                    return nil
                }
            }
            guard file == 8 else { return nil }
        }

        let turn: PieceColor
        if parts.count >= 2 {
            switch parts[1].lowercased() {
            case "w": turn = .white
            case "b": turn = .black
            default: return nil
            }
        } else {
            turn = .white
        }

        var rights = CastlingRights.none
        if parts.count >= 3 {
            let cStr = parts[2]
            if cStr != "-" {
                rights.whiteKingside = cStr.contains("K")
                rights.whiteQueenside = cStr.contains("Q")
                rights.blackKingside = cStr.contains("k")
                rights.blackQueenside = cStr.contains("q")
            }
        } else {
            rights = .all
        }

        var ep: Square? = nil
        if parts.count >= 4, parts[3] != "-" {
            guard let sq = Square(algebraic: parts[3]) else { return nil }
            ep = sq
        }

        let half = parts.count >= 5 ? (Int(parts[4]) ?? 0) : 0
        let full = parts.count >= 6 ? max(1, Int(parts[5]) ?? 1) : 1

        // Ensure both kings exist
        let whiteKingCount = board.compactMap { $0 }.filter { $0 == Piece(.king, .white) }.count
        let blackKingCount = board.compactMap { $0 }.filter { $0 == Piece(.king, .black) }.count
        guard whiteKingCount == 1, blackKingCount == 1 else { return nil }

        self.init(
            squares: board,
            sideToMove: turn,
            castlingRights: rights,
            enPassantTarget: ep,
            halfmoveClock: half,
            fullmoveNumber: full
        )
    }

    public subscript(_ square: Square) -> Piece? {
        get { squares[square.index] }
        set { squares[square.index] = newValue }
    }

    public subscript(file: Int, rank: Int) -> Piece? {
        get {
            guard (0..<8).contains(file), (0..<8).contains(rank) else { return nil }
            return squares[(rank << 3) | file]
        }
        set {
            guard (0..<8).contains(file), (0..<8).contains(rank) else { return }
            squares[(rank << 3) | file] = newValue
        }
    }

    public var fen: String {
        "\(repetitionKey) \(halfmoveClock) \(fullmoveNumber)"
    }

    /// Position key used for threefold repetition (board + sideToMove + castling + enPassant).
    public var repetitionKey: String {
        var rankStrings: [String] = []
        rankStrings.reserveCapacity(8)
        for rank in stride(from: 7, through: 0, by: -1) {
            var line = ""
            var emptyCount = 0
            for file in 0..<8 {
                if let piece = squares[(rank << 3) | file] {
                    if emptyCount > 0 {
                        line.append(String(emptyCount))
                        emptyCount = 0
                    }
                    line.append(piece.fenCharacter)
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 {
                line.append(String(emptyCount))
            }
            rankStrings.append(line)
        }
        let boardPart = rankStrings.joined(separator: "/")
        let turnPart = sideToMove == .white ? "w" : "b"
        let epPart = enPassantTarget?.algebraic ?? "-"
        return "\(boardPart) \(turnPart) \(castlingRights.fenString) \(epPart)"
    }

    public func kingSquare(for color: PieceColor) -> Square? {
        let target = Piece(.king, color)
        for idx in 0..<64 where squares[idx] == target {
            return Square(index: idx)
        }
        return nil
    }

    public func isInCheck(_ color: PieceColor) -> Bool {
        guard let kingSq = kingSquare(for: color) else { return false }
        return isSquareAttacked(kingSq, by: color.opposite)
    }

    public func isSquareAttacked(_ square: Square, by attacker: PieceColor) -> Bool {
        let f = square.file
        let r = square.rank

        // 1. Pawn attacks
        let pawnSourceRank = r - attacker.pawnStep
        if (0..<8).contains(pawnSourceRank) {
            for df in [-1, 1] {
                let pf = f + df
                if (0..<8).contains(pf),
                   squares[(pawnSourceRank << 3) | pf] == Piece(.pawn, attacker) {
                    return true
                }
            }
        }

        // 2. Knight attacks
        let knightOffsets = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ]
        for (df, dr) in knightOffsets {
            let nf = f + df, nr = r + dr
            if (0..<8).contains(nf), (0..<8).contains(nr),
               squares[(nr << 3) | nf] == Piece(.knight, attacker) {
                return true
            }
        }

        // 3. King attacks
        for df in -1...1 {
            for dr in -1...1 where df != 0 || dr != 0 {
                let kf = f + df, kr = r + dr
                if (0..<8).contains(kf), (0..<8).contains(kr),
                   squares[(kr << 3) | kf] == Piece(.king, attacker) {
                    return true
                }
            }
        }

        // 4. Orthogonal rays (Rook / Queen)
        let orthoDirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        for (df, dr) in orthoDirs {
            var cf = f + df, cr = r + dr
            while (0..<8).contains(cf) && (0..<8).contains(cr) {
                if let piece = squares[(cr << 3) | cf] {
                    if piece.color == attacker && (piece.kind == .rook || piece.kind == .queen) {
                        return true
                    }
                    break
                }
                cf += df
                cr += dr
            }
        }

        // 5. Diagonal rays (Bishop / Queen)
        let diagDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        for (df, dr) in diagDirs {
            var cf = f + df, cr = r + dr
            while (0..<8).contains(cf) && (0..<8).contains(cr) {
                if let piece = squares[(cr << 3) | cf] {
                    if piece.color == attacker && (piece.kind == .bishop || piece.kind == .queen) {
                        return true
                    }
                    break
                }
                cf += df
                cr += dr
            }
        }

        return false
    }

    /// Returns a map of squares attacked by the given color (used for the Shadow Threat Map).
    public func attackedSquares(by color: PieceColor) -> Set<Square> {
        var result = Set<Square>()
        for idx in 0..<64 {
            let sq = Square(index: idx)
            if isSquareAttacked(sq, by: color) {
                result.insert(sq)
            }
        }
        return result
    }

    public func pseudoLegalMoves() -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(48)
        let us = sideToMove
        let them = us.opposite

        for idx in 0..<64 {
            guard let piece = squares[idx], piece.color == us else { continue }
            let from = Square(index: idx)
            let f = from.file
            let r = from.rank

            switch piece.kind {
            case .pawn:
                let step = us.pawnStep
                let nextRank = r + step
                if (0..<8).contains(nextRank) {
                    let oneStep = Square(file: f, rank: nextRank)
                    if self[oneStep] == nil {
                        if nextRank == us.promotionRank {
                            for promo in PieceKind.promotionChoices {
                                moves.append(Move(from: from, to: oneStep, promotion: promo))
                            }
                        } else {
                            moves.append(Move(from: from, to: oneStep))
                            if r == us.pawnStartRank {
                                let twoStep = Square(file: f, rank: r + step * 2)
                                if self[twoStep] == nil {
                                    moves.append(Move(from: from, to: twoStep))
                                }
                            }
                        }
                    }
                    // Captures & En Passant
                    for df in [-1, 1] {
                        guard let target = Square(validatingFile: f + df, rank: nextRank) else { continue }
                        if let occupant = self[target], occupant.color == them {
                            if nextRank == us.promotionRank {
                                for promo in PieceKind.promotionChoices {
                                    moves.append(Move(from: from, to: target, promotion: promo))
                                }
                            } else {
                                moves.append(Move(from: from, to: target))
                            }
                        } else if target == enPassantTarget {
                            moves.append(Move(from: from, to: target, isEnPassant: true))
                        }
                    }
                }

            case .knight:
                let offsets = [
                    (-2, -1), (-2, 1), (-1, -2), (-1, 2),
                    (1, -2), (1, 2), (2, -1), (2, 1)
                ]
                for (df, dr) in offsets {
                    guard let to = from.offset(df: df, dr: dr) else { continue }
                    if self[to]?.color != us {
                        moves.append(Move(from: from, to: to))
                    }
                }

            case .bishop:
                addSlidingMoves(from: from, dirs: [(1, 1), (1, -1), (-1, 1), (-1, -1)], into: &moves)

            case .rook:
                addSlidingMoves(from: from, dirs: [(1, 0), (-1, 0), (0, 1), (0, -1)], into: &moves)

            case .queen:
                addSlidingMoves(
                    from: from,
                    dirs: [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)],
                    into: &moves
                )

            case .king:
                for df in -1...1 {
                    for dr in -1...1 where df != 0 || dr != 0 {
                        guard let to = from.offset(df: df, dr: dr) else { continue }
                        if self[to]?.color != us {
                            moves.append(Move(from: from, to: to))
                        }
                    }
                }
                // Castling
                let backRank = us.backRank
                if r == backRank && f == 4 && !isInCheck(us) {
                    let canKS = us == .white ? castlingRights.whiteKingside : castlingRights.blackKingside
                    if canKS,
                       self[5, backRank] == nil,
                       self[6, backRank] == nil,
                       self[7, backRank] == Piece(.rook, us),
                       !isSquareAttacked(Square(file: 5, rank: backRank), by: them),
                       !isSquareAttacked(Square(file: 6, rank: backRank), by: them) {
                        moves.append(Move(from: from, to: Square(file: 6, rank: backRank), isCastleKingside: true))
                    }

                    let canQS = us == .white ? castlingRights.whiteQueenside : castlingRights.blackQueenside
                    if canQS,
                       self[3, backRank] == nil,
                       self[2, backRank] == nil,
                       self[1, backRank] == nil,
                       self[0, backRank] == Piece(.rook, us),
                       !isSquareAttacked(Square(file: 3, rank: backRank), by: them),
                       !isSquareAttacked(Square(file: 2, rank: backRank), by: them) {
                        moves.append(Move(from: from, to: Square(file: 2, rank: backRank), isCastleQueenside: true))
                    }
                }
            }
        }

        return moves
    }

    private func addSlidingMoves(from: Square, dirs: [(Int, Int)], into moves: inout [Move]) {
        let us = sideToMove
        for (df, dr) in dirs {
            var cf = from.file + df
            var cr = from.rank + dr
            while let to = Square(validatingFile: cf, rank: cr) {
                if let occupant = self[to] {
                    if occupant.color != us {
                        moves.append(Move(from: from, to: to))
                    }
                    break
                }
                moves.append(Move(from: from, to: to))
                cf += df
                cr += dr
            }
        }
    }

    public func legalMoves() -> [Move] {
        let us = sideToMove
        return pseudoLegalMoves().filter { move in
            let next = applying(move)
            return !next.isInCheck(us)
        }
    }

    public func legalMoves(from square: Square) -> [Move] {
        guard self[square]?.color == sideToMove else { return [] }
        return legalMoves().filter { $0.from == square }
    }

    public func capturedPiece(for move: Move) -> Piece? {
        if move.isEnPassant {
            let capSq = Square(file: move.to.file, rank: move.from.rank)
            return self[capSq]
        }
        return self[move.to]
    }

    public func applying(_ move: Move) -> BoardState {
        var next = self
        guard let movingPiece = next[move.from] else { return next }
        let us = movingPiece.color
        let isCapture = next[move.to] != nil || move.isEnPassant

        next[move.from] = nil

        if move.isEnPassant {
            let capturedPawnSquare = Square(file: move.to.file, rank: move.from.rank)
            next[capturedPawnSquare] = nil
        }

        if move.isCastleKingside {
            let rank = us.backRank
            next[Square(file: 7, rank: rank)] = nil
            next[Square(file: 5, rank: rank)] = Piece(.rook, us)
        } else if move.isCastleQueenside {
            let rank = us.backRank
            next[Square(file: 0, rank: rank)] = nil
            next[Square(file: 3, rank: rank)] = Piece(.rook, us)
        }

        if let promo = move.promotion {
            next[move.to] = Piece(promo, us)
        } else {
            next[move.to] = movingPiece
        }

        // Update castling rights
        if movingPiece.kind == .king {
            if us == .white {
                next.castlingRights.whiteKingside = false
                next.castlingRights.whiteQueenside = false
            } else {
                next.castlingRights.blackKingside = false
                next.castlingRights.blackQueenside = false
            }
        }
        if move.from == Square(file: 0, rank: 0) || move.to == Square(file: 0, rank: 0) {
            next.castlingRights.whiteQueenside = false
        }
        if move.from == Square(file: 7, rank: 0) || move.to == Square(file: 7, rank: 0) {
            next.castlingRights.whiteKingside = false
        }
        if move.from == Square(file: 0, rank: 7) || move.to == Square(file: 0, rank: 7) {
            next.castlingRights.blackQueenside = false
        }
        if move.from == Square(file: 7, rank: 7) || move.to == Square(file: 7, rank: 7) {
            next.castlingRights.blackKingside = false
        }

        // En passant target
        if movingPiece.kind == .pawn && abs(move.to.rank - move.from.rank) == 2 {
            let midRank = (move.from.rank + move.to.rank) / 2
            next.enPassantTarget = Square(file: move.from.file, rank: midRank)
        } else {
            next.enPassantTarget = nil
        }

        // Clocks & turn
        if movingPiece.kind == .pawn || isCapture {
            next.halfmoveClock = 0
        } else {
            next.halfmoveClock += 1
        }
        if us == .black {
            next.fullmoveNumber += 1
        }
        next.sideToMove = us.opposite
        next.lastMove = move
        return next
    }

    public func toFEN() -> String {
        fen
    }

    public func termination(positionCounts: [String: Int] = [:]) -> GameTermination? {
        let legal = legalMoves()
        if legal.isEmpty {
            if isInCheck(sideToMove) {
                return .checkmate(winner: sideToMove.opposite)
            } else {
                return .stalemate
            }
        }
        if (positionCounts[repetitionKey] ?? 0) >= 3 {
            return .threefoldRepetition
        }
        if halfmoveClock >= 100 {
            return .fiftyMoveRule
        }
        if isInsufficientMaterial {
            return .insufficientMaterial
        }
        return nil
    }

    public func capturedPieces(by color: PieceColor) -> [PieceKind] {
        let opponent = color.opposite
        let startingCounts: [(PieceKind, Int)] = [
            (.queen, 1), (.rook, 2), (.bishop, 2), (.knight, 2), (.pawn, 8)
        ]
        var remaining: [PieceKind: Int] = [:]
        for p in squares.compactMap({ $0 }) where p.color == opponent {
            remaining[p.kind, default: 0] += 1
        }
        var captured: [PieceKind] = []
        for (kind, initialCount) in startingCounts {
            let count = max(0, initialCount - (remaining[kind] ?? 0))
            for _ in 0..<count {
                captured.append(kind)
            }
        }
        return captured
    }

    public var materialDiff: Int {
        var whitePts = 0
        var blackPts = 0
        for p in squares.compactMap({ $0 }) {
            if p.color == .white {
                whitePts += p.kind.materialPoints
            } else {
                blackPts += p.kind.materialPoints
            }
        }
        return whitePts - blackPts
    }

    public var isInsufficientMaterial: Bool {
        var whitePieces: [(PieceKind, Square)] = []
        var blackPieces: [(PieceKind, Square)] = []
        for idx in 0..<64 {
            guard let p = squares[idx], p.kind != .king else { continue }
            if p.kind == .pawn || p.kind == .rook || p.kind == .queen {
                return false
            }
            if p.color == .white {
                whitePieces.append((p.kind, Square(index: idx)))
            } else {
                blackPieces.append((p.kind, Square(index: idx)))
            }
        }
        if whitePieces.isEmpty && blackPieces.isEmpty { return true }
        if whitePieces.count == 1 && blackPieces.isEmpty { return true }
        if blackPieces.count == 1 && whitePieces.isEmpty { return true }
        if whitePieces.count == 1 && blackPieces.count == 1,
           whitePieces[0].0 == .bishop && blackPieces[0].0 == .bishop,
           whitePieces[0].1.isLight == blackPieces[0].1.isLight {
            return true
        }
        return false
    }

    /// Formats a legal move in Standard Algebraic Notation (e.g. "Nf3", "exd5", "O-O", "Qh4#").
    public func san(for move: Move, knownLegalMoves: [Move]? = nil) -> String {
        guard let piece = self[move.from] else { return move.uci }
        let after = applying(move)
        let opponentMoves = after.legalMoves()
        let givesCheck = after.isInCheck(after.sideToMove)
        let suffix: String
        if givesCheck {
            suffix = opponentMoves.isEmpty ? "#" : "+"
        } else {
            suffix = ""
        }

        if move.isCastleKingside {
            return "O-O" + suffix
        }
        if move.isCastleQueenside {
            return "O-O-O" + suffix
        }

        let isCapture = self[move.to] != nil || move.isEnPassant
        var text = ""

        if piece.kind == .pawn {
            if isCapture {
                let fileChar = Character(UnicodeScalar(Int(UnicodeScalar("a").value) + move.from.file)!)
                text.append(fileChar)
                text.append("x")
            }
            text.append(move.to.algebraic)
            if let promo = move.promotion {
                text.append("=\(promo.sanLetter)")
            }
        } else {
            text.append(piece.kind.sanLetter)
            let legal = knownLegalMoves ?? legalMoves()
            let ambiguous = legal.filter {
                $0.from != move.from &&
                $0.to == move.to &&
                self[$0.from] == piece
            }
            if !ambiguous.isEmpty {
                let sameFile = ambiguous.contains { $0.from.file == move.from.file }
                let sameRank = ambiguous.contains { $0.from.rank == move.from.rank }
                let fileChar = Character(UnicodeScalar(Int(UnicodeScalar("a").value) + move.from.file)!)
                let rankChar = Character(UnicodeScalar(Int(UnicodeScalar("1").value) + move.from.rank)!)
                if !sameFile {
                    text.append(fileChar)
                } else if !sameRank {
                    text.append(rankChar)
                } else {
                    text.append(fileChar)
                    text.append(rankChar)
                }
            }
            if isCapture {
                text.append("x")
            }
            text.append(move.to.algebraic)
        }

        return text + suffix
    }
}

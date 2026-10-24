import Foundation

public enum PieceColor: String, Codable, CaseIterable, Sendable {
    case white
    case black

    public var opposite: PieceColor {
        self == .white ? .black : .white
    }

    public var displayName: String {
        self == .white ? "White" : "Black"
    }

    public var pawnStep: Int {
        self == .white ? 1 : -1
    }

    public var pawnStartRank: Int {
        self == .white ? 1 : 6
    }

    public var promotionRank: Int {
        self == .white ? 7 : 0
    }

    public var backRank: Int {
        self == .white ? 0 : 7
    }
}

public enum PieceKind: String, Codable, CaseIterable, Sendable {
    case king
    case queen
    case rook
    case bishop
    case knight
    case pawn

    public var materialValue: Int {
        switch self {
        case .king: return 20_000
        case .queen: return 950
        case .rook: return 500
        case .bishop: return 335
        case .knight: return 320
        case .pawn: return 100
        }
    }

    public var materialPoints: Int {
        switch self {
        case .king: return 0
        case .queen: return 9
        case .rook: return 5
        case .bishop: return 3
        case .knight: return 3
        case .pawn: return 1
        }
    }

    public var sanLetter: String {
        switch self {
        case .king: return "K"
        case .queen: return "Q"
        case .rook: return "R"
        case .bishop: return "B"
        case .knight: return "N"
        case .pawn: return ""
        }
    }

    public var fenChar: Character {
        switch self {
        case .king: return "k"
        case .queen: return "q"
        case .rook: return "r"
        case .bishop: return "b"
        case .knight: return "n"
        case .pawn: return "p"
        }
    }

    public var solidGlyphUnicode: UniChar {
        switch self {
        case .king: return 0x265A
        case .queen: return 0x265B
        case .rook: return 0x265C
        case .bishop: return 0x265D
        case .knight: return 0x265E
        case .pawn: return 0x265F
        }
    }

    public var symbolString: String {
        String(UnicodeScalar(solidGlyphUnicode)!)
    }

    public static let promotionChoices: [PieceKind] = [.queen, .rook, .bishop, .knight]
}

public struct Piece: Equatable, Hashable, Codable, Sendable {
    public var kind: PieceKind
    public var color: PieceColor

    public init(_ kind: PieceKind, _ color: PieceColor) {
        self.kind = kind
        self.color = color
    }

    public init(_ color: PieceColor, _ kind: PieceKind) {
        self.kind = kind
        self.color = color
    }

    public var unicodeSymbol: String {
        kind.symbolString
    }

    public var fenCharacter: Character {
        let base = String(kind.fenChar)
        return color == .white ? Character(base.uppercased()) : Character(base)
    }

    public static func fromFEN(_ ch: Character) -> Piece? {
        let color: PieceColor = ch.isUppercase ? .white : .black
        switch ch.lowercased().first {
        case "k": return Piece(.king, color)
        case "q": return Piece(.queen, color)
        case "r": return Piece(.rook, color)
        case "b": return Piece(.bishop, color)
        case "n": return Piece(.knight, color)
        case "p": return Piece(.pawn, color)
        default: return nil
        }
    }
}

public struct Square: Equatable, Hashable, Codable, Sendable {
    public let file: Int // 0...7 (a...h)
    public let rank: Int // 0...7 (1...8)

    public init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    public init?(validatingFile file: Int, rank: Int) {
        guard (0..<8).contains(file), (0..<8).contains(rank) else { return nil }
        self.file = file
        self.rank = rank
    }

    public init(index: Int) {
        self.file = index & 7
        self.rank = index >> 3
    }

    public init?(algebraic: String) {
        let chars = Array(algebraic.lowercased())
        guard chars.count == 2,
              let fileScalar = chars[0].unicodeScalars.first,
              let rankScalar = chars[1].unicodeScalars.first else {
            return nil
        }
        let f = Int(fileScalar.value) - Int(UnicodeScalar("a").value)
        let r = Int(rankScalar.value) - Int(UnicodeScalar("1").value)
        self.init(validatingFile: f, rank: r)
    }

    public var index: Int {
        (rank << 3) | file
    }

    public var isLight: Bool {
        (file + rank) % 2 != 0
    }

    public var isLightSquare: Bool {
        isLight
    }

    public var algebraic: String {
        let f = Character(UnicodeScalar(Int(UnicodeScalar("a").value) + file)!)
        let r = Character(UnicodeScalar(Int(UnicodeScalar("1").value) + rank)!)
        return "\(f)\(r)"
    }

    public func offset(df: Int, dr: Int) -> Square? {
        Square(validatingFile: file + df, rank: rank + dr)
    }

    public static var all: [Square] {
        (0..<64).map { Square(index: $0) }
    }
}

public struct CastlingRights: Equatable, Hashable, Codable, Sendable {
    public var whiteKingside: Bool
    public var whiteQueenside: Bool
    public var blackKingside: Bool
    public var blackQueenside: Bool

    public init(
        whiteKingside: Bool = true,
        whiteQueenside: Bool = true,
        blackKingside: Bool = true,
        blackQueenside: Bool = true
    ) {
        self.whiteKingside = whiteKingside
        self.whiteQueenside = whiteQueenside
        self.blackKingside = blackKingside
        self.blackQueenside = blackQueenside
    }

    public static let all = CastlingRights()
    public static let none = CastlingRights(
        whiteKingside: false,
        whiteQueenside: false,
        blackKingside: false,
        blackQueenside: false
    )

    public var fenString: String {
        var s = ""
        if whiteKingside { s.append("K") }
        if whiteQueenside { s.append("Q") }
        if blackKingside { s.append("k") }
        if blackQueenside { s.append("q") }
        return s.isEmpty ? "-" : s
    }
}

public struct Move: Equatable, Hashable, Codable, Sendable {
    public let from: Square
    public let to: Square
    public let promotion: PieceKind?
    public let isEnPassant: Bool
    public let isCastleKingside: Bool
    public let isCastleQueenside: Bool

    public init(
        from: Square,
        to: Square,
        promotion: PieceKind? = nil,
        isEnPassant: Bool = false,
        isCastleKingside: Bool = false,
        isCastleQueenside: Bool = false
    ) {
        self.from = from
        self.to = to
        self.promotion = promotion
        self.isEnPassant = isEnPassant
        self.isCastleKingside = isCastleKingside
        self.isCastleQueenside = isCastleQueenside
    }

    public var uci: String {
        let promo = promotion.map { String($0.fenChar) } ?? ""
        return "\(from.algebraic)\(to.algebraic)\(promo)"
    }

    public var uciNotation: String { uci }
    public var isKingsideCastle: Bool { isCastleKingside }
    public var isQueensideCastle: Bool { isCastleQueenside }
    public var isCastle: Bool { isCastleKingside || isCastleQueenside }
}

public enum GameTermination: Equatable, Sendable {
    case checkmate(winner: PieceColor)
    case stalemate
    case threefoldRepetition
    case fiftyMoveRule
    case insufficientMaterial
    case timeOut(winner: PieceColor)
    case resignation(winner: PieceColor)

    public var headline: String {
        switch self {
        case .checkmate(let winner):
            return "Checkmate — \(winner.displayName) Wins"
        case .stalemate:
            return "Draw by Stalemate"
        case .threefoldRepetition:
            return "Draw by Threefold Repetition"
        case .fiftyMoveRule:
            return "Draw by Fifty-Move Rule"
        case .insufficientMaterial:
            return "Draw by Insufficient Material"
        case .timeOut(let winner):
            return "\(winner.displayName) Wins on Time"
        case .resignation(let winner):
            return "\(winner.displayName) Wins by Resignation"
        }
    }

    public var subtitle: String {
        switch self {
        case .checkmate(let winner):
            return "\(winner.opposite.displayName)'s king has no legal escape."
        case .stalemate:
            return "No legal moves remain, and the king is not in check."
        case .threefoldRepetition:
            return "The exact same position has occurred three times."
        case .fiftyMoveRule:
            return "Fifty consecutive moves played without a pawn advance or capture."
        case .insufficientMaterial:
            return "Neither side has sufficient material to force checkmate."
        case .timeOut(let winner):
            return "\(winner.opposite.displayName)'s clock expired."
        case .resignation(let winner):
            return "\(winner.opposite.displayName) resigned the game."
        }
    }

    public var pgnResult: String {
        switch self {
        case .checkmate(let winner), .timeOut(let winner), .resignation(let winner):
            return winner == .white ? "1-0" : "0-1"
        case .stalemate, .threefoldRepetition, .fiftyMoveRule, .insufficientMaterial:
            return "1/2-1/2"
        }
    }

    public var title: String { headline }

    public static func timeout(winner: PieceColor) -> GameTermination {
        .timeOut(winner: winner)
    }
}

public enum AIDifficulty: String, CaseIterable, Identifiable, Sendable {
    case novice = "Shadow Initiate"
    case club = "Club Tactician"
    case master = "Shadow Master"
    case grandmaster = "Grandmaster Shadow"
    case passAndPlay = "Pass & Play (2P)"

    public var id: String { rawValue }

    public var searchDepth: Int {
        switch self {
        case .novice: return 1
        case .club: return 2
        case .master: return 3
        case .grandmaster: return 4
        case .passAndPlay: return 3
        }
    }

    public var ratingEstimate: String {
        switch self {
        case .novice: return "~950 ELO"
        case .club: return "~1450 ELO"
        case .master: return "~1900 ELO"
        case .grandmaster: return "~2350 ELO"
        case .passAndPlay: return "Local 2-Player"
        }
    }

    public static var shadowKnight: AIDifficulty { .club }
    public static var shadowMaster: AIDifficulty { .master }

    public var subtitle: String {
        switch self {
        case .novice: return "Gentle tactical awareness"
        case .club: return "Balanced positional play"
        case .master: return "Deep tactical calculation"
        case .grandmaster: return "Maximum search precision"
        case .passAndPlay: return "Two human players"
        }
    }

    public var estimatedELO: Int {
        switch self {
        case .novice: return 950
        case .club: return 1450
        case .master: return 1900
        case .grandmaster: return 2350
        case .passAndPlay: return 1500
        }
    }
}

public enum TimeControl: String, CaseIterable, Identifiable, Sendable {
    case untimed = "Untimed"
    case bullet1_0 = "Bullet 1+0"
    case blitz3_2 = "Blitz 3+2"
    case blitz5_0 = "Blitz 5+0"
    case rapid10_0 = "Rapid 10+0"
    case classical15_10 = "Classical 15+10"

    public var id: String { rawValue }

    public var initialSeconds: TimeInterval? {
        switch self {
        case .untimed: return nil
        case .bullet1_0: return 60
        case .blitz3_2: return 180
        case .blitz5_0: return 300
        case .rapid10_0: return 600
        case .classical15_10: return 900
        }
    }

    public var incrementSeconds: TimeInterval? {
        switch self {
        case .untimed: return nil
        case .blitz3_2: return 2
        case .classical15_10: return 10
        default: return 0
        }
    }

    public static var rapid10m: TimeControl { .rapid10_0 }
}

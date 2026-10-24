import AppKit
import SwiftUI
import XCTest
@testable import Chestyshadows

final class ChessEngineTests: XCTestCase {
    func testInitialPositionHas20LegalMoves() {
        let board = BoardState.initial
        let moves = board.legalMoves()
        XCTAssertEqual(moves.count, 20)
        XCTAssertEqual(board.toFEN(), BoardState.initialFEN)
    }

    func testPerftDepth2Is400() {
        let board = BoardState.initial
        var total = 0
        for m1 in board.legalMoves() {
            let b1 = board.applying(m1)
            total += b1.legalMoves().count
        }
        XCTAssertEqual(total, 400)
    }

    func testFoolsMateCheckmateAndSAN() {
        var board = BoardState.initial
        // 1. f3 e5 2. g4 Qh4#
        let m1 = board.legalMoves().first { $0.uciNotation == "f2f3" }!
        board = board.applying(m1)
        let m2 = board.legalMoves().first { $0.uciNotation == "e7e5" }!
        board = board.applying(m2)
        let m3 = board.legalMoves().first { $0.uciNotation == "g2g4" }!
        board = board.applying(m3)
        let m4 = board.legalMoves().first { $0.uciNotation == "d8h4" }!
        let san4 = board.san(for: m4)
        XCTAssertEqual(san4, "Qh4#")
        board = board.applying(m4)

        XCTAssertEqual(board.termination(), .checkmate(winner: .black))
    }

    func testEnPassantCapture() {
        // White pawn on e5, Black plays d7d5, White captures e5d6 en passant
        guard var board = BoardState(fen: "rnbqkbnr/pppppppp/8/4P3/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1") else {
            XCTFail("Invalid FEN")
            return
        }
        let d7d5 = board.legalMoves().first { $0.uciNotation == "d7d5" }!
        board = board.applying(d7d5)
        XCTAssertEqual(board.enPassantTarget, Square(algebraic: "d6"))

        let epMove = board.legalMoves().first { $0.uciNotation == "e5d6" }
        XCTAssertNotNil(epMove)
        XCTAssertTrue(epMove?.isEnPassant == true)

        let afterEP = board.applying(epMove!)
        XCTAssertNil(afterEP[Square(algebraic: "d5")!])
        XCTAssertEqual(afterEP[Square(algebraic: "d6")!], Piece(.white, .pawn))
    }

    func testCastlingAndAttackedTransitRestriction() {
        guard let clearBoard = BoardState(fen: "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1") else {
            XCTFail("Invalid FEN")
            return
        }
        let kingMoves = clearBoard.legalMoves(from: Square(algebraic: "e1")!)
        XCTAssertTrue(kingMoves.contains { $0.isKingsideCastle })
        XCTAssertTrue(kingMoves.contains { $0.isQueensideCastle })

        // Now place a Black rook attacking f1 so kingside castling is illegal
        guard let blockedTransit = BoardState(fen: "4k3/8/8/8/8/5r2/8/R3K2R w KQ - 0 1") else {
            XCTFail("Invalid FEN")
            return
        }
        let blockedMoves = blockedTransit.legalMoves(from: Square(algebraic: "e1")!)
        XCTAssertFalse(blockedMoves.contains { $0.isKingsideCastle })
        XCTAssertTrue(blockedMoves.contains { $0.isQueensideCastle })
    }

    func testPawnPromotionGeneratesFourChoices() {
        guard let promoBoard = BoardState(fen: "8/4P2k/8/8/8/8/8/4K3 w - - 0 1") else {
            XCTFail("Invalid FEN")
            return
        }
        let e7Moves = promoBoard.legalMoves(from: Square(algebraic: "e7")!)
        let promoMoves = e7Moves.filter { $0.to == Square(algebraic: "e8") }
        XCTAssertEqual(promoMoves.count, 4)
    }

    func testAIFindsMateInOne() {
        // White Queen on h5, Bishop on c4, Black King on e8 -> Qxf7#
        guard let board = BoardState(fen: "r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4") else {
            XCTFail("Invalid FEN")
            return
        }
        let result = ChessAI.chooseMove(for: board, difficulty: .shadowKnight, moveHistoryUCI: [])
        XCTAssertEqual(result.move?.uciNotation, "h5f7")
    }

    @MainActor
    func testMainGameViewControllerLifecycle() {
        let vm = GameViewModel()
        vm.soundMuted = true
        vm.aiDifficulty = .passAndPlay
        for uci in ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"] {
            if let m = vm.board.legalMoves().first(where: { $0.uciNotation == uci }) {
                vm.commitMove(m, animate: false)
            }
        }
        vm.handleSquareTap(Square(algebraic: "f3")!)
        XCTAssertEqual(vm.currentOpeningName, "Italian Game · Giuoco Piano")
        XCTAssertEqual(vm.moveHistory.count, 6)
    }
}


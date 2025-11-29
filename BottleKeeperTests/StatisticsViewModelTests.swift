import XCTest
import CoreData
@testable import BottleKeeper

/// StatisticsViewModelのユニットテスト
@MainActor
final class StatisticsViewModelTests: BottleKeeperTestCase {

    var sut: StatisticsViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = StatisticsViewModel()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Basic Statistics Tests

    func test_totalBottles_returnsCorrectCount() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1"),
            createTestBottle(name: "ボトル2"),
            createTestBottle(name: "ボトル3")
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.totalBottles, 3)
    }

    func test_totalInvestment_calculatesCorrectSum() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1", purchasePrice: 3000),
            createTestBottle(name: "ボトル2", purchasePrice: 5000),
            createTestBottle(name: "ボトル3", purchasePrice: 7000)
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.totalInvestment, 15000)
    }

    func test_averageABV_calculatesCorrectAverage() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1", abv: 40.0),
            createTestBottle(name: "ボトル2", abv: 43.0),
            createTestBottle(name: "ボトル3", abv: 46.0)
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.averageABV, 43.0, accuracy: 0.01)
    }

    func test_averageABV_returnsZeroForEmptyList() throws {
        // When
        sut.updateData(bottles: [], drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.averageABV, 0)
    }

    // MARK: - Opened Status Tests

    func test_openedBottles_countsCorrectly() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1", isOpened: true),
            createTestBottle(name: "ボトル2", isOpened: false),
            createTestBottle(name: "ボトル3", isOpened: true)
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.openedBottles, 2)
        XCTAssertEqual(sut.unopenedBottles, 1)
    }

    func test_openedPercentage_calculatesCorrectly() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1", isOpened: true),
            createTestBottle(name: "ボトル2", isOpened: true),
            createTestBottle(name: "ボトル3", isOpened: false),
            createTestBottle(name: "ボトル4", isOpened: false)
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.openedPercentage, 50.0, accuracy: 0.01)
    }

    func test_averageRemainingPercentage_calculatesForOpenedBottles() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1", volume: 700, remainingVolume: 350, isOpened: true), // 50%
            createTestBottle(name: "ボトル2", volume: 700, remainingVolume: 700, isOpened: true), // 100%
            createTestBottle(name: "ボトル3", volume: 700, remainingVolume: 700, isOpened: false) // 未開栓は除外
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.averageRemainingPercentage, 75.0, accuracy: 0.01)
    }

    // MARK: - Type Distribution Tests

    func test_typeDistribution_groupsCorrectly() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1", type: "シングルモルト"),
            createTestBottle(name: "ボトル2", type: "シングルモルト"),
            createTestBottle(name: "ボトル3", type: "ブレンデッド"),
            createTestBottle(name: "ボトル4", type: "バーボン")
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.typeDistribution.count, 3)

        // シングルモルトが最多
        XCTAssertEqual(sut.typeDistribution.first?.0, "シングルモルト")
        XCTAssertEqual(sut.typeDistribution.first?.1, 2)
    }

    // MARK: - Cost Performance Tests

    func test_costPerformanceData_sortsCorrectly() throws {
        // Given
        let bottles = [
            createTestBottle(name: "高コスパ", volume: 700, purchasePrice: 3500),   // 5円/ml
            createTestBottle(name: "中コスパ", volume: 700, purchasePrice: 7000),   // 10円/ml
            createTestBottle(name: "低コスパ", volume: 700, purchasePrice: 10500)   // 15円/ml
        ]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertEqual(sut.costPerformanceData.count, 3)
        XCTAssertEqual(sut.costPerformanceData.first?.bottle.name, "高コスパ")
        XCTAssertEqual(sut.costPerformanceData.last?.bottle.name, "低コスパ")
    }

    // MARK: - Display State Tests

    func test_hasBottles_returnsFalseForEmptyList() throws {
        // When
        sut.updateData(bottles: [], drinkingLogs: [])

        // Then
        XCTAssertFalse(sut.hasBottles)
    }

    func test_hasBottles_returnsTrueForNonEmptyList() throws {
        // Given
        let bottles = [createTestBottle()]
        try saveContext()

        // When
        sut.updateData(bottles: bottles, drinkingLogs: [])

        // Then
        XCTAssertTrue(sut.hasBottles)
    }
}

import XCTest
import CoreData
@testable import BottleKeeper

/// DrinkingLogServiceのユニットテスト
final class DrinkingLogServiceTests: BottleKeeperTestCase {

    var sut: DrinkingLogService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = DrinkingLogService.shared
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - consumeOneShot Tests

    func test_consumeOneShot_createsLogAndReducesVolume() throws {
        // Given
        let bottle = createTestBottle(volume: 700, remainingVolume: 700)
        try saveContext()

        let initialVolume = bottle.remainingVolume

        // When
        try sut.consumeOneShot(bottle: bottle, context: context)

        // Then
        XCTAssertEqual(bottle.remainingVolume, initialVolume - DrinkingLogService.oneShotVolume)
        XCTAssertTrue(bottle.isOpened)
    }

    func test_consumeOneShot_marksBottleAsOpened() throws {
        // Given
        let bottle = createTestBottle(isOpened: false)
        try saveContext()

        // When
        try sut.consumeOneShot(bottle: bottle, context: context)

        // Then
        XCTAssertTrue(bottle.isOpened)
    }

    func test_consumeOneShot_doesNotExceedZero() throws {
        // Given
        let bottle = createTestBottle(remainingVolume: 10) // 30mlのショットより少ない
        try saveContext()

        // When
        try sut.consumeOneShot(bottle: bottle, context: context)

        // Then
        XCTAssertEqual(bottle.remainingVolume, 0) // 0を下回らない
    }

    // MARK: - updateRemainingVolume Tests

    func test_updateRemainingVolume_createsLogForDecrease() throws {
        // Given
        let bottle = createTestBottle(volume: 700, remainingVolume: 700)
        try saveContext()

        // When
        try sut.updateRemainingVolume(bottle: bottle, newVolume: 650, context: context)

        // Then
        XCTAssertEqual(bottle.remainingVolume, 650)
        XCTAssertTrue(bottle.isOpened)

        // ログが作成されているか確認
        let fetchRequest: NSFetchRequest<DrinkingLog> = DrinkingLog.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "bottle == %@", bottle)
        let logs = try context.fetch(fetchRequest)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.volume, 50) // 700 - 650 = 50
    }

    func test_updateRemainingVolume_doesNotCreateLogForIncrease() throws {
        // Given
        let bottle = createTestBottle(remainingVolume: 500)
        try saveContext()

        // When
        try sut.updateRemainingVolume(bottle: bottle, newVolume: 600, context: context)

        // Then
        XCTAssertEqual(bottle.remainingVolume, 600)

        // ログが作成されていないことを確認
        let fetchRequest: NSFetchRequest<DrinkingLog> = DrinkingLog.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "bottle == %@", bottle)
        let logs = try context.fetch(fetchRequest)
        XCTAssertTrue(logs.isEmpty)
    }

    func test_updateRemainingVolume_clampsToZero() throws {
        // Given
        let bottle = createTestBottle(remainingVolume: 100)
        try saveContext()

        // When
        try sut.updateRemainingVolume(bottle: bottle, newVolume: -50, context: context)

        // Then
        XCTAssertEqual(bottle.remainingVolume, 0)
    }

    func test_updateRemainingVolume_clampsToMaxVolume() throws {
        // Given
        let bottle = createTestBottle(volume: 700, remainingVolume: 500)
        try saveContext()

        // When
        try sut.updateRemainingVolume(bottle: bottle, newVolume: 1000, context: context)

        // Then
        XCTAssertEqual(bottle.remainingVolume, 700) // ボトル容量を超えない
    }
}

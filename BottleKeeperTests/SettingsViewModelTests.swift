import XCTest
import CoreData
@testable import BottleKeeper

/// SettingsViewModelのユニットテスト
@MainActor
final class SettingsViewModelTests: BottleKeeperTestCase {

    var sut: SettingsViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = SettingsViewModel()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func test_init_hasDefaultState() throws {
        // Then
        XCTAssertFalse(sut.showingDeleteAlert)
        XCTAssertFalse(sut.showingSchemaInitAlert)
        XCTAssertNil(sut.schemaInitError)
        XCTAssertFalse(sut.isInitializingSchema)
    }

    // MARK: - Delete Alert Tests

    func test_showingDeleteAlert_canBeToggled() throws {
        // When
        sut.showingDeleteAlert = true

        // Then
        XCTAssertTrue(sut.showingDeleteAlert)

        // When
        sut.showingDeleteAlert = false

        // Then
        XCTAssertFalse(sut.showingDeleteAlert)
    }

    // MARK: - Schema Init Alert Tests

    func test_showingSchemaInitAlert_canBeToggled() throws {
        // When
        sut.showingSchemaInitAlert = true

        // Then
        XCTAssertTrue(sut.showingSchemaInitAlert)
    }

    func test_schemaInitError_canBeSet() throws {
        // When
        sut.schemaInitError = "テストエラー"

        // Then
        XCTAssertEqual(sut.schemaInitError, "テストエラー")
    }

    func test_isInitializingSchema_canBeSet() throws {
        // When
        sut.isInitializingSchema = true

        // Then
        XCTAssertTrue(sut.isInitializingSchema)
    }
}

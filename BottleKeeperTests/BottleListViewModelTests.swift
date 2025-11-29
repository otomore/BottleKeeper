import XCTest
import CoreData
@testable import BottleKeeper

/// BottleListViewModelのユニットテスト
@MainActor
final class BottleListViewModelTests: BottleKeeperTestCase {

    var sut: BottleListViewModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = BottleListViewModel()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func test_init_hasEmptyState() throws {
        // Then
        XCTAssertFalse(sut.showingAddBottle)
        XCTAssertFalse(sut.showingQuickUpdate)
        XCTAssertFalse(sut.showingBottleDetail)
        XCTAssertFalse(sut.showingRandomPicker)
        XCTAssertTrue(sut.searchText.isEmpty)
        XCTAssertNil(sut.selectedBottle)
        XCTAssertNil(sut.randomBottle)
        XCTAssertTrue(sut.filteredBottles.isEmpty)
    }

    // MARK: - updateBottles Tests

    func test_updateBottles_setsBottlesAndUpdatesFiltered() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1"),
            createTestBottle(name: "ボトル2"),
            createTestBottle(name: "ボトル3")
        ]
        try saveContext()

        // When
        sut.updateBottles(bottles)

        // Then
        XCTAssertEqual(sut.filteredBottles.count, 3)
        XCTAssertTrue(sut.hasBottles)
    }

    func test_updateBottles_withEmptyArray_clearsFiltered() throws {
        // Given
        let bottles = [createTestBottle()]
        try saveContext()
        sut.updateBottles(bottles)

        // When
        sut.updateBottles([])

        // Then
        XCTAssertTrue(sut.filteredBottles.isEmpty)
        XCTAssertFalse(sut.hasBottles)
    }

    // MARK: - Search/Filter Tests

    func test_updateFilteredBottles_filtersbySearchText() throws {
        // Given
        let bottles = [
            createTestBottle(name: "山崎12年"),
            createTestBottle(name: "白州12年"),
            createTestBottle(name: "響21年")
        ]
        try saveContext()
        sut.updateBottles(bottles)

        // When
        sut.searchText = "12年"
        sut.updateFilteredBottles()

        // Then
        XCTAssertEqual(sut.filteredBottles.count, 2)
        XCTAssertTrue(sut.filteredBottles.allSatisfy { $0.name?.contains("12年") == true })
    }

    func test_updateFilteredBottles_emptySearch_showsAll() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1"),
            createTestBottle(name: "ボトル2")
        ]
        try saveContext()
        sut.updateBottles(bottles)
        sut.searchText = "test"
        sut.updateFilteredBottles()

        // When
        sut.searchText = ""
        sut.updateFilteredBottles()

        // Then
        XCTAssertEqual(sut.filteredBottles.count, 2)
    }

    func test_updateFilteredBottles_byDistillery() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1", distillery: "サントリー"),
            createTestBottle(name: "ボトル2", distillery: "ニッカ"),
            createTestBottle(name: "ボトル3", distillery: "サントリー")
        ]
        try saveContext()
        sut.updateBottles(bottles)

        // When
        sut.searchText = "サントリー"
        sut.updateFilteredBottles()

        // Then
        XCTAssertEqual(sut.filteredBottles.count, 2)
    }

    // MARK: - Grid Layout Tests

    func test_gridColumns_iPhoneWidth_returnsOne() throws {
        // When
        let columns = sut.gridColumns(for: 400)

        // Then
        XCTAssertEqual(columns, 1)
    }

    func test_gridColumns_iPadPortrait_returnsTwo() throws {
        // When
        let columns = sut.gridColumns(for: 800)

        // Then
        XCTAssertEqual(columns, 2)
    }

    func test_gridColumns_iPadLandscape_returnsThree() throws {
        // When
        let columns = sut.gridColumns(for: 1100)

        // Then
        XCTAssertEqual(columns, 3)
    }

    func test_gridColumns_boundaryAt700_returnsTwo() throws {
        // When
        let columns = sut.gridColumns(for: 700)

        // Then
        XCTAssertEqual(columns, 2)
    }

    func test_gridColumns_boundaryAt1000_returnsThree() throws {
        // When
        let columns = sut.gridColumns(for: 1000)

        // Then
        XCTAssertEqual(columns, 3)
    }

    // MARK: - Random Picker Tests

    func test_pickRandomBottle_setsRandomBottleAndShowsAlert() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1"),
            createTestBottle(name: "ボトル2")
        ]
        try saveContext()
        sut.updateBottles(bottles)

        // When
        sut.pickRandomBottle()

        // Then
        XCTAssertNotNil(sut.randomBottle)
        XCTAssertTrue(sut.showingRandomPicker)
        XCTAssertTrue(bottles.contains(sut.randomBottle!))
    }

    func test_pickRandomBottle_emptyList_doesNothing() throws {
        // When
        sut.pickRandomBottle()

        // Then
        XCTAssertNil(sut.randomBottle)
        XCTAssertFalse(sut.showingRandomPicker)
    }

    // MARK: - Show Actions Tests

    func test_showAddBottle_setsFlag() throws {
        // When
        sut.showAddBottle()

        // Then
        XCTAssertTrue(sut.showingAddBottle)
    }

    func test_showQuickUpdate_setsBottleAndFlag() throws {
        // Given
        let bottle = createTestBottle()
        try saveContext()

        // When
        sut.showQuickUpdate(for: bottle)

        // Then
        XCTAssertEqual(sut.selectedBottle, bottle)
        XCTAssertTrue(sut.showingQuickUpdate)
    }

    func test_showBottleDetail_setsBottleAndFlag() throws {
        // Given
        let bottle = createTestBottle()
        try saveContext()

        // When
        sut.showBottleDetail(for: bottle)

        // Then
        XCTAssertEqual(sut.selectedBottle, bottle)
        XCTAssertTrue(sut.showingBottleDetail)
    }

    func test_navigateToRandomBottleDetail_setsFlag() throws {
        // When
        sut.navigateToRandomBottleDetail()

        // Then
        XCTAssertTrue(sut.navigateToRandomBottle)
    }

    // MARK: - State Helpers Tests

    func test_hasBottles_falseWhenEmpty() throws {
        // Then
        XCTAssertFalse(sut.hasBottles)
    }

    func test_hasBottles_trueWhenNotEmpty() throws {
        // Given
        let bottles = [createTestBottle()]
        try saveContext()

        // When
        sut.updateBottles(bottles)

        // Then
        XCTAssertTrue(sut.hasBottles)
    }

    func test_hasFilteredBottles_reflectsFilteredList() throws {
        // Given
        let bottles = [createTestBottle(name: "テスト")]
        try saveContext()
        sut.updateBottles(bottles)

        // When - no filter
        XCTAssertTrue(sut.hasFilteredBottles)

        // When - filter matches
        sut.searchText = "テスト"
        sut.updateFilteredBottles()
        XCTAssertTrue(sut.hasFilteredBottles)

        // When - filter doesn't match
        sut.searchText = "存在しない"
        sut.updateFilteredBottles()
        XCTAssertFalse(sut.hasFilteredBottles)
    }

    // MARK: - Delete Tests

    func test_deleteBottle_removesFromContext() throws {
        // Given
        let bottle = createTestBottle()
        try saveContext()

        // Verify bottle exists
        let fetchRequest: NSFetchRequest<Bottle> = Bottle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", bottle.id! as CVarArg)
        var results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)

        // When
        sut.deleteBottle(bottle, context: context)

        // Then
        results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 0)
    }

    func test_deleteBottles_removesMultipleFromContext() throws {
        // Given
        let bottles = [
            createTestBottle(name: "ボトル1"),
            createTestBottle(name: "ボトル2"),
            createTestBottle(name: "ボトル3")
        ]
        try saveContext()
        sut.updateBottles(bottles)

        // When - delete first two bottles
        sut.deleteBottles(at: IndexSet([0, 1]), context: context)

        // Then
        let fetchRequest: NSFetchRequest<Bottle> = Bottle.fetchRequest()
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "ボトル3")
    }
}

import XCTest
import CoreData
@testable import BottleKeeper

/// テスト用のCore Dataスタックを提供するベースクラス
class BottleKeeperTestCase: XCTestCase {
    var context: NSManagedObjectContext!
    var container: NSPersistentContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = createInMemoryContainer()
        context = container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    /// インメモリのCore Dataコンテナを作成
    private func createInMemoryContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "BottleKeeper")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }

        return container
    }

    // MARK: - Factory Methods

    /// テスト用のボトルを作成
    @discardableResult
    func createTestBottle(
        name: String = "テストウイスキー",
        distillery: String = "テスト蒸留所",
        type: String = "シングルモルト",
        abv: Double = 43.0,
        volume: Int32 = 700,
        remainingVolume: Int32 = 700,
        purchasePrice: Decimal? = 5000,
        isOpened: Bool = false
    ) -> Bottle {
        let bottle = Bottle(context: context)
        bottle.id = UUID()
        bottle.name = name
        bottle.distillery = distillery
        bottle.type = type
        bottle.abv = abv
        bottle.volume = volume
        bottle.remainingVolume = remainingVolume
        bottle.isOpened = isOpened
        bottle.createdAt = Date()
        bottle.updatedAt = Date()

        if let price = purchasePrice {
            bottle.purchasePrice = NSDecimalNumber(decimal: price)
        }

        return bottle
    }

    /// テスト用の飲酒ログを作成
    @discardableResult
    func createTestDrinkingLog(
        bottle: Bottle,
        volume: Int32 = 30,
        date: Date = Date()
    ) -> DrinkingLog {
        let log = DrinkingLog(context: context)
        log.id = UUID()
        log.bottle = bottle
        log.volume = volume
        log.date = date
        return log
    }

    /// コンテキストを保存
    func saveContext() throws {
        try context.save()
    }
}

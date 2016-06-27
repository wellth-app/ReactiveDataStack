import Foundation
import CoreData


public class CoreDataStack {
    public enum StoreType {
        case InMemory
        case SQLite
    }
    
    // MARK: - Variables
    
    let storeType: StoreType
    let storeName: String?
    let modelName: String
    let modelBundle: NSBundle
    
    /// The context for the main queue
    private var _mainContext: NSManagedObjectContext?
    public var mainContext: NSManagedObjectContext {
        get {
            if _mainContext == nil {
                let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
                context.undoManager = nil
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                context.parentContext = self.writerContext
                context.name = "CoreDataStack Main Context"
                
                _mainContext = context
            }
            
            return _mainContext!
        }
    }
    
    /// The writer context
    private var _writerContext: NSManagedObjectContext?
    private var writerContext: NSManagedObjectContext {
        get {
            if _writerContext == nil {
                let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                context.undoManager = nil
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                context.persistentStoreCoordinator = self.persistentStoreCoordinator
                context.name = "CoreDataStack Writer Context"
                
                _writerContext = context
            }
            
            return _writerContext!
        }
    }
    
    /// The persistent store coordinator shared across all `NSManagedObjectContext` instances
    /// created by this instance
    private var _persistentStoreCoordinator: NSPersistentStoreCoordinator?
    private var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        get {
            if _persistentStoreCoordinator == nil {
                let filePath = (self.storeName ?? self.modelName) + ".sqlite"
                
                var model: NSManagedObjectModel?
                
                if let momdModelURL = self.modelBundle.URLForResource(self.modelName, withExtension: "momd") {
                    model = NSManagedObjectModel(contentsOfURL: momdModelURL)
                }
                
                if let momModelURL = self.modelBundle.URLForResource(self.modelName, withExtension: "mom") {
                    model = NSManagedObjectModel(contentsOfURL: momModelURL)
                }
                
                guard let unwrappedModel = model else { fatalError("Model with model name \(self.modelName) not found in bundle \(self.modelBundle)") }
                let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: unwrappedModel)
                
                switch self.storeType {
                case .InMemory:
                    do {
                        try persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
                    } catch let error as NSError {
                        fatalError("There was an error creating the persistentStoreCoordinator: \(error)")
                    }
                    
                    break
                case .SQLite:
                    let storeURL = self.applicationDocumentsDirectory().URLByAppendingPathComponent(filePath)
                    guard let storePath = storeURL.path else { fatalError("Store path not found: \(storeURL)") }
                    
                    let shouldPreloadDatabase = !NSFileManager.defaultManager().fileExistsAtPath(storePath)
                    if shouldPreloadDatabase {
                        if let preloadedPath = self.modelBundle.pathForResource(self.modelName, ofType: "sqlite") {
                            let preloadURL = NSURL.fileURLWithPath(preloadedPath)
                            
                            do {
                                try NSFileManager.defaultManager().copyItemAtURL(preloadURL, toURL: storeURL)
                            } catch let error as NSError {
                                fatalError("Oops, could not copy preloaded data. Error: \(error)")
                            }
                        }
                    }
                    
                    do {
                        try persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: [NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true])
                    } catch {
                        print("Error encountered while reading the database. Please allow all the data to download again.")
                        
                        do {
                            try NSFileManager.defaultManager().removeItemAtPath(storePath)
                            
                            do {
                                try persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: [NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true])
                            } catch let addPersistentError as NSError {
                                fatalError("There was an error creating the persistentStoreCoordinator: \(addPersistentError)")
                            }
                        } catch let removingError as NSError {
                            fatalError("There was an error removing the persistentStoreCoordinator: \(removingError)")
                        }
                    }
                    
                    let shouldExcludeSQLiteFromBackup = self.storeType == .SQLite
                    if shouldExcludeSQLiteFromBackup {
                        do {
                            try storeURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
                        } catch let excludingError as NSError {
                            fatalError("Excluding SQLite file from backup caused an error: \(excludingError)")
                        }
                    }
                    
                    break
                }
                
                _persistentStoreCoordinator = persistentStoreCoordinator
            }
            
            return _persistentStoreCoordinator!
        }
    }
    
    private lazy var disposablePersistentStoreCoordinator: NSPersistentStoreCoordinator = {
        guard let modelURL = self.modelBundle.URLForResource(self.modelName, withExtension: "momd"), model = NSManagedObjectModel(contentsOfURL: modelURL)
            else { fatalError("Model named \(self.modelName) not found in bundle \(self.modelBundle)") }
        
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        do {
            try persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
        } catch let error as NSError {
            fatalError("There was an error creating the disposablePersistentStoreCoordinator: \(error)")
        }
        
        return persistentStoreCoordinator
    }()
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextWillSaveNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextDidSaveNotification, object: nil)
    }
    
    // MARK: - Initalizers
    
    public convenience init?() {
        let bundle = NSBundle.mainBundle()
        if let bundleName = bundle.infoDictionary?["CFBundleName"] as? String {
            self.init(modelName: bundleName)
        } else {
            return nil
        }
    }
    
    public init(modelName: String, bundle: NSBundle = NSBundle.mainBundle(), storeType: StoreType = .SQLite, storeName: String? = nil) {
        self.modelName = modelName
        self.modelBundle = bundle
        self.storeType = storeType
        self.storeName = storeName
    }
    
    // MARK: - Observers
    @objc
    internal func newDisposableMainContextWillSave(notification: NSNotification) {
        if let context = notification.object as? NSManagedObjectContext {
            context.reset()
        }
    }
    
    @objc
    internal func backgroundContextDidSave(notification: NSNotification) {
        if NSThread.isMainThread() {
            fatalError("Background context saved in the main thread. Use context's `performBlock`")
        } else {
            mainContext.performBlock {
                self.mainContext.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
    }
    
    // MARK: - Public
    
    /// Creates a new disposable main context.
    public func newDisposableMainContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.persistentStoreCoordinator = self.disposablePersistentStoreCoordinator
        context.undoManager = nil
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(CoreDataStack.newDisposableMainContextWillSave(_:)), name: NSManagedObjectContextWillSaveNotification, object: context)
        
        return context
    }
    
    /// Creates a new private context.
    public func newBackgroundContext(name: String? = nil, parentContext: NSManagedObjectContext? = nil, mergeChanges: Bool = false) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        
        if let parentContext = parentContext {
            context.parentContext = parentContext
        } else {
            context.persistentStoreCoordinator = self.persistentStoreCoordinator
        }
        
        context.undoManager = nil
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.name = name
        
        if mergeChanges {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(CoreDataStack.backgroundContextDidSave(_:)), name: NSManagedObjectContextDidSaveNotification, object: context)
        }
        
        return context
    }
    
    /// Creates a new background context, performs `operation` within the context.
    public func performInNewBackgroundContext(operation: (backgroundContext: NSManagedObjectContext) -> ()) {
        let context = newBackgroundContext()
        
        context.performBlock {
            operation(backgroundContext: context)
        }
    }
    
    /// Persists the stack. Calls `completion` with an error if something fails.
    /// This will not save child context's. They must be saved before invoking this method
    /// for their changes to persist.
    public func persistWithCompletion(completion: ((ErrorType?) -> Void)? = nil) {
        let saveWriterContext: Void -> Void = {
            self.writerContext.performBlock {
                do {
                    try self.writerContext.save()
                    dispatch_async(dispatch_get_main_queue()) {
                        completion?(nil)
                    }
                } catch {
                    completion?(error)
                }
            }
        }
        
        mainContext.performBlock {
            do {
                try self.mainContext.save()
                saveWriterContext()
            } catch {
                completion?(error)
            }
        }
    }
    
    /// Drops a collection for an `entity`. This is not object-graph safe, and
    /// mostly for development purposes. Deletes in production should respect
    /// the object graph
    public func dropEntityCollection(entityName: String, managedObjectContext: NSManagedObjectContext? = nil) -> Bool {
        let fetchRequest = NSFetchRequest(entityName: entityName)
        let managedObjectContext = managedObjectContext ?? mainContext
        
        if #available(iOS 9.0, OSX 10.11, *) {
            return batchDeleteCollection(fetchRequest, managedObjectContext: managedObjectContext)
        } else {
            // Fallback on earlier versions
            return fetchAndDeleteCollection(fetchRequest, managedObjectContext: managedObjectContext)
        }
        
    }
    
    /// Utilizes `NSBatchDeleteRequest` to delete objects matching `fetchRequest`
    @available(iOS 9.0, OSX 10.11, *)
    private func batchDeleteCollection(fetchRequest: NSFetchRequest, managedObjectContext: NSManagedObjectContext) -> Bool {
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try self._persistentStoreCoordinator?.executeRequest(batchDeleteRequest, withContext: managedObjectContext)
            return true
        } catch {
            return false
        }
    }
    
    /// Loads objects matching `fetchRequest` into memory, and then deletes them.
    private func fetchAndDeleteCollection(fetchRequest: NSFetchRequest, managedObjectContext: NSManagedObjectContext) -> Bool {
        fetchRequest.includesPropertyValues = false
        
        do {
            guard let objects = try managedObjectContext.executeFetchRequest(fetchRequest) as? [NSManagedObject]
            else {
                return false
            }
            
            for object in objects {
                managedObjectContext.deleteObject(object)
            }
            
            return true
        } catch {
            return false
        }
    }
    
    /// Drops the entire stack.
    public func drop() {
        guard let store = self.persistentStoreCoordinator.persistentStores.last,
            storeURL = store.URL,
            storePath = storeURL.path
            else {
                fatalError("Persistent store coordinator not found")
        }
        
        let sqliteFile = (storePath as NSString).stringByDeletingPathExtension
        let fileManager = NSFileManager.defaultManager()
        
        self._writerContext = nil
        self._mainContext = nil
        self._persistentStoreCoordinator = nil
        
        let shm = sqliteFile + ".sqlite-shm"
        if fileManager.fileExistsAtPath(shm) {
            do {
                try fileManager.removeItemAtURL(NSURL.fileURLWithPath(shm))
            } catch let error as NSError {
                print("Could not delete persistent store shm: \(error)")
            }
        }
        
        let wal = sqliteFile + ".sqlite-wal"
        if fileManager.fileExistsAtPath(wal) {
            do {
                try fileManager.removeItemAtURL(NSURL.fileURLWithPath(wal))
            } catch let error as NSError {
                print("Could not delete persistent store wal: \(error)")
            }
        }
        
        if fileManager.fileExistsAtPath(storePath) {
            do {
                try fileManager.removeItemAtURL(storeURL)
            } catch let error as NSError {
                print("Could not delete sqlite file: \(error)")
            }
        }
    }
    
    private func applicationDocumentsDirectory() -> NSURL {
        #if os(tvOS)
            return NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).last!
        #else
            return NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last!
        #endif
    }
}

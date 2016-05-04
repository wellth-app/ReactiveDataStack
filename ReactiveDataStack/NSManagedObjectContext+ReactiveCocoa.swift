import CoreData
import ReactiveCocoa
import Result


public struct CoreDataScheduler: SchedulerType {
    let managedObjectContext: NSManagedObjectContext
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    public func schedule(action: () -> ()) -> Disposable? {
        let disposable = SimpleDisposable()
        
        managedObjectContext.performBlock {
            if disposable.disposed {
                return
            }
            
            action()
        }
        
        return disposable
    }
}


public extension NSManagedObjectContext {
    ///  Returns the count of `insertedObjects`, `updatedObjects`, and `deletedObjects`
    private var changedObjectsCount: Int {
        return insertedObjects.count + updatedObjects.count + deletedObjects.count
    }
    
    ///  Tries to save.
    ///  Returns a signal which sends true if successful
    ///  or an error
    public func saveProducer() -> SignalProducer<Bool, NSError> {
        return performBlockProducer()
            .promoteErrors(NSError)
            .flatMap(.Latest) { context -> SignalProducer<Bool, NSError> in
                do {
                    try context.save()
                    return SignalProducer(value: true)
                } catch let error as NSError {
                    return SignalProducer(error: error)
                }
        }
    }
    
    ///  Tries to save. If unsuccessful, rolls back self.
    ///  Returns the result of `saveProducer`, automatically rolling back
    ///  self on failed event.
    public func saveOrRollbackProducer() -> SignalProducer<Bool, NSError> {
        return saveProducer()
            .on(event: { event in
                switch event {
                case .Interrupted, .Failed:
                    self.rollback()
                default:
                    break
                }
            })
    }
    
    func performBlockProducer() -> SignalProducer<NSManagedObjectContext, NoError> {
        return SignalProducer(value: self)
            .observeOn(CoreDataScheduler(managedObjectContext: self))
    }
}
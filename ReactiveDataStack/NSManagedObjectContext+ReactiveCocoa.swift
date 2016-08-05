import CoreData
import ReactiveCocoa
import Result


public extension NSManagedObjectContext {
    /// Returns a `SignalProducer` that sends `self` as the value,
    /// and executes on a `CoreDataScheduler`.
    /// This method is thread safe for core data.
    public var producer: SignalProducer<NSManagedObjectContext, NoError> {
        return SignalProducer(value: self)
            .observeOn(CoreDataScheduler(managedObjectContext: self))
    }
    
    /// The number of objects that have changes (inserted, updated, and deleted).
    private var changedObjectsCount: Int {
        return insertedObjects.count + updatedObjects.count + deletedObjects.count
    }
    
    @objc
    public func observedContextDidSave(notification: NSNotification) {
        performBlock {
            self.mergeChangesFromContextDidSaveNotification(notification)
        }
    }
}

extension SignalProducerType where Value == NSManagedObjectContext {
    /// Merges changes from the reciever to `context` after a `NSManagedObjectContextDidSaveNotification`
    func mergeChanges(inContext context: NSManagedObjectContext) -> SignalProducer<Value, Error> {
        return producer
            .map { managedObjectContext -> NSManagedObjectContext in
                NSNotificationCenter.defaultCenter().addObserver(context, selector: #selector(NSManagedObjectContext.observedContextDidSave(_:)), name: NSManagedObjectContextDidSaveNotification, object: managedObjectContext)
                return managedObjectContext
            }
    }
    
    /// Performs a block on the producers queue, returning the `SignalProducer` from `block`.
    public func performBlock<U>(block: NSManagedObjectContext -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
        return producer
            .flatMap(.Concat, transform: block)
    }
    
    /// Performs a block on the producers queue, returning a `SignalProducer` with the value from `block`.
    public func performBlock<U>(block: NSManagedObjectContext -> U) -> SignalProducer<U, Error> {
        return producer
            .map(block)
    }
    
    /// Performs a block on the producers queue, returing a `SignalProducer`, using the `Result<U, Error>` returned from `block`.
    public func performBlock<U>(block: NSManagedObjectContext -> Result<U, Error>) -> SignalProducer<U, Error> {
        return producer
            .attemptMap(block)
    }
    
    /// Attempts to invoke `save` on the `Value` of the producer.
    public func save(rollback: Bool = false) -> SignalProducer<NSManagedObjectContext, NSError> {
        return producer
            .flatMapError { error in return SignalProducer.empty }
            .attemptMap { context in
                do {
                    try context.save()
                } catch let error as NSError {
                    if rollback {
                        context.rollback()
                    }
                    
                    return .Failure(error)
                }
                
                return .Success(context)
            }
    }
}

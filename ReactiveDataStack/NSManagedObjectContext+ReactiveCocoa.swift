import Result


public extension NSManagedObjectContext {
    /// Returns a `SignalProducer` that sends `self` as the value,
    /// and executes on a `CoreDataScheduler`.
    /// This method is thread safe for core data.
    public var producer: SignalProducer<NSManagedObjectContext, NoError> {
        return SignalProducer(value: self)
            .observe(on: CoreDataScheduler(managedObjectContext: self))
    }
    
    public func saveProducer() -> SignalProducer<NSManagedObjectContext, NSError> {
        return producer
            .promoteErrors(NSError.self)
            .save()
    }
    
    public func saveOrRollbackProducer() -> SignalProducer<NSManagedObjectContext, NSError> {
        return producer
            .promoteErrors(NSError.self)
            .save(rollback: true)
    }
    
    @objc
    public func observedContextDidSave(_ notification: Notification) {
        perform {
            self.mergeChanges(fromContextDidSave: notification)
        }
    }
}

extension SignalProducerProtocol where Value == NSManagedObjectContext {
    /// Merges changes from the reciever to `context` after a `NSManagedObjectContextDidSaveNotification`
    public func mergeChanges(inContext context: NSManagedObjectContext) -> SignalProducer<Value, Error> {
        return producer
            .map { managedObjectContext -> NSManagedObjectContext in
                NotificationCenter.default.addObserver(context, selector: #selector(NSManagedObjectContext.observedContextDidSave(_:)), name: Notification.Name.NSManagedObjectContextDidSave, object: managedObjectContext)
                return managedObjectContext
            }
    }
    
    /// Performs a block on the producers queue, returning the `SignalProducer` from `block`.
    public func perform<U>(block: @escaping  (NSManagedObjectContext) -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
        return producer
            .flatMap(.concat, transform: block)
    }
    
    /// Performs a block on the producers queue, returning a `SignalProducer` with the value from `block`.
    public func perform<U>(block: @escaping (NSManagedObjectContext) -> U) -> SignalProducer<U, Error> {
        return producer
            .map(block)
    }
    
    /// Performs a block on the producers queue, returing a `SignalProducer`, using the `Result<U, Error>` returned from `block`.
    public func perform<U>(block: @escaping  (NSManagedObjectContext) -> Result<U, Error>) -> SignalProducer<U, Error> {
        return producer
            .attemptMap(block)
    }
}

extension SignalProducerProtocol where Value == NSManagedObjectContext, Error == NSError {
    /// Attempts to invoke `save` on the `Value` of the producer.
    public func save(rollback: Bool = false) -> SignalProducer<NSManagedObjectContext, NSError> {
        return producer
            .perform { context -> Result<NSManagedObjectContext, NSError> in
                do {
                    try context.save()
                } catch let error as NSError {
                    if rollback {
                        context.rollback()
                    }
                    
                    return .failure(error)
                }
                
                return .success(context)
        }
    }
}

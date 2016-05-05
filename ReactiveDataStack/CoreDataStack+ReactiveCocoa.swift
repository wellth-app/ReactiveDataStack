import CoreData
import ReactiveCocoa
import Result
import CoreDataStack


extension CoreDataStack {
    public func persistProducer() -> SignalProducer<Bool, NSError> {
        return SignalProducer { observer, _ in
            self.persistWithCompletion { error in
                if let error = error as? NSError {
                    observer.sendFailed(error)
                } else {
                    observer.sendNext(true)
                    observer.sendCompleted()
                }
            }
        }
    }
    
    public func performInNewBackgroundContextProducer() -> SignalProducer<NSManagedObjectContext, NoError> {
        return newBackgroundContext().performBlockProducer()
    }
    
    public func performInMainContextProducer() -> SignalProducer<NSManagedObjectContext, NoError> {
        return mainContext.performBlockProducer()
    }
    
    public func performInNewMainContextChildContextProducer(name: String? = nil) -> SignalProducer<NSManagedObjectContext, NoError> {
        return performInConcurrentContextProducer(name, parentContext: mainContext)
    }
    
    public func performInConcurrentContextProducer(name: String? = nil, parentContext: NSManagedObjectContext? = nil) -> SignalProducer<NSManagedObjectContext, NoError> {
        return newBackgroundContext(name, parentContext: parentContext).performBlockProducer()
    }
}